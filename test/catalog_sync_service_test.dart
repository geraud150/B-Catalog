import 'dart:async';
import 'dart:convert';

import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/sync/catalog_sync_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const _catalogId = '11111111-1111-4111-8111-111111111111';

/// Simule assez du backend Postgres/PostgREST décrit par les migrations
/// `supabase/migrations/` pour exercer [CatalogSyncService.synchronize] sans
/// réseau : le verrou d'initialisation (`claim_catalog_initialization`,
/// `complete_catalog_initialization`) et les deux fonctions d'écriture à
/// verrou optimiste (`apply_catalog_product_change`,
/// `apply_catalog_product_deletion`).
class _FakeSupabaseBackend {
  _FakeSupabaseBackend({bool initialized = false})
    : catalog = {
        'id': _catalogId,
        'initialized_at': initialized ? _iso(DateTime(2026, 1, 1)) : null,
      },
      initializingDeviceId = null,
      initializationStartedAt = null;

  final Map<String, dynamic> catalog;
  String? initializingDeviceId;
  DateTime? initializationStartedAt;

  /// Lignes `products` déjà présentes côté serveur avant l'appel testé —
  /// sert à simuler un catalogue partiellement initialisé par une tentative
  /// antérieure.
  final List<Map<String, dynamic>> products = [];

  http.Client get httpClient => _FakeHttpClient(this);

  static String _iso(DateTime value) => value.toUtc().toIso8601String();

  Map<String, dynamic> _claimInitialization(Map<String, dynamic> body) {
    final deviceId = body['p_device_id'] as String;

    if (catalog['initialized_at'] != null) return {'state': 'ready'};
    if (initializingDeviceId == deviceId) return {'state': 'winner'};

    final expired =
        initializationStartedAt == null ||
        DateTime.now().difference(initializationStartedAt!) >
            const Duration(minutes: 15);
    if (initializingDeviceId == null || expired) {
      initializingDeviceId = deviceId;
      initializationStartedAt = DateTime.now();
      return {'state': 'winner'};
    }
    return {'state': 'waiting'};
  }

  Object? _completeInitialization(Map<String, dynamic> body) {
    final deviceId = body['p_device_id'] as String;
    if (catalog['initialized_at'] != null) return false;
    if (initializingDeviceId != deviceId) return false;

    catalog['initialized_at'] = _iso(DateTime.now());
    initializingDeviceId = null;
    initializationStartedAt = null;
    return true;
  }

  List<Map<String, dynamic>> _applyProductChange(Map<String, dynamic> body) {
    final payload = Map<String, dynamic>.from(body['p_payload'] as Map);
    final expectedRevision = body['p_expected_revision'] as int;
    final id = payload['id'] as String;
    final index = products.indexWhere((row) => row['id'] == id);

    if (index == -1) {
      final row = {
        ...payload,
        'revision': 1,
        'updated_at': _iso(DateTime.now()),
        'is_deleted': payload['is_deleted'] ?? false,
      };
      products.add(row);
      return [row];
    }

    final existing = products[index];
    if (existing['revision'] != expectedRevision) return const [];

    final updated = {
      ...existing,
      ...payload,
      'revision': (existing['revision'] as int) + 1,
      'updated_at': _iso(DateTime.now()),
    };
    products[index] = updated;
    return [updated];
  }

