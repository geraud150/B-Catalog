import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/sync/loyverse_api_service.dart';
import 'package:boutique_catalog/features/sync/sync_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Product _buildProduct({
  int id = 1,
  String name = 'Produit',
  String? category = 'Cat',
  double? sellPrice = 10,
  String? photoPath,
  String? optionName,
  String? optionValue,
  String? groupId,
  String? loyverseItemId,
  String? loyverseVariantId,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    name: name,
    category: category,
    sellPrice: sellPrice,
    quantity: 5,
    photoPath: photoPath,
    optionName: optionName,
    optionValue: optionValue,
    groupId: groupId,
    loyverseItemId: loyverseItemId,
    loyverseVariantId: loyverseVariantId,
    createdAt: now,
    updatedAt: now,
    syncedToLoyverse: false,
  );
}

/// Double de test : évite tout appel réseau réel et permet de simuler des
/// échecs ciblés sur un produit donné.
class _FakeLoyverseApiService extends LoyverseApiService {
  _FakeLoyverseApiService({
    required super.database,
    this.failOnItemFor,
    this.dioErrorDetailsFor,
  }) : super(dio: Dio());

  final String? failOnItemFor;
  final String? dioErrorDetailsFor;
  final List<String> setInitialStockCalls = [];
  final List<String> uploadImageCalls = [];
  final List<List<int>> createOrUpdateItemCalls = [];

  @override
  Future<String> fetchStoreId() async => 'store-1';

  @override
  Future<String> fetchOrCreateCategoryId(String categoryName) async =>
      'cat-$categoryName';

