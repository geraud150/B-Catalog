import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/database/app_database.dart';
import '../photo/photo_service.dart';

class CatalogSyncReport {
  const CatalogSyncReport({
    required this.uploaded,
    required this.downloaded,
    required this.deleted,
    required this.merged,
    required this.conflicts,
    required this.waitingForInitializer,
  });

  final int uploaded;
  final int downloaded;
  final int deleted;
  final int merged;
  final int conflicts;
  final bool waitingForInitializer;
}

class CatalogSyncService {
  CatalogSyncService({required this.database, required this.client});

  static const _catalogIdKey = 'catalog_id';

  final AppDatabase database;
  final SupabaseClient client;

  Future<CatalogSyncReport> synchronize() async {
    final catalog = await _loadCatalog();
    final catalogId = catalog['id'] as String;
    final initial = catalog['initialized_at'] == null;
    final deviceId = await database.getOrCreateCatalogDeviceId();
    final initializationState = await _claimCatalogInitialization(
      catalogId: catalogId,
      deviceId: deviceId,
    );

    if (initial && initializationState == 'waiting') {
      return const CatalogSyncReport(
        uploaded: 0,
        downloaded: 0,
        deleted: 0,
        merged: 0,
        conflicts: 0,
        waitingForInitializer: true,
      );
    }

    final isInitializer = initializationState == 'winner';
    var uploaded = 0;
    var conflicts = 0;

    // Rapproche d'abord les fiches locales jamais vues du cloud avec ce qui
    // existe déjà côté serveur. Cela évite d'envoyer deux UUID différents
    // pour le même article — y compris pour l'appareil "gagnant" : une
    // tentative d'initialisation précédente (son propre essai interrompu, ou
    // celui d'un autre appareil dont le bail a expiré) peut déjà avoir
    // envoyé des fiches avant que ce verrou ne soit repris.
    final remoteBeforeUpload = await _loadRemoteRows(catalogId);
    final reconciliation = await _reconcileUnknownLocalProducts(
      remoteRows: remoteBeforeUpload,
    );
    final merged = reconciliation.merged;
    conflicts += reconciliation.ambiguous;

    final pending = await database.getProductsPendingSync();

    for (final product in pending) {
      final syncId = product.syncId;
      if (syncId == null) continue;
      final photoObjectPath = await _uploadPhotoIfNeeded(product, syncId);
      final rows = await client.rpc(
        'apply_catalog_product_change',
        params: {
          'p_payload': {
            ..._toCloud(product),
            'catalog_id': catalogId,
            'photo_object_path': photoObjectPath,
          },
          'p_expected_revision': product.remoteRevision ?? 0,
        },
      );

      if (rows is! List || rows.isEmpty) {
        conflicts++;
        continue;
      }

      final row = Map<String, dynamic>.from(rows.first as Map);
      await database.markProductSynced(
        id: product.id,
        syncId: row['id'] as String,
        revision: row['revision'] as int,
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
        expectedLocalUpdatedAt: product.updatedAt,
      );
      uploaded++;
    }

    final tombstones = await database.getProductSyncTombstones();
    final uploadedDeletions = <String>{};
    for (final tombstone in tombstones) {
      final rows = await client.rpc(
        'apply_catalog_product_deletion',
        params: {
          'p_product_id': tombstone.syncId,
          'p_catalog_id': catalogId,
          'p_expected_revision': tombstone.remoteRevision,
        },
      );
      if (rows is List && rows.isNotEmpty) {
        uploadedDeletions.add(tombstone.syncId);
        await database.clearProductSyncTombstone(tombstone.syncId);
        uploaded++;
      } else {
        conflicts++;
      }
    }

    final remoteRows = await _loadRemoteRows(catalogId);
    var downloaded = 0;

    for (final rawRow in remoteRows) {
      final row = Map<String, dynamic>.from(rawRow);
      final syncId = row['id'] as String;
      final local = await database.getProductBySyncId(syncId);
      final revision = row['revision'] as int;

      if (row['is_deleted'] as bool) {
        if ((local != null && local.syncPending) ||
            (tombstones.any((item) => item.syncId == syncId) &&
                !uploadedDeletions.contains(syncId))) {
          conflicts++;
        } else {
          await database.applyRemoteProductDeletion(syncId);
        }
        continue;
      }

      if (local != null && local.syncPending) {
        if (local.remoteRevision != revision) conflicts++;
        continue;
      }

      final wasUpdated = local == null || local.remoteRevision != revision;
      final photoPath = await _downloadPhotoIfNeeded(row, local, syncId);
      await database.applyRemoteProduct(_fromCloud(row, local, photoPath));
      if (wasUpdated) downloaded++;
    }

    if (isInitializer && conflicts == 0) {
      final completed = await client.rpc(
        'complete_catalog_initialization',
        params: {'p_catalog_id': catalogId, 'p_device_id': deviceId},
      );
      if (completed != true) conflicts++;
    }

    await database.setCatalogSyncState(_catalogIdKey, catalogId);
    return CatalogSyncReport(
      uploaded: uploaded,
      downloaded: downloaded,
      deleted: uploadedDeletions.length,
      merged: merged,
      conflicts: conflicts,
      waitingForInitializer: false,
    );
  }

