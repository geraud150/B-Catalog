import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';

import '../utils/sku_generator.dart';

part 'app_database.g.dart';

/// Table Drift décrivant un produit et sa variante simple (teinte/taille).
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get barcode => text().nullable()();
  TextColumn get sku => text().nullable()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get costPrice => real().nullable()();
  RealColumn get sellPrice => real().nullable()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get syncedToLoyverse =>
      boolean().withDefault(const Constant(false))();
  TextColumn get optionName => text().nullable()();
  TextColumn get optionValue => text().nullable()();
  TextColumn get loyverseItemId => text().nullable()();
  TextColumn get loyverseVariantId => text().nullable()();

  /// Identifiant partagé par tous les produits locaux qui représentent les
  /// variantes d'un même article Loyverse (voir generateHandle() dans
  /// core/utils/).
  TextColumn get groupId => text().nullable()();

  /// Origine du produit lorsqu'il n'a pas été saisi à la main dans l'app
  /// (ex. `"docx_import"`, voir features/import/). Null pour une saisie
  /// manuelle.
  TextColumn get importSource => text().nullable()();

  /// Identifiant (UUID) partagé par tous les produits créés lors d'un même
  /// import en masse, pour retrouver ou tracer un lot dans son ensemble.
  TextColumn get importBatchId => text().nullable()();
  TextColumn get syncId =>
      text().nullable().clientDefault(() => const Uuid().v4())();
  IntColumn get remoteRevision => integer().nullable()();
  BoolColumn get syncPending => boolean().withDefault(const Constant(true))();
}

class ProductSyncTombstones extends Table {
  TextColumn get syncId => text()();
  IntColumn get remoteRevision => integer()();
  DateTimeColumn get deletedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {syncId};
}

class CatalogSyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Cache local des résultats de recherche de code-barres auprès des sources
/// externes (Open Beauty Facts, Open Products Facts, Icecat, UPC Item DB),
/// pour éviter de refaire un appel réseau sur un code-barres déjà résolu.
class BarcodeLookupCache extends Table {
  TextColumn get barcode => text()();
  TextColumn get source => text()();
  TextColumn get name => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get sku => text().nullable()();
  TextColumn get optionCapacite => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {barcode};
}

/// Cache local générique (clé/valeur) pour les identifiants Loyverse résolus
/// une fois pour toutes : store_id de la boutique configurée et id des
/// catégories déjà créées ou retrouvées côté Loyverse.
class LoyverseCache extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get cacheValue => text()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