  @override
  Future<LoyverseItemResult> createOrUpdateItem(
    List<Product> products, {
    required String categoryId,
    required String storeId,
  }) async {
    createOrUpdateItemCalls.add([for (final p in products) p.id]);
    if (products.any((p) => p.name == failOnItemFor)) {
      throw Exception('boom');
    }
    if (products.any((p) => p.name == dioErrorDetailsFor)) {
      final options = RequestOptions(path: '/items');
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: 400,
          // Forme réelle des erreurs Loyverse : enveloppées dans "errors",
          // pas exposées directement à la racine de la réponse.
          data: {
            'errors': [
              {
                'code': 'INVALID_VALUE',
                'details': 'Message lisible attendu par l\'utilisateur',
                'field': 'object.variants[0].sku',
              },
            ],
          },
        ),
      );
    }
    final itemId = 'item-${products.first.id}';
    return LoyverseItemResult(
      itemId: itemId,
      variantIds: [for (final p in products) 'variant-${p.id}'],
    );
  }

  @override
  Future<void> setInitialStock({
    required String variantId,
    required String storeId,
    required num quantity,
  }) async {
    setInitialStockCalls.add(variantId);
  }

  @override
  Future<void> uploadItemImage({
    required String itemId,
    required dynamic imageFile,
  }) async {
    uploadImageCalls.add(itemId);
  }
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('catégorie manquante : échec sans appel réseau', () async {
    final api = _FakeLoyverseApiService(database: database);
    final service = SyncService(database: database, apiService: api);

    final results = await service.syncProducts([
      _buildProduct(category: null),
    ]);

    expect(results, hasLength(1));
    expect(results.single.success, isFalse);
    expect(results.single.errorMessage, 'Catégorie manquante');
  });

  test('prix de vente manquant : échec sans appel réseau', () async {
    final api = _FakeLoyverseApiService(database: database);
    final service = SyncService(database: database, apiService: api);

    final results = await service.syncProducts([
      _buildProduct(sellPrice: null),
    ]);

    expect(results.single.success, isFalse);
    expect(results.single.errorMessage, 'Prix de vente manquant');
  });

  test(
    'le message d\'erreur Loyverse est extrait de "errors[].details", pas '
    'un dump brut de la réponse',
    () async {
      final api = _FakeLoyverseApiService(
        database: database,
        dioErrorDetailsFor: 'Produit défaillant',
      );
      final service = SyncService(database: database, apiService: api);

      final results = await service.syncProducts([
        _buildProduct(name: 'Produit défaillant'),
      ]);

      expect(
        results.single.errorMessage,
        'Message lisible attendu par l\'utilisateur',
      );
      // Ne doit pas remonter la Map brute (ex. "{code: ..., field: ...}").
      expect(results.single.errorMessage, isNot(contains('{code')));
    },
  );

  test(
    'un échec sur un produit n\'empêche pas la synchronisation des suivants',
    () async {
      final api = _FakeLoyverseApiService(
        database: database,
        failOnItemFor: 'Produit B',
      );
      final service = SyncService(database: database, apiService: api);

      final results = await service.syncProducts([
        _buildProduct(id: 1, name: 'Produit A'),
        _buildProduct(id: 2, name: 'Produit B'),
        _buildProduct(id: 3, name: 'Produit C'),
      ]);

      expect(results.map((r) => r.success), [true, false, true]);
      expect(results[1].errorMessage, contains('boom'));
      // Les produits en succès ont bien reçu leur stock initial.
      expect(api.setInitialStockCalls, ['variant-1', 'variant-3']);
    },
  );

  test('onProgress est appelé après chaque produit traité', () async {
    final api = _FakeLoyverseApiService(database: database);
    final service = SyncService(database: database, apiService: api);
    final progressCalls = <(int, int)>[];

    await service.syncProducts(
      [_buildProduct(id: 1), _buildProduct(id: 2)],
      onProgress: (done, total) => progressCalls.add((done, total)),
    );

    expect(progressCalls, [(1, 2), (2, 2)]);
  });

  test('la photo n\'est envoyée que si le fichier existe', () async {
    final api = _FakeLoyverseApiService(database: database);
    final service = SyncService(database: database, apiService: api);

    await service.syncProducts([
      _buildProduct(id: 1, photoPath: 'C:/chemin/inexistant.jpg'),
    ]);

    expect(api.uploadImageCalls, isEmpty);
  });

  test(
    'les produits partageant un groupId sont envoyés en un seul appel createOrUpdateItem',
    () async {
      final api = _FakeLoyverseApiService(database: database);
      final service = SyncService(database: database, apiService: api);

      final results = await service.syncProducts([
        _buildProduct(id: 1, name: 'Rouge à lèvres', groupId: 'g1'),
        _buildProduct(id: 2, name: 'Rouge à lèvres', groupId: 'g1'),
        _buildProduct(id: 3, name: 'Autre produit'),
      ]);

      expect(results.every((r) => r.success), isTrue);
      // Un seul appel pour les 2 membres du groupe, un autre pour le
      // produit autonome : 2 appels au total, pas 3.
      expect(api.createOrUpdateItemCalls, [
        [1, 2],
        [3],
      ]);
    },
  );

  test(
    'un membre incomplet d\'un groupe est écarté sans bloquer les autres membres',
    () async {
      final api = _FakeLoyverseApiService(database: database);
      final service = SyncService(database: database, apiService: api);

      final results = await service.syncProducts([
        _buildProduct(id: 1, name: 'Rouge à lèvres', groupId: 'g1'),
        _buildProduct(
          id: 2,
          name: 'Rouge à lèvres',
          groupId: 'g1',
          sellPrice: null,
        ),
      ]);

      final byId = {for (final r in results) r.product.id: r};
      expect(byId[1]!.success, isTrue);
      expect(byId[2]!.success, isFalse);
      expect(byId[2]!.errorMessage, 'Prix de vente manquant');
      // Le membre valide est bien envoyé seul, sans attendre le membre écarté.
      expect(api.createOrUpdateItemCalls, [
        [1],
      ]);
    },
  );

  test(
    'markSyncedToLoyverse enregistre les identifiants et marque le produit synchronisé',
    () async {
      final id = await database.insertProduct(
        ProductsCompanion.insert(
          name: 'Produit test',
          sellPrice: const Value(10),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await database.markSyncedToLoyverse(
        id: id,
        loyverseItemId: 'item-x',
        loyverseVariantId: 'variant-x',
      );

      final updated = await database.getProductById(id);
      expect(updated!.loyverseItemId, 'item-x');
      expect(updated.loyverseVariantId, 'variant-x');
      expect(updated.syncedToLoyverse, isTrue);
    },
  );
}
