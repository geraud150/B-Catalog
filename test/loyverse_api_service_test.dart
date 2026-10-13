import 'dart:convert';

import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/sync/loyverse_api_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Insère un produit réel en base et retourne la ligne persistée : nécessaire
/// ici (contrairement à un `Product(...)` construit à la volée) car
/// [LoyverseApiService.createOrUpdateItem] écrit son résultat via
/// `database.markSyncedToLoyverse(id: ...)`, qui ne fait rien si la ligne
/// n'existe pas.
Future<Product> _insertProduct(
  AppDatabase database, {
  String name = 'Rouge à lèvres mat',
  String? sku,
  String? barcode,
  String? optionName,
  String? optionValue,
  String? groupId,
  String? loyverseItemId,
  String? loyverseVariantId,
}) async {
  final now = DateTime(2026, 1, 1);
  final id = await database.insertProduct(
    ProductsCompanion.insert(
      name: name,
      category: const Value('Cosmétiques'),
      sku: Value(sku),
      barcode: Value(barcode),
      costPrice: const Value(5),
      sellPrice: const Value(12),
      quantity: const Value(3),
      optionName: Value(optionName),
      optionValue: Value(optionValue),
      groupId: Value(groupId),
      loyverseItemId: Value(loyverseItemId),
      loyverseVariantId: Value(loyverseVariantId),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  );
  return (await database.getProductById(id))!;
}

/// Adaptateur Dio de test : capture la dernière requête envoyée et répond
/// avec la forme réelle d'un article Loyverse — son identifiant sous la clé
/// "id" (et non "item_id", qui n'existe que sur chaque variante) — sans
/// réseau réel.
///
/// [existingVariantsBySku] simule des variants déjà présents sur Loyverse
/// pour un SKU donné (réponse de `GET /v1.0/variants?sku=...`) ; par défaut,
/// aucun SKU n'a de correspondance, donc la réconciliation par SKU est un
/// no-op et ne change rien au comportement des autres tests.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.existingVariantsBySku = const {}});

  final Map<String, ({String itemId, String variantId})> existingVariantsBySku;

  RequestOptions? lastRequest;
  Map<String, dynamic>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/variants') {
      final sku = options.queryParameters['sku'] as String?;
      final existing = existingVariantsBySku[sku];
      final responseBody = {
        'variants': existing == null
            ? []
            : [
                {
                  'item_id': existing.itemId,
                  'variant_id': existing.variantId,
                },
              ],
      };
      return ResponseBody.fromString(
        jsonEncode(responseBody),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    lastRequest = options;
    lastBody = options.data as Map<String, dynamic>;

    final variants = (lastBody!['variants'] as List).cast<Map>();
    final responseBody = {
      'id': (lastBody!['id'] as String?) ?? 'new-item-1',
      'variants': [
        for (var i = 0; i < variants.length; i++)
          {'variant_id': (variants[i]['variant_id'] as String?) ?? 'new-variant-$i'},
      ],
    };

    return ResponseBody.fromString(
      jsonEncode(responseBody),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase database;
  late _FakeAdapter adapter;
  late LoyverseApiService api;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    adapter = _FakeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    api = LoyverseApiService(database: database, dio: dio);
  });

  tearDown(() => database.close());

  test(
    'un groupe de variantes est envoyé en un seul appel avec plusieurs variants',
    () async {
      final p1 = await _insertProduct(
        database,
        sku: 'RAL-ROUGE',
        optionName: 'Couleur',
        optionValue: 'Rouge',
        groupId: 'group-1',
      );
      final p2 = await _insertProduct(
        database,
        sku: 'RAL-ROSE',
        optionName: 'Couleur',
        optionValue: 'Rose',
        groupId: 'group-1',
      );

      final result = await api.createOrUpdateItem(
        [p1, p2],
        categoryId: 'cat-1',
        storeId: 'store-1',
      );

      final body = adapter.lastBody!;
      expect(body['item_name'], 'Rouge à lèvres mat');
      expect(body['option1_name'], 'Couleur');
      expect(body.containsKey('id'), isFalse);

      final variants = (body['variants'] as List).cast<Map>();
      expect(variants, hasLength(2));
      expect(variants[0]['sku'], 'RAL-ROUGE');
      expect(variants[0]['option1_value'], 'Rouge');
      expect(variants[1]['sku'], 'RAL-ROSE');
      expect(variants[1]['option1_value'], 'Rose');

      expect(result.variantIds, hasLength(2));

      // item_id partagé, variant_id distinct, enregistrés en base pour
      // chaque membre du groupe.
      final updated1 = await database.getProductById(p1.id);
      final updated2 = await database.getProductById(p2.id);
      expect(updated1!.loyverseItemId, result.itemId);
      expect(updated2!.loyverseItemId, result.itemId);
      expect(updated1.loyverseVariantId, isNot(updated2.loyverseVariantId));
      expect(updated1.loyverseVariantId, result.variantIds[0]);
      expect(updated2.loyverseVariantId, result.variantIds[1]);
      expect(updated1.syncedToLoyverse, isTrue);
      expect(updated2.syncedToLoyverse, isTrue);
    },
  );

  test(
    'un produit déjà synchronisé seul avant d\'être groupé déclenche une mise à jour',
    () async {
      // Déjà synchronisé individuellement avant sa mise en groupe.
      final p1 = await _insertProduct(
        database,
        sku: 'RAL-ROUGE',
        optionValue: 'Rouge',
        groupId: 'group-1',
        loyverseItemId: 'existing-item',
        loyverseVariantId: 'existing-variant',
      );
      // Nouvelle variante, jamais synchronisée.
      final p2 = await _insertProduct(
        database,
        sku: 'RAL-ROSE',
        optionValue: 'Rose',
        groupId: 'group-1',
      );

      await api.createOrUpdateItem(
        [p1, p2],
        categoryId: 'cat-1',
        storeId: 'store-1',
      );

      final body = adapter.lastBody!;
      expect(body['id'], 'existing-item');

      final variants = (body['variants'] as List).cast<Map>();
      expect(variants[0]['variant_id'], 'existing-variant');
      expect(variants[1].containsKey('variant_id'), isFalse);
    },
  );

  test(
    'l\'id existant est retrouvé même s\'il ne se trouve pas sur le premier membre',
    () async {
      final p1 = await _insertProduct(
        database,
        sku: 'A',
        optionValue: 'Rouge',
        groupId: 'group-1',
      );
      final p2 = await _insertProduct(
        database,
        sku: 'B',
        optionValue: 'Rose',
        groupId: 'group-1',
        loyverseItemId: 'existing-item',
        loyverseVariantId: 'existing-variant',
      );

      await api.createOrUpdateItem(
        [p1, p2],
        categoryId: 'cat-1',
        storeId: 'store-1',
      );

      expect(adapter.lastBody!['id'], 'existing-item');
    },
  );

  test('un produit autonome (liste à un élément) fonctionne comme avant', () async {
    final p1 = await _insertProduct(database, sku: 'SOLO');

    final result = await api.createOrUpdateItem(
      [p1],
      categoryId: 'cat-1',
      storeId: 'store-1',
    );

    expect(result.variantIds, hasLength(1));
    final product = await database.getProductById(p1.id);
    expect(product!.loyverseVariantId, result.variantIds.single);
  });

  test(
    'un SKU déjà présent sur Loyverse est adopté au lieu de dupliquer '
    '(reconciliation)',
    () async {
      final reconcilingAdapter = _FakeAdapter(
        existingVariantsBySku: {
          'cb-2026': (itemId: 'existing-item-x', variantId: 'existing-variant-x'),
        },
      );
      final reconcilingApi = LoyverseApiService(
        database: database,
        dio: Dio()..httpClientAdapter = reconcilingAdapter,
      );
      // Jamais synchronisé localement (pas de loyverseVariantId), mais le
      // SKU existe déjà côté Loyverse : simule une tentative précédente qui
      // a réussi côté serveur avant de planter localement.
      final p1 = await _insertProduct(database, sku: 'cb-2026');

      final result = await reconcilingApi.createOrUpdateItem(
        [p1],
        categoryId: 'cat-1',
        storeId: 'store-1',
      );

      final body = reconcilingAdapter.lastBody!;
      expect(body['id'], 'existing-item-x');
      final variants = (body['variants'] as List).cast<Map>();
      expect(variants.single['variant_id'], 'existing-variant-x');
      expect(result.itemId, 'existing-item-x');

      final updated = await database.getProductById(p1.id);
      expect(updated!.loyverseItemId, 'existing-item-x');
      expect(updated.loyverseVariantId, 'existing-variant-x');
    },
  );

  test(
    'un item lié localement mais supprimé sur Loyverse est recréé, pas '
    'retenté indéfiniment',
    () async {
      final staleAdapter = _StaleItemAdapter(
        staleItemId: 'deleted-item',
        delegate: adapter,
      );
      final staleApi = LoyverseApiService(
        database: database,
        dio: Dio()..httpClientAdapter = staleAdapter,
      );
      // Lien local vers un article qui n'existe plus côté Loyverse (par ex.
      // supprimé manuellement lors d'un nettoyage de doublons).
      final p1 = await _insertProduct(
        database,
        sku: 'RF-300L',
        loyverseItemId: 'deleted-item',
        loyverseVariantId: 'deleted-variant',
      );

      final result = await staleApi.createOrUpdateItem(
        [p1],
        categoryId: 'cat-1',
        storeId: 'store-1',
      );

      expect(staleAdapter.rejectedAttempts, 1);
      expect(result.itemId, isNot('deleted-item'));

      final updated = await database.getProductById(p1.id);
      expect(updated!.loyverseItemId, result.itemId);
      expect(updated.loyverseItemId, isNot('deleted-item'));
      expect(updated.syncedToLoyverse, isTrue);
    },
  );

  group('retry sur incident réseau transitoire', () {
    test(
      'un timeout de connexion est retenté une fois puis réussit',
      () async {
        final flaky = _FlakyThenSucceedAdapter(
          failuresBeforeSuccess: 1,
          failureType: DioExceptionType.connectionTimeout,
          delegate: adapter,
          pathToFail: '/items',
        );
        final flakyApi = LoyverseApiService(
          database: database,
          dio: Dio()..httpClientAdapter = flaky,
        );
        final p1 = await _insertProduct(database, sku: 'SOLO');

        final result = await flakyApi.createOrUpdateItem(
          [p1],
          categoryId: 'cat-1',
          storeId: 'store-1',
        );

        expect(flaky.attempts, 2);
        expect(result.variantIds, hasLength(1));
      },
    );

    test(
      'deux timeouts consécutifs échouent (une seule tentative de retry)',
      () async {
        final flaky = _FlakyThenSucceedAdapter(
          failuresBeforeSuccess: 2,
          failureType: DioExceptionType.connectionTimeout,
          delegate: adapter,
          pathToFail: '/items',
        );
        final flakyApi = LoyverseApiService(
          database: database,
          dio: Dio()..httpClientAdapter = flaky,
        );
        final p1 = await _insertProduct(database, sku: 'SOLO');

        await expectLater(
          flakyApi.createOrUpdateItem(
            [p1],
            categoryId: 'cat-1',
            storeId: 'store-1',
          ),
          throwsA(isA<DioException>()),
        );
        expect(flaky.attempts, 2);
      },
    );

    test(
      'une erreur de validation (réponse reçue) n\'est jamais retentée',
      () async {
        final rejecting = _RejectingAdapter(
          pathToFail: '/items',
          delegate: adapter,
        );
        final rejectingApi = LoyverseApiService(
          database: database,
          dio: Dio()..httpClientAdapter = rejecting,
        );
        final p1 = await _insertProduct(database, sku: 'SOLO');

        await expectLater(
          rejectingApi.createOrUpdateItem(
            [p1],
            categoryId: 'cat-1',
            storeId: 'store-1',
          ),
          throwsA(isA<DioException>()),
        );
        expect(rejecting.attempts, 1);
      },
    );
  });
}

