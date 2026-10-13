import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/config.dart';
import '../../core/database/app_database.dart';

/// Identifiants renvoyés par Loyverse après création ou mise à jour d'un
/// article, nécessaires pour renseigner ensuite le stock initial et la
/// photo de chaque variante.
///
/// [variantIds] est dans le même ordre que la liste de produits passée à
/// [LoyverseApiService.createOrUpdateItem] (un seul élément pour un produit
/// autonome, un par membre pour un groupe de variantes).
class LoyverseItemResult {
  const LoyverseItemResult({required this.itemId, required this.variantIds});

  final String itemId;
  final List<String> variantIds;
}

/// Client de l'API Loyverse (https://developer.loyverse.com/docs/).
///
/// Toutes les requêtes portent le jeton d'accès `LOYVERSE_ACCESS_TOKEN`
/// défini dans `.env`. Le store_id de la boutique configurée
/// ([kLoyverseStoreName]) et les id de catégorie déjà résolus sont mis en
/// cache dans la base locale pour n'être interrogés qu'une seule fois,
/// plutôt qu'à chaque synchronisation.
class LoyverseApiService {
  LoyverseApiService({required this.database, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.loyverse.com/v1.0',
              connectTimeout: _timeout,
              sendTimeout: _timeout,
              receiveTimeout: _timeout,
              headers: {
                'Authorization':
                    'Bearer ${dotenv.env['LOYVERSE_ACCESS_TOKEN']}',
                'Content-Type': 'application/json',
              },
            ),
          );

  final AppDatabase database;
  final Dio _dio;

  static const _timeout = Duration(seconds: 20);
  static const _storeIdCacheKey = 'loyverse_store_id';