@DriftDatabase(
  tables: [
    Products,
    BarcodeLookupCache,
    LoyverseCache,
    ProductSyncTombstones,
    CatalogSyncState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(barcodeLookupCache);
      }
      if (from < 3) {
        await m.addColumn(products, products.loyverseItemId);
        await m.addColumn(products, products.loyverseVariantId);
        await m.createTable(loyverseCache);
      }
      if (from < 4) {
        await m.addColumn(products, products.groupId);
      }
      if (from < 5) {
        await m.addColumn(barcodeLookupCache, barcodeLookupCache.description);
        await m.addColumn(barcodeLookupCache, barcodeLookupCache.sku);
        await m.addColumn(
          barcodeLookupCache,
          barcodeLookupCache.optionCapacite,
        );
        await m.addColumn(barcodeLookupCache, barcodeLookupCache.imageUrl);
      }
      if (from < 6) {
        await assignMissingSkus();
      }
      if (from < 7) {
        await m.addColumn(products, products.importSource);
        await m.addColumn(products, products.importBatchId);
      }
      if (from < 8) {
        await m.addColumn(products, products.syncId);
        await m.addColumn(products, products.remoteRevision);
        await m.addColumn(products, products.syncPending);
        await m.createTable(productSyncTombstones);
        await m.createTable(catalogSyncState);

        final existingProducts = await select(products).get();
        for (final product in existingProducts) {
          await (update(
            products,
          )..where((tbl) => tbl.id.equals(product.id))).write(
            ProductsCompanion(
              syncId: Value(const Uuid().v4()),
              syncPending: const Value(true),
            ),
          );
        }
      }
    },
  );

  /// Corrige les produits dont le SKU est vide (créés avant l'introduction
  /// de la génération automatique de SKU, Phase 11) en leur assignant un
  /// [generateSafeSku()]. Appelée une seule fois à la mise à jour vers le
  /// schéma 6 ; non privée pour rester directement testable.
  ///
  /// Retourne le nombre de produits corrigés, et le logue dans la console.
  Future<int> assignMissingSkus() async {
    final allProducts = await select(products).get();
    final missingSku = allProducts.where(
      (p) => p.sku == null || p.sku!.trim().isEmpty,
    );

    var fixedCount = 0;
    for (final product in missingSku) {
      await (update(products)..where((tbl) => tbl.id.equals(product.id))).write(
        ProductsCompanion(sku: Value(generateSafeSku())),
      );
      fixedCount++;
    }

    debugPrint(
      '[AppDatabase] migration v6 : $fixedCount produit(s) corrigé(s) '
      '(SKU manquant généré automatiquement).',
    );
    return fixedCount;
  }

  Future<int> insertProduct(ProductsCompanion product) {
    return into(products).insert(product);
  }

  /// Insère tous les [companions] dans une seule transaction : soit tout
  /// est enregistré, soit rien (une erreur sur une ligne annule le lot
  /// entier). Les lignes sont envoyées par paquets de [chunkSize] via des
  /// batches Drift, et [onProgress] est appelé après chaque paquet avec le
  /// nombre de lignes déjà écrites et le total, pour alimenter une barre de
  /// progression.
  ///
  /// Retourne le nombre de produits insérés.
  Future<int> insertProductsInTransaction(
    List<ProductsCompanion> companions, {
    void Function(int done, int total)? onProgress,
    int chunkSize = 50,
  }) {
    return transaction(() async {
      final total = companions.length;
      var done = 0;
      for (var start = 0; start < total; start += chunkSize) {
        final end = start + chunkSize < total ? start + chunkSize : total;
        final chunk = companions.sublist(start, end);
        await batch((b) => b.insertAll(products, chunk));
        done = end;
        onProgress?.call(done, total);
      }
      return done;
    });
  }

  /// Nombre de produits issus d'un import (`importSource` non nul) dont le
  /// SKU, le code-barres ET la photo sont encore tous vides, c'est-à-dire
  /// les fiches importées qu'il reste entièrement à compléter à la main.
  ///
  /// Dès qu'un seul de ces trois champs est renseigné, la fiche sort du
  /// compte : l'indicateur diminue donc au fur et à mesure de la saisie.
  Future<int> countImportedProductsToComplete() async {
    final countExpression = products.id.count();
    final query = selectOnly(products)
      ..addColumns([countExpression])
      ..where(_importedToCompleteFilter);
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  /// Flux des produits comptés par [countImportedProductsToComplete], triés
  /// par nom : alimente la liste filtrée ouverte depuis le lien "Compléter
  /// les fiches" de l'accueil. Une fiche disparaît du flux dès qu'un de ses
  /// trois champs (SKU, code-barres, photo) est renseigné.
  Stream<List<Product>> watchImportedProductsToComplete() {
    return (select(products)
          ..where((_) => _importedToCompleteFilter)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.name)]))
        .watch();
  }

  /// Condition SQL "fiche importée dont SKU, code-barres et photo sont tous
  /// vides", partagée par le compteur et le flux ci-dessus pour qu'ils ne
  /// divergent jamais.
  Expression<bool> get _importedToCompleteFilter {
    Expression<bool> isBlank(TextColumn column) =>
        column.isNull() | column.trim().equals('');

    return products.importSource.isNotNull() &
        isBlank(products.sku) &
        isBlank(products.barcode) &
        isBlank(products.photoPath);
  }

  /// Catégories distinctes déjà utilisées par au moins un produit (valeurs
  /// non vides, espaces de bord retirés), triées alphabétiquement. Alimente
  /// l'autocomplétion du champ Catégorie du formulaire produit : il n'existe
  /// pas de liste de catégories gérée à part.
  Future<List<String>> getDistinctCategories() async {
    final trimmed = products.category.trim();
    final query = selectOnly(products, distinct: true)
      ..addColumns([trimmed])
      ..where(products.category.isNotNull() & trimmed.equals('').not())
      ..orderBy([OrderingTerm(expression: trimmed)]);
    final rows = await query.get();
    return [for (final row in rows) ?row.read(trimmed)];
  }

  Future<bool> updateProduct(ProductsCompanion product) {
    return update(products).replace(
      product.copyWith(
        updatedAt: Value(DateTime.now()),
        syncPending: const Value(true),
      ),
    );
  }

  Future<int> deleteProduct(int id) async {
    return transaction(() async {
      final product = await getProductById(id);
      if (product == null) return 0;

      if (product.remoteRevision != null && product.syncId != null) {
        await into(productSyncTombstones).insertOnConflictUpdate(
          ProductSyncTombstonesCompanion.insert(
            syncId: product.syncId!,
            remoteRevision: product.remoteRevision!,
            deletedAt: Value(DateTime.now()),
          ),
        );
      }

      return (delete(products)..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  Future<List<Product>> getProductsPendingSync() =>
      (select(products)..where((tbl) => tbl.syncPending.equals(true))).get();

  Future<Product?> getProductBySyncId(String syncId) => (select(
    products,
  )..where((tbl) => tbl.syncId.equals(syncId))).getSingleOrNull();

  Future<void> setCatalogSyncState(String key, String value) =>
      into(catalogSyncState).insertOnConflictUpdate(
        CatalogSyncStateCompanion.insert(key: key, value: value),
      );

  Future<String?> getCatalogSyncState(String key) async {
    final state = await (select(
      catalogSyncState,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return state?.value;
  }

  /// Identifiant persistant de l'installation, utilisé uniquement pour
  /// départager atomiquement le tout premier appareil qui initialise le cloud.
  Future<String> getOrCreateCatalogDeviceId() async {
    const key = 'device_id';
    final existing = await getCatalogSyncState(key);
    if (existing != null) return existing;

    final id = const Uuid().v4();
    await setCatalogSyncState(key, id);
    return id;
  }

  /// Associe une fiche locale jusque-là inconnue du cloud à une fiche distante
  /// reconnue par un identifiant métier stable. Elle reste à envoyer afin que
  /// ses données locales soient fusionnées dans la fiche distante.
  Future<void> adoptRemoteProductIdentity({
    required int localId,
    required String syncId,
    required int remoteRevision,
  }) {
    return (update(products)..where((tbl) => tbl.id.equals(localId))).write(
      ProductsCompanion(
        syncId: Value(syncId),
        remoteRevision: Value(remoteRevision),
        syncPending: const Value(true),
      ),
    );
  }

  /// Deux fiches locales ayant été reconnues comme le même article cloud sont
  /// réduites à une seule. Les informations renseignées priment sur les
  /// champs vides et le stock conserve la valeur la plus haute : additionner
  /// compterait deux fois le même stock physique.
  Future<void> mergeUnsyncedDuplicateInto({
    required int canonicalId,
    required int duplicateId,
  }) {
    return transaction(() async {
      final canonical = await getProductById(canonicalId);
      final duplicate = await getProductById(duplicateId);
      if (canonical == null || duplicate == null) return;

      String? preferred(String? first, String? second) {
        if (first != null && first.trim().isNotEmpty) return first;
        return second;
      }

      await (update(products)..where((tbl) => tbl.id.equals(canonicalId))).write(
        ProductsCompanion(
          barcode: Value(preferred(canonical.barcode, duplicate.barcode)),
          sku: Value(preferred(canonical.sku, duplicate.sku)),
          name: Value(preferred(canonical.name, duplicate.name) ?? canonical.name),
          category: Value(preferred(canonical.category, duplicate.category)),
          description: Value(
            preferred(canonical.description, duplicate.description),
          ),
          costPrice: Value(canonical.costPrice ?? duplicate.costPrice),
          sellPrice: Value(canonical.sellPrice ?? duplicate.sellPrice),
          quantity: Value(
            canonical.quantity > duplicate.quantity
                ? canonical.quantity
                : duplicate.quantity,
          ),
          photoPath: Value(preferred(canonical.photoPath, duplicate.photoPath)),
          createdAt: Value(
            canonical.createdAt.isBefore(duplicate.createdAt)
                ? canonical.createdAt
                : duplicate.createdAt,
          ),
          updatedAt: Value(DateTime.now()),
          syncedToLoyverse: Value(
            canonical.syncedToLoyverse || duplicate.syncedToLoyverse,
          ),
          optionName: Value(preferred(canonical.optionName, duplicate.optionName)),
          optionValue: Value(
            preferred(canonical.optionValue, duplicate.optionValue),
          ),
          loyverseItemId: Value(
            preferred(canonical.loyverseItemId, duplicate.loyverseItemId),
          ),
          loyverseVariantId: Value(
            preferred(canonical.loyverseVariantId, duplicate.loyverseVariantId),
          ),
          groupId: Value(preferred(canonical.groupId, duplicate.groupId)),
          importSource: Value(
            preferred(canonical.importSource, duplicate.importSource),
          ),
          importBatchId: Value(
            preferred(canonical.importBatchId, duplicate.importBatchId),
          ),
          syncPending: const Value(true),
        ),
      );
      await (delete(products)..where((tbl) => tbl.id.equals(duplicateId))).go();
    });
  }

  /// Enregistre l'identifiant et la révision renvoyés par le serveur après
  /// l'envoi d'un produit. [syncId]/[revision] sont toujours mis à jour :
  /// sans eux, une édition locale concurrente ferait resynchroniser ce
  /// produit avec une révision attendue périmée, rejetée indéfiniment par
  /// `apply_catalog_product_change` (conflit qui ne se résorbe jamais).
  ///
  /// `syncPending` n'est en revanche levé à `false` que si la fiche locale
  /// n'a pas changé depuis l'envoi ([expectedLocalUpdatedAt] toujours
  /// courant) : sinon l'édition concurrente doit encore être envoyée au
  /// prochain passage, cette fois avec la révision désormais à jour.
  Future<void> markProductSynced({
    required int id,
    required String syncId,
    required int revision,
    required DateTime updatedAt,
    required DateTime expectedLocalUpdatedAt,
  }) {
    return transaction(() async {
      await (update(products)..where((tbl) => tbl.id.equals(id))).write(
        ProductsCompanion(
          syncId: Value(syncId),
          remoteRevision: Value(revision),
        ),
      );
      await (update(products)..where(
            (tbl) =>
                tbl.id.equals(id) &
                tbl.updatedAt.equals(expectedLocalUpdatedAt),
          ))
          .write(
            ProductsCompanion(
              updatedAt: Value(updatedAt),
              syncPending: const Value(false),
            ),
          );
    });
  }

  Future<void> applyRemoteProduct(ProductsCompanion product) async {
    await into(products).insertOnConflictUpdate(product);
  }

  Future<List<ProductSyncTombstone>> getProductSyncTombstones() =>
      select(productSyncTombstones).get();

  Future<void> clearProductSyncTombstone(String syncId) async {
    await (delete(
      productSyncTombstones,
    )..where((tbl) => tbl.syncId.equals(syncId))).go();
  }

  Future<void> applyRemoteProductDeletion(String syncId) async {
    await transaction(() async {
      await (delete(products)..where((tbl) => tbl.syncId.equals(syncId))).go();
      await clearProductSyncTombstone(syncId);
    });
  }

  Stream<List<Product>> watchAllProducts() {
    return (select(
      products,
    )..orderBy([(tbl) => OrderingTerm(expression: tbl.name)])).watch();
  }

  /// Derniers produits touchés (créés ou modifiés), du plus récent au plus
  /// ancien. Le tri et la limite sont faits en SQL plutôt que sur la liste
  /// complète : l'activité récente n'a pas à charger tout le catalogue.
  Stream<List<Product>> watchRecentlyTouchedProducts({int limit = 8}) {
    return (select(products)
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.updatedAt,
              mode: OrderingMode.desc,
            ),
            // Départage les fiches d'un même import, toutes écrites à la
            // même seconde : sans cela leur ordre varierait d'un build à
            // l'autre.
            (tbl) => OrderingTerm(expression: tbl.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<Product?> getProductById(int id) {
    return (select(
      products,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<Product?> getProductByBarcode(String barcode) {
    return (select(
      products,
    )..where((tbl) => tbl.barcode.equals(barcode))).getSingleOrNull();
  }

  Future<BarcodeLookupCacheData?> getCachedLookup(String barcode) {
    return (select(
      barcodeLookupCache,
    )..where((tbl) => tbl.barcode.equals(barcode))).getSingleOrNull();
  }

  Future<void> cacheLookupResult({
    required String barcode,
    required String source,
    String? name,
    String? category,
    String? description,
    String? sku,
    String? optionCapacite,
    String? imageUrl,
  }) {
    return into(barcodeLookupCache).insertOnConflictUpdate(
      BarcodeLookupCacheCompanion.insert(
        barcode: barcode,
        source: source,
        name: Value(name),
        category: Value(category),
        description: Value(description),
        sku: Value(sku),
        optionCapacite: Value(optionCapacite),
        imageUrl: Value(imageUrl),
        fetchedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<String?> getLoyverseCacheValue(String key) async {
    final row = await (select(
      loyverseCache,
    )..where((tbl) => tbl.cacheKey.equals(key))).getSingleOrNull();
    return row?.cacheValue;
  }

  Future<void> setLoyverseCacheValue(String key, String value) {
    return into(loyverseCache).insertOnConflictUpdate(
      LoyverseCacheCompanion.insert(cacheKey: key, cacheValue: value),
    );
  }

  /// Enregistre les identifiants Loyverse renvoyés après création ou mise à
  /// jour d'un article, et marque le produit comme synchronisé.
  Future<void> markSyncedToLoyverse({
    required int id,
    required String loyverseItemId,
    required String loyverseVariantId,
  }) {
    return (update(products)..where((tbl) => tbl.id.equals(id))).write(
      ProductsCompanion(
        loyverseItemId: Value(loyverseItemId),
        loyverseVariantId: Value(loyverseVariantId),
        syncedToLoyverse: const Value(true),
        updatedAt: Value(DateTime.now()),
        syncPending: const Value(true),
      ),
    );
  }

  /// Affecte [groupId] au produit [id], sans toucher aux autres colonnes
  /// (contrairement à `updateProduct`, qui utilise `.replace()`).
  Future<void> setGroupId({required int id, required String groupId}) {
    return (update(products)..where((tbl) => tbl.id.equals(id))).write(
      ProductsCompanion(
        groupId: Value(groupId),
        updatedAt: Value(DateTime.now()),
        syncPending: const Value(true),
      ),
    );
  }

  /// Oublie la liaison Loyverse du produit [id] (article/variant supprimé
  /// côté Loyverse depuis la dernière synchronisation, par exemple lors
  /// d'un nettoyage manuel de doublons) pour permettre d'en recréer une
  /// neuve au prochain envoi.
  Future<void> clearLoyverseLink(int id) {
    return (update(products)..where((tbl) => tbl.id.equals(id))).write(
      ProductsCompanion(
        loyverseItemId: Value(null),
        loyverseVariantId: Value(null),
        syncedToLoyverse: Value(false),
        updatedAt: Value(DateTime.now()),
        syncPending: const Value(true),
      ),
    );
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'boutique_catalog');
}
