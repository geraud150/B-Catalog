import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config.dart';
import '../../core/database/app_database.dart';
import 'loyverse_api_service.dart';

/// Résultat de la tentative de synchronisation d'un produit avec Loyverse.
class SyncResult {
  const SyncResult({
    required this.product,
    required this.success,
    this.errorMessage,
  });

  final Product product;
  final bool success;
  final String? errorMessage;
}

/// Orchestration de l'envoi des produits sélectionnés vers Loyverse :
/// résolution de la boutique et des catégories (via [LoyverseApiService],
/// avec cache), création ou mise à jour de l'article (un seul appel par
/// groupe de variantes partageant un `groupId`), stock initial, puis photo
/// si disponible.
///
/// Une erreur sur un produit ou un groupe n'interrompt pas le lot : elle
/// est collectée dans le [SyncResult] correspondant et les produits
/// suivants sont traités.
class SyncService {
  SyncService({required this.database, LoyverseApiService? apiService})
    : _api = apiService ?? LoyverseApiService(database: database);

  final AppDatabase database;
  final LoyverseApiService _api;

  Future<List<SyncResult>> syncProducts(
    List<Product> products, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (products.isEmpty) return const [];

    final String storeId;
    try {
      storeId = await _api.fetchStoreId();
    } catch (e) {
      final message =
          'Boutique Loyverse "$kLoyverseStoreName" introuvable : '
          '${_describeError(e)}';
      onProgress?.call(products.length, products.length);
      return [
        for (final product in products)
          SyncResult(product: product, success: false, errorMessage: message),
      ];
    }

    final results = <SyncResult>[];
    var done = 0;
    for (final group in _groupByGroupId(products)) {
      results.addAll(await _syncGroup(group, storeId));
      done += group.length;
      onProgress?.call(done, products.length);
    }
    return results;
  }

  /// Partitionne [products] par `groupId`, en conservant l'ordre
  /// d'apparition des groupes (et l'ordre des membres au sein d'un groupe).
  /// Un produit sans `groupId` forme son propre groupe à un seul élément.
  List<List<Product>> _groupByGroupId(List<Product> products) {
    final order = <String>[];
    final byKey = <String, List<Product>>{};

    for (final product in products) {
      final key = product.groupId ?? '__standalone_${product.id}';
      final group = byKey.putIfAbsent(key, () {
        order.add(key);
        return [];
      });
      group.add(product);
    }

    return [for (final key in order) byKey[key]!];
  }

  /// Synchronise un groupe de variantes (ou un produit autonome, groupe à
  /// un seul élément) en un seul appel `createOrUpdateItem`.
  ///
  /// Les membres dont la catégorie ou le prix de vente sont manquants sont
  /// écartés de l'appel API et rapportés en échec individuellement, sans
  /// empêcher la synchronisation des autres membres valides du groupe.
  Future<List<SyncResult>> _syncGroup(
    List<Product> group,
    String storeId,
  ) async {
    final results = <SyncResult>[];
    final valid = <Product>[];

    for (final product in group) {
      final category = product.category?.trim();
      if (category == null || category.isEmpty) {
        results.add(
          SyncResult(
            product: product,
            success: false,
            errorMessage: 'Catégorie manquante',
          ),
        );
        continue;
      }
      if (product.sellPrice == null) {
        results.add(
          SyncResult(
            product: product,
            success: false,
            errorMessage: 'Prix de vente manquant',
          ),
        );
        continue;
      }
      // Loyverse rejette une catégorie de plus de 64 caractères. Le
      // formulaire la bloque désormais à la saisie, mais une fiche plus
      // ancienne (import, édition directe) peut encore la dépasser.
      if (category.length > 64) {
        results.add(
          SyncResult(
            product: product,
            success: false,
            errorMessage:
                'Catégorie trop longue (${category.length}/64 caractères '
                'maximum pour Loyverse)',
          ),
        );
        continue;
      }
      valid.add(product);
    }

    if (valid.isEmpty) return results;

    try {
      final categoryId = await _api.fetchOrCreateCategoryId(
        valid.first.category!.trim(),
      );
      final item = await _api.createOrUpdateItem(
        valid,
        categoryId: categoryId,
        storeId: storeId,
      );

      for (var i = 0; i < valid.length; i++) {
        results.add(
          await _finishVariant(valid[i], item.itemId, item.variantIds[i], storeId),
        );
      }
    } catch (e) {
      final message = _describeError(e);
      for (final product in valid) {
        results.add(
          SyncResult(product: product, success: false, errorMessage: message),
        );
      }
    }

    return results;
  }

  /// Renseigne le stock initial et la photo d'une variante déjà créée sur
  /// Loyverse. Une erreur ici n'affecte que cette variante, pas le reste du
  /// groupe (l'article et les autres variantes ont déjà été créés).
  Future<SyncResult> _finishVariant(
    Product product,
    String itemId,
    String variantId,
    String storeId,
  ) async {
    try {
      await _api.setInitialStock(
        variantId: variantId,
        storeId: storeId,
        quantity: product.quantity,
      );

      final photoPath = product.photoPath;
      if (photoPath != null && photoPath.isNotEmpty) {
        final photoFile = File(photoPath);
        if (await photoFile.exists()) {
          await _api.uploadItemImage(itemId: itemId, imageFile: photoFile);
        }
      }

      return SyncResult(product: product, success: true);
    } catch (e) {
      return SyncResult(
        product: product,
        success: false,
        errorMessage: _describeError(e),
      );
    }
  }
}

/// Extrait un message lisible d'une erreur d'appel API, en tentant de
/// remonter le message renvoyé par Loyverse plutôt qu'une exception brute.
///
/// Les erreurs de validation Loyverse sont enveloppées dans un tableau
/// `errors`, chaque élément portant `code`, `field` et `details` (ex.
/// `{"errors": [{"code": "NOT_FOUND", "field": "object.id", "details":
/// "..."}]}`) plutôt qu'un simple champ `message` à la racine.
String _describeError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final details = errors
            .whereType<Map>()
            .map((e) => e['details'])
            .whereType<String>()
            .where((d) => d.trim().isNotEmpty);
        if (details.isNotEmpty) return details.join(' ; ');
      }
      final message = data['message'] ?? data['error'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    final statusCode = error.response?.statusCode;
    if (statusCode != null) return 'Erreur HTTP $statusCode';
    return error.message ?? 'Erreur réseau';
  }
  return error.toString();
}