  Future<String> _claimCatalogInitialization({
    required String catalogId,
    required String deviceId,
  }) async {
    final rows = await client.rpc(
      'claim_catalog_initialization',
      params: {'p_catalog_id': catalogId, 'p_device_id': deviceId},
    );
    if (rows is! List || rows.isEmpty) {
      throw StateError('Le catalogue est inaccessible avec ce compte.');
    }
    return (rows.first as Map)['state'] as String;
  }

  Future<List<dynamic>> _loadRemoteRows(String catalogId) async =>
      await client
          .from('products')
          .select()
          .eq('catalog_id', catalogId)
          .order('updated_at');

  Future<_ReconciliationResult> _reconcileUnknownLocalProducts({
    required List<dynamic> remoteRows,
  }) async {
    final index = _RemoteIdentityIndex.fromRows(remoteRows);
    final canonicalLocalIdByRemoteId = <String, int>{};
    var merged = 0;
    var ambiguous = 0;

    final pending = await database.getProductsPendingSync();
    for (final product in pending) {
      // Les fiches déjà synchronisées sont des modifications et ne doivent
      // jamais être fusionnées implicitement avec une autre fiche.
      if (product.remoteRevision != null) continue;

      final resolution = index.resolve(_identityKeysForProduct(product));
      if (resolution.ambiguous) {
        ambiguous++;
        continue;
      }
      final remote = resolution.row;
      if (remote == null) continue;

      final remoteId = remote['id'] as String;
      final canonicalLocalId = canonicalLocalIdByRemoteId[remoteId];
      if (canonicalLocalId != null) {
        await database.mergeUnsyncedDuplicateInto(
          canonicalId: canonicalLocalId,
          duplicateId: product.id,
        );
        merged++;
        continue;
      }

      await database.adoptRemoteProductIdentity(
        localId: product.id,
        syncId: remoteId,
        remoteRevision: remote['revision'] as int,
      );
      canonicalLocalIdByRemoteId[remoteId] = product.id;
      merged++;
    }

    return _ReconciliationResult(merged: merged, ambiguous: ambiguous);
  }

  static Set<String> _identityKeysForProduct(Product product) =>
      _identityKeys(
        loyverseVariantId: product.loyverseVariantId,
        barcode: product.barcode,
        sku: product.sku,
      );

  static Set<String> _identityKeysForRow(Map<String, dynamic> row) =>
      _identityKeys(
        loyverseVariantId: row['loyverse_variant_id'] as String?,
        barcode: row['barcode'] as String?,
        sku: row['sku'] as String?,
      );