  /// Exécute [action] et la retente une seule fois si l'échec est un
  /// problème réseau transitoire (timeout, connexion perdue...) plutôt
  /// qu'une réponse d'erreur explicite de Loyverse (ex. validation
  /// refusée), qui échouerait de toute façon à nouveau à l'identique.
  Future<T> _withRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      if (!_isTransientNetworkError(e)) rethrow;
      return await action();
    }
  }

  bool _isTransientNetworkError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }

  /// Résout le store_id de la boutique [kLoyverseStoreName] (recherche
  /// insensible à la casse), en le mettant en cache localement pour ne
  /// l'interroger qu'une seule fois.
  Future<String> fetchStoreId() async {
    final cached = await database.getLoyverseCacheValue(_storeIdCacheKey);
    if (cached != null) return cached;

    final response = await _withRetry(
      () => _dio.get<Map<String, dynamic>>('/stores'),
    );
    final stores = (response.data?['stores'] as List?) ?? const [];
    final match = stores.cast<Map<String, dynamic>>().firstWhere(
      (store) =>
          (store['name'] as String?)?.trim().toLowerCase() ==
          kLoyverseStoreName.trim().toLowerCase(),
      orElse: () => throw StateError(
        'Aucune boutique nommée "$kLoyverseStoreName" trouvée sur ce compte Loyverse.',
      ),
    );

    final storeId = match['id'] as String;
    await database.setLoyverseCacheValue(_storeIdCacheKey, storeId);
    return storeId;
  }

  /// Résout l'id de la catégorie [categoryName] (recherche insensible à la
  /// casse) ; la crée sur Loyverse si elle n'existe pas encore. Met le
  /// résultat en cache localement pour éviter les appels répétés sur les
  /// mêmes catégories.
  Future<String> fetchOrCreateCategoryId(String categoryName) async {
    final normalized = categoryName.trim();
    final cacheKey = 'loyverse_category:${normalized.toLowerCase()}';

    final cached = await database.getLoyverseCacheValue(cacheKey);
    if (cached != null) return cached;

    final response = await _withRetry(
      () => _dio.get<Map<String, dynamic>>('/categories'),
    );
    final categories = (response.data?['categories'] as List?) ?? const [];
    final existing = categories.cast<Map<String, dynamic>>().firstWhere(
      (category) =>
          (category['name'] as String?)?.trim().toLowerCase() ==
          normalized.toLowerCase(),
      orElse: () => const {},
    );

    final categoryId = existing.isNotEmpty
        ? existing['id'] as String
        : await _createCategory(normalized);

    await database.setLoyverseCacheValue(cacheKey, categoryId);
    return categoryId;
  }

  Future<String> _createCategory(String name) async {
    final response = await _withRetry(
      () => _dio.post<Map<String, dynamic>>('/categories', data: {'name': name}),
    );
    return response.data!['id'] as String;
  }

  /// Crée un nouvel article sur Loyverse à partir de [products], ou le met
  /// à jour si l'un d'eux porte déjà un `loyverseItemId` (déjà synchronisé
  /// seul ou avec d'autres membres du groupe). [products] contient un seul
  /// élément pour un produit autonome, ou tous les membres d'un groupe de
  /// variantes pour qu'ils soient créés comme un seul article à plusieurs
  /// variantes plutôt qu'un article par produit.
  ///
  /// Le nom, la catégorie, la description et `option1_name` de l'article
  /// sont ceux du premier élément de [products] (ils doivent être
  /// identiques entre membres d'un même groupe). Enregistre les
  /// identifiants renvoyés (item_id partagé, variant_id par variante) sur
  /// chaque produit local et les marque comme synchronisés.
  Future<LoyverseItemResult> createOrUpdateItem(
    List<Product> products, {
    required String categoryId,
    required String storeId,
  }) async {
    assert(products.isNotEmpty);

    // Un produit sans loyverseVariantId local peut malgré tout déjà exister
    // côté Loyverse : par ex. une tentative précédente a réussi côté serveur
    // mais planté ou expiré localement avant d'enregistrer ses identifiants.
    // Sans cette réconciliation, la création serait retentée à l'identique
    // et rejetée sur "Duplicate variant SKU" au lieu de mettre à jour.
    final reconciled = await _reconcileByPendingSku(products);

    try {
      return await _postItem(reconciled, categoryId: categoryId, storeId: storeId);
    } on DioException catch (e) {
      if (!_isStaleItemReference(e)) rethrow;
      // L'article lié localement (par une synchronisation antérieure ou la
      // réconciliation ci-dessus) n'existe plus côté Loyverse — supprimé
      // manuellement, par exemple lors d'un nettoyage de doublons. On oublie
      // ce lien obsolète et on recrée l'article à neuf plutôt que d'échouer
      // indéfiniment sur le même id introuvable.
      for (final product in reconciled) {
        await database.clearLoyverseLink(product.id);
      }
      final fresh = [
        for (final product in reconciled)
          product.copyWith(
            loyverseItemId: const Value(null),
            loyverseVariantId: const Value(null),
          ),
      ];
      return await _postItem(fresh, categoryId: categoryId, storeId: storeId);
    }
  }

  /// `true` si [e] correspond à Loyverse refusant un `object.id` (ou
  /// `variant_id`) qui ne correspond à aucun article/variant existant.
  ///
  /// Les erreurs de validation Loyverse sont enveloppées dans un tableau
  /// `errors` (ex. `{"errors": [{"code": "NOT_FOUND", "field": "object.id",
  /// "details": "..."}]}`) et non exposées directement à la racine de la
  /// réponse.
  bool _isStaleItemReference(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return false;
    final errors = data['errors'];
    if (errors is! List) return false;
    return errors.any((error) {
      if (error is! Map) return false;
      final field = error['field'] as String?;
      return error['code'] == 'NOT_FOUND' &&
          (field == 'object.id' || field?.endsWith('.variant_id') == true);
    });
  }

  Future<LoyverseItemResult> _postItem(
    List<Product> products, {
    required String categoryId,
    required String storeId,
  }) async {
    final first = products.first;
    final optionName = first.optionName?.trim();

    final body = <String, dynamic>{
      'item_name': first.name,
      'category_id': categoryId,
      'description': first.description,
      'track_stock': true,
      'sold_by_weight': false,
      if (optionName != null && optionName.isNotEmpty)
        'option1_name': optionName,
      'variants': [
        for (final product in products) _variantPayload(product, storeId),
      ],
    };

    // L'id existant peut se trouver sur n'importe quel membre du groupe
    // (par ex. un produit synchronisé seul avant d'être dupliqué en
    // variante) : on ne peut pas supposer qu'il est sur le premier.
    final existingItemId = products
        .map((p) => p.loyverseItemId)
        .firstWhere((id) => id != null, orElse: () => null);
    if (existingItemId != null) {
      body['id'] = existingItemId;
    }

    final response = await _withRetry(
      () => _dio.post<Map<String, dynamic>>('/items', data: body),
    );
    final data = response.data!;
    // L'identifiant d'un article Loyverse est "id" ; "item_id" n'existe que
    // sur chaque variante, en référence vers son article parent.
    final itemId = data['id'] as String;
    final variantsData = (data['variants'] as List)
        .cast<Map<String, dynamic>>();
    final variantIds = [
      for (final variant in variantsData) variant['variant_id'] as String,
    ];

    for (var i = 0; i < products.length; i++) {
      await database.markSyncedToLoyverse(
        id: products[i].id,
        loyverseItemId: itemId,
        loyverseVariantId: variantIds[i],
      );
    }

    return LoyverseItemResult(itemId: itemId, variantIds: variantIds);
  }

  /// Pour les [products] qui n'ont pas encore de `loyverseVariantId` local,
  /// vérifie via `GET /v1.0/variants?sku=...` si un variant portant le même
  /// SKU existe déjà sur Loyverse, et adopte ses identifiants existants le
  /// cas échéant (en les enregistrant aussi en base). Les produits sans SKU
  /// ou déjà liés sont retournés inchangés.
  Future<List<Product>> _reconcileByPendingSku(List<Product> products) async {
    final reconciled = <Product>[];
    for (final product in products) {
      final sku = product.sku?.trim();
      if (product.loyverseVariantId != null || sku == null || sku.isEmpty) {
        reconciled.add(product);
        continue;
      }

      final response = await _withRetry(
        () => _dio.get<Map<String, dynamic>>(
          '/variants',
          queryParameters: {'sku': sku},
        ),
      );
      final variants = (response.data?['variants'] as List?) ?? const [];
      if (variants.isEmpty) {
        reconciled.add(product);
        continue;
      }

      final match = variants.first as Map<String, dynamic>;
      final existingItemId = match['item_id'] as String;
      final existingVariantId = match['variant_id'] as String;

      await database.markSyncedToLoyverse(
        id: product.id,
        loyverseItemId: existingItemId,
        loyverseVariantId: existingVariantId,
      );

      reconciled.add(
        product.copyWith(
          loyverseItemId: Value(existingItemId),
          loyverseVariantId: Value(existingVariantId),
        ),
      );
    }
    return reconciled;
  }

  Map<String, dynamic> _variantPayload(Product product, String storeId) {
    final optionValue = product.optionValue?.trim();

    final variant = <String, dynamic>{
      'sku': product.sku,
      'barcode': product.barcode,
      'cost': product.costPrice,
      'default_pricing_type': 'FIXED',
      'default_price': product.sellPrice,
      if (optionValue != null && optionValue.isNotEmpty)
        'option1_value': optionValue,
      'stores': [
        {
          'store_id': storeId,
          // Le pricing_type par boutique est indépendant de
          // default_pricing_type au niveau de la variante ; sans lui,
          // Loyverse le prend par défaut à VARIABLE (prix libre en caisse),
          // ce qui rejette toute valeur de `price` fournie ici.
          'pricing_type': 'FIXED',
          'price': product.sellPrice,
          'available_for_sale': true,
        },
      ],
    };
    if (product.loyverseVariantId != null) {
      variant['variant_id'] = product.loyverseVariantId;
    }
    return variant;
  }

  /// Renseigne le stock initial de la variante [variantId] sur la boutique
  /// [storeId].
  Future<void> setInitialStock({
    required String variantId,
    required String storeId,
    required num quantity,
  }) {
    return _withRetry(
      () => _dio.post<void>(
        '/inventory',
        data: {
          'inventory_levels': [
            {
              'variant_id': variantId,
              'store_id': storeId,
              'stock_after': quantity,
            },
          ],
        },
      ),
    );
  }

  /// Envoie la photo produit (déjà compressée en JPEG en Phase 5) comme
  /// image de l'article [itemId].
  Future<void> uploadItemImage({
    required String itemId,
    required File imageFile,
  }) async {
    final bytes = await imageFile.readAsBytes();
    await _withRetry(
      () => _dio.post<void>(
        '/items/$itemId/image',
        data: bytes,
        options: Options(headers: {'Content-Type': 'image/jpeg'}),
      ),
    );
  }
}