/// Échoue avec [failureType] les [failuresBeforeSuccess] premiers appels au
/// chemin [pathToFail], puis délègue à [delegate] pour simuler une reprise
/// réseau. Les requêtes vers d'autres chemins (ex. la réconciliation par
/// SKU sur `/variants`) passent directement à [delegate], pour isoler le
/// comportement testé sur l'appel qui nous intéresse.
class _FlakyThenSucceedAdapter implements HttpClientAdapter {
  _FlakyThenSucceedAdapter({
    required this.failuresBeforeSuccess,
    required this.failureType,
    required this.delegate,
    required this.pathToFail,
  });

  final int failuresBeforeSuccess;
  final DioExceptionType failureType;
  final HttpClientAdapter delegate;
  final String pathToFail;
  int attempts = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path != pathToFail) {
      return delegate.fetch(options, requestStream, cancelFuture);
    }
    attempts++;
    if (attempts <= failuresBeforeSuccess) {
      throw DioException(requestOptions: options, type: failureType);
    }
    return delegate.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

/// Simule une réponse d'erreur explicite de Loyverse (réponse HTTP reçue,
/// pas un incident réseau) pour le chemin [pathToFail] uniquement : ne doit
/// jamais être retentée. Les autres chemins passent à [delegate].
class _RejectingAdapter implements HttpClientAdapter {
  _RejectingAdapter({required this.pathToFail, required this.delegate});

  final String pathToFail;
  final HttpClientAdapter delegate;
  int attempts = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path != pathToFail) {
      return delegate.fetch(options, requestStream, cancelFuture);
    }
    attempts++;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: 400,
        data: {'code': 'INVALID_VALUE'},
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Simule un article Loyverse supprimé : rejette tout `POST /items` dont le
/// corps référence encore [staleItemId], mais délègue normalement (donc
/// réussit) une fois cet id retiré du corps par la tentative de recréation.
class _StaleItemAdapter implements HttpClientAdapter {
  _StaleItemAdapter({required this.staleItemId, required this.delegate});

  final String staleItemId;
  final HttpClientAdapter delegate;
  int rejectedAttempts = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data;
    if (options.path == '/items' &&
        body is Map &&
        body['id'] == staleItemId) {
      rejectedAttempts++;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: 404,
          // Forme réelle confirmée par les réponses Loyverse observées en
          // production : les erreurs sont enveloppées dans un tableau
          // "errors", pas exposées directement à la racine.
          data: {
            'errors': [
              {
                'code': 'NOT_FOUND',
                'details': "The item with ID '$staleItemId' not found",
                'field': 'object.id',
              },
            ],
          },
        ),
      );
    }
    return delegate.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