  static Set<String> _identityKeys({
    String? loyverseVariantId,
    String? barcode,
    String? sku,
  }) {
    String? normalized(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed.toLowerCase();
    }

    return {
      if (normalized(loyverseVariantId) case final value?) 'loyverse:$value',
      if (normalized(barcode) case final value?) 'barcode:$value',
      if (normalized(sku) case final value?) 'sku:$value',
    };
  }

  Future<Map<String, dynamic>> _loadCatalog() async {
    final cachedId = await database.getCatalogSyncState(_catalogIdKey);
    if (cachedId != null) {
      final catalog = await client
          .from('catalogs')
          .select('id, initialized_at')
          .eq('id', cachedId)
          .single();
      return Map<String, dynamic>.from(catalog);
    }

    final catalog = await client
        .from('catalogs')
        .select('id, initialized_at')
        .eq('is_singleton', true)
        .single();
    final result = Map<String, dynamic>.from(catalog);
    await database.setCatalogSyncState(_catalogIdKey, result['id'] as String);
    return result;
  }

  Future<String?> _uploadPhotoIfNeeded(Product product, String syncId) async {
    final path = product.photoPath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) {
      throw StateError(
        'Une photo locale est introuvable. Vérifiez-la avant de synchroniser.',
      );
    }

    final response = await client.functions.invoke(
      'catalog-sync',
      body: {
        'action': 'upload_photo',
        'productId': syncId,
        'photoBase64': base64Encode(await file.readAsBytes()),
      },
    );
    final data = response.data;
    if (response.status < 200 || response.status >= 300 || data is! Map) {
      throw StateError('L’envoi d’une photo a échoué.');
    }
    return data['photoObjectPath'] as String?;
  }

  Future<String?> _downloadPhotoIfNeeded(
    Map<String, dynamic> row,
    Product? local,
    String syncId,
  ) async {
    final currentPath = local?.photoPath;
    if (local != null && local.remoteRevision == row['revision']) {
      return currentPath;
    }

    final remotePath = row['photo_object_path'] as String?;
    if (remotePath == null) {
      if (currentPath != null) {
        await const PhotoService().deletePhoto(currentPath);
      }
      return null;
    }

    final response = await client.functions.invoke(
      'catalog-sync',
      body: {'action': 'download_photo', 'photoObjectPath': remotePath},
    );
    final data = response.data;
    if (response.status < 200 || response.status >= 300 || data is! Map) {
      throw StateError('Le téléchargement d’une photo a échoué.');
    }

    final bytes = base64Decode(data['photoBase64'] as String);
    final savedPath = await const PhotoService().saveCompressed(
      bytes,
      sku: syncId,
    );
    if (savedPath == null) throw StateError('La photo reçue est invalide.');
    if (currentPath != null && currentPath != savedPath) {
      await const PhotoService().deletePhoto(currentPath);
    }
    return savedPath;
  }

  Map<String, dynamic> _toCloud(Product product) => {
    'id': product.syncId,
    'barcode': product.barcode,
    'sku': product.sku,
    'name': product.name,
    'category': product.category,
    'description': product.description,
    'cost_price': product.costPrice,
    'sell_price': product.sellPrice,
    'quantity': product.quantity,
    'created_at': product.createdAt.toUtc().toIso8601String(),
    'updated_at': product.updatedAt.toUtc().toIso8601String(),
    'synced_to_loyverse': product.syncedToLoyverse,
    'option_name': product.optionName,
    'option_value': product.optionValue,
    'loyverse_item_id': product.loyverseItemId,
    'loyverse_variant_id': product.loyverseVariantId,
    'group_id': product.groupId,
    'import_source': product.importSource,
    'import_batch_id': product.importBatchId,
    'is_deleted': false,
  };

  ProductsCompanion _fromCloud(
    Map<String, dynamic> row,
    Product? local,
    String? photoPath,
  ) => ProductsCompanion(
    id: local == null ? const Value.absent() : Value(local.id),
    barcode: Value(row['barcode'] as String?),
    sku: Value(row['sku'] as String?),
    name: Value(row['name'] as String),
    category: Value(row['category'] as String?),
    description: Value(row['description'] as String?),
    costPrice: Value((row['cost_price'] as num?)?.toDouble()),
    sellPrice: Value((row['sell_price'] as num?)?.toDouble()),
    quantity: Value(row['quantity'] as int),
    photoPath: Value(photoPath),
    createdAt: Value(DateTime.parse(row['created_at'] as String).toLocal()),
    updatedAt: Value(DateTime.parse(row['updated_at'] as String).toLocal()),
    syncedToLoyverse: Value(row['synced_to_loyverse'] as bool),
    optionName: Value(row['option_name'] as String?),
    optionValue: Value(row['option_value'] as String?),
    loyverseItemId: Value(row['loyverse_item_id'] as String?),
    loyverseVariantId: Value(row['loyverse_variant_id'] as String?),
    groupId: Value(row['group_id'] as String?),
    importSource: Value(row['import_source'] as String?),
    importBatchId: Value(row['import_batch_id'] as String?),
    syncId: Value(row['id'] as String),
    remoteRevision: Value(row['revision'] as int),
    syncPending: const Value(false),
  );
}