  List<Map<String, dynamic>> _applyProductDeletion(Map<String, dynamic> body) {
    final id = body['p_product_id'] as String;
    final expectedRevision = body['p_expected_revision'] as int;
    final index = products.indexWhere((row) => row['id'] == id);
    if (index == -1) return const [];

    final existing = products[index];
    if (existing['revision'] != expectedRevision) return const [];

    final updated = {
      ...existing,
      'is_deleted': true,
      'revision': (existing['revision'] as int) + 1,
      'updated_at': _iso(DateTime.now()),
    };
    products[index] = updated;
    return [updated];
  }
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.backend);

  final _FakeSupabaseBackend backend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final Map<String, dynamic> body = request is http.Request && request.body.isNotEmpty
        ? jsonDecode(request.body) as Map<String, dynamic>
        : const {};

    if (path == '/rest/v1/catalogs') {
      return _json(request, backend.catalog);
    }
    if (path == '/rest/v1/products') {
      final catalogFilter = request.url.queryParameters['catalog_id'];
      final rows = catalogFilter == null
          ? backend.products
          : backend.products
              .where((row) => 'eq.${row['catalog_id']}' == catalogFilter)
              .toList();
      return _json(request, rows);
    }
    if (path == '/rest/v1/rpc/claim_catalog_initialization') {
      return _json(request, [backend._claimInitialization(body)]);
    }
    if (path == '/rest/v1/rpc/complete_catalog_initialization') {
      return _json(request, backend._completeInitialization(body));
    }
    if (path == '/rest/v1/rpc/apply_catalog_product_change') {
      return _json(request, backend._applyProductChange(body));
    }
    if (path == '/rest/v1/rpc/apply_catalog_product_deletion') {
      return _json(request, backend._applyProductDeletion(body));
    }

    throw UnsupportedError('Requête non simulée : ${request.method} $path');
  }

  http.StreamedResponse _json(http.BaseRequest request, Object? data) {
    final bytes = utf8.encode(jsonEncode(data));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

SupabaseClient _client(_FakeSupabaseBackend backend) => SupabaseClient(
  'https://fake.supabase.test',
  'sb_publishable_test',
  httpClient: backend.httpClient,
);

ProductsCompanion _pendingProduct({
  required String name,
  String? barcode,
  String? sku,
  String? loyverseVariantId,
}) => ProductsCompanion.insert(
  name: name,
  barcode: Value(barcode),
  sku: Value(sku),
  loyverseVariantId: Value(loyverseVariantId),
  sellPrice: const Value(10),
  quantity: const Value(3),
  createdAt: Value(DateTime(2026, 1, 1)),
  updatedAt: Value(DateTime(2026, 1, 1)),
);

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'le premier appareil initialise un catalogue vide et termine '
    'l\'initialisation sans conflit',
    () async {
      final backend = _FakeSupabaseBackend();
      final service = CatalogSyncService(
        database: database,
        client: _client(backend),
      );
      await database.insertProduct(
        _pendingProduct(name: 'Produit A', barcode: '111'),
      );

      final report = await service.synchronize();

      expect(report.waitingForInitializer, isFalse);
      expect(report.uploaded, 1);
      expect(report.conflicts, 0);
      expect(backend.catalog['initialized_at'], isNotNull);
      expect(backend.products, hasLength(1));
    },
  );

  test(
    'un appareil qui arrive pendant l\'initialisation d\'un autre attend '
    'sans rien envoyer',
    () async {
      final backend = _FakeSupabaseBackend()
        ..initializingDeviceId = 'un-autre-appareil'
        ..initializationStartedAt = DateTime.now();
      final service = CatalogSyncService(
        database: database,
        client: _client(backend),
      );
      await database.insertProduct(
        _pendingProduct(name: 'Produit A', barcode: '111'),
      );

      final report = await service.synchronize();

      expect(report.waitingForInitializer, isTrue);
      expect(backend.products, isEmpty);
    },
  );

  test(
    'l\'appareil gagnant rapproche ses fiches locales avec des produits déjà '
    'présents côté serveur (reprise après une initialisation partielle), au '
    'lieu de créer des doublons',
    () async {
      // Le catalogue n'est pas encore marqué initialisé, mais une tentative
      // précédente (son propre essai interrompu, ou celui d'un autre
      // appareil dont le bail a expiré) y a déjà laissé une fiche.
      final backend = _FakeSupabaseBackend()
        ..products.add({
          'id': 'remote-uuid-1',
          'catalog_id': _catalogId,
          'barcode': '111',
          'sku': null,
          'name': 'Produit A',
          'category': null,
          'description': null,
          'cost_price': null,
          'sell_price': 10,
          'quantity': 3,
          'photo_object_path': null,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
          'synced_to_loyverse': false,
          'option_name': null,
          'option_value': null,
          'loyverse_item_id': null,
          'loyverse_variant_id': null,
          'group_id': null,
          'import_source': null,
          'import_batch_id': null,
          'revision': 1,
          'is_deleted': false,
        });
      final service = CatalogSyncService(
        database: database,
        client: _client(backend),
      );
      await database.insertProduct(
        _pendingProduct(name: 'Produit A (local)', barcode: '111'),
      );

      final report = await service.synchronize();

      expect(report.waitingForInitializer, isFalse);
      expect(report.merged, 1);
      expect(report.conflicts, 0);
      // Toujours une seule fiche côté serveur : la locale a été rapprochée
      // de l'existante plutôt que créée en double.
      expect(backend.products, hasLength(1));
      expect(backend.products.single['id'], 'remote-uuid-1');
    },
  );

  test(
    'une suppression distante retire la fiche locale non modifiée',
    () async {
      final backend = _FakeSupabaseBackend(initialized: true)
        ..products.add({
          'id': 'remote-uuid-2',
          'catalog_id': _catalogId,
          'barcode': '222',
          'sku': null,
          'name': 'Produit supprimé',
          'category': null,
          'description': null,
          'cost_price': null,
          'sell_price': 5,
          'quantity': 1,
          'photo_object_path': null,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
          'synced_to_loyverse': false,
          'option_name': null,
          'option_value': null,
          'loyverse_item_id': null,
          'loyverse_variant_id': null,
          'group_id': null,
          'import_source': null,
          'import_batch_id': null,
          'revision': 2,
          'is_deleted': true,
        });
      final service = CatalogSyncService(
        database: database,
        client: _client(backend),
      );
      final localId = await database.insertProduct(
        ProductsCompanion.insert(
          name: 'Produit supprimé',
          syncId: const Value('remote-uuid-2'),
          remoteRevision: const Value(1),
          syncPending: const Value(false),
          createdAt: Value(DateTime(2026, 1, 1)),
          updatedAt: Value(DateTime(2026, 1, 1)),
        ),
      );

      final report = await service.synchronize();

      expect(report.waitingForInitializer, isFalse);
      expect(await database.getProductById(localId), isNull);
    },
  );
}