class _ReconciliationResult {
  const _ReconciliationResult({required this.merged, required this.ambiguous});

  final int merged;
  final int ambiguous;
}

class _IdentityResolution {
  const _IdentityResolution.match(this.row) : ambiguous = false;
  const _IdentityResolution.none()
      : row = null,
        ambiguous = false;
  const _IdentityResolution.ambiguous()
      : row = null,
        ambiguous = true;

  final Map<String, dynamic>? row;
  final bool ambiguous;
}

/// Indexe uniquement les identifiants réellement exploitables. Une valeur qui
/// désigne plusieurs fiches cloud n'est jamais fusionnée automatiquement.
class _RemoteIdentityIndex {
  _RemoteIdentityIndex(this._unique, this._ambiguous);

  final Map<String, Map<String, dynamic>> _unique;
  final Set<String> _ambiguous;

  factory _RemoteIdentityIndex.fromRows(List<dynamic> rows) {
    final candidates = <String, List<Map<String, dynamic>>>{};
    for (final rawRow in rows) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      if (row['is_deleted'] == true) continue;
      for (final key in CatalogSyncService._identityKeysForRow(row)) {
        candidates.putIfAbsent(key, () => []).add(row);
      }
    }

    final unique = <String, Map<String, dynamic>>{};
    final ambiguous = <String>{};
    candidates.forEach((key, rowsForKey) {
      if (rowsForKey.length == 1) {
        unique[key] = rowsForKey.single;
      } else {
        ambiguous.add(key);
      }
    });
    return _RemoteIdentityIndex(unique, ambiguous);
  }

  _IdentityResolution resolve(Set<String> keys) {
    if (keys.isEmpty) return const _IdentityResolution.none();

    final loyverseKey = keys.where((key) => key.startsWith('loyverse:'));
    if (loyverseKey.isNotEmpty) {
      final key = loyverseKey.single;
      if (_ambiguous.contains(key)) return const _IdentityResolution.ambiguous();
      final row = _unique[key];
      return row == null
          ? const _IdentityResolution.none()
          : _IdentityResolution.match(row);
    }

    if (keys.any(_ambiguous.contains)) {
      return const _IdentityResolution.ambiguous();
    }
    final rows = <String, Map<String, dynamic>>{};
    for (final key in keys) {
      final row = _unique[key];
      if (row != null) rows[row['id'] as String] = row;
    }
    if (rows.isEmpty) return const _IdentityResolution.none();
    if (rows.length > 1) return const _IdentityResolution.ambiguous();
    return _IdentityResolution.match(rows.values.single);
  }
}
