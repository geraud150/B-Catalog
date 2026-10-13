import '../../core/database/app_database.dart';

/// Indicateurs affichés sur l'écran d'accueil, calculés à partir de la liste
/// complète des produits (flux `watchAllProducts()`), de sorte qu'ils se
/// mettent à jour d'eux-mêmes après chaque saisie, import ou suppression.
class HomeStats {
  const HomeStats({
    required this.totalProducts,
    required this.categoryCount,
    required this.completeCount,
    required this.importedCount,
    required this.importedToCompleteCount,
    required this.syncedToLoyverseCount,
  });

  factory HomeStats.fromProducts(Iterable<Product> products) {
    final categories = <String>{};
    var total = 0;
    var complete = 0;
    var imported = 0;
    var importedToComplete = 0;
    var synced = 0;

    for (final product in products) {
      total++;
      if (product.syncedToLoyverse) synced++;
      final category = product.category?.trim();
      if (category != null && category.isNotEmpty) {
        categories.add(category.toLowerCase());
      }
      if (isComplete(product)) complete++;
      if (product.importSource != null) {
        imported++;
        if (isImportedToComplete(product)) importedToComplete++;
      }
    }

    return HomeStats(
      totalProducts: total,
      categoryCount: categories.length,
      completeCount: complete,
      importedCount: imported,
      importedToCompleteCount: importedToComplete,
      syncedToLoyverseCount: synced,
    );
  }

  static const empty = HomeStats(
    totalProducts: 0,
    categoryCount: 0,
    completeCount: 0,
    importedCount: 0,
    importedToCompleteCount: 0,
    syncedToLoyverseCount: 0,
  );

  final int totalProducts;

  /// Nombre de catégories distinctes (comparaison insensible à la casse et
  /// aux espaces de bord).
  final int categoryCount;

  /// Produits dont SKU, code-barres, prix de vente, catégorie et photo sont
  /// tous renseignés (voir [isComplete]).
  final int completeCount;

  /// Produits issus d'un import (Word), complétés ou non.
  final int importedCount;

  /// Fiches importées dont SKU, code-barres et photo sont encore tous vides :
  /// même définition que `AppDatabase.countImportedProductsToComplete()`.
  final int importedToCompleteCount;

  /// Produits déjà poussés vers Loyverse (colonne `syncedToLoyverse`). Compté
  /// sur le même flux que les autres indicateurs : la valeur suit donc la
  /// base en direct, sans anti-rebond ni mesure de latence.
  final int syncedToLoyverseCount;

  /// Produits pas encore poussés vers Loyverse. Complément de
  /// [syncedToLoyverseCount] : à eux deux ils couvrent tout le catalogue.
  int get pendingLoyverseCount => totalProducts - syncedToLoyverseCount;

  /// Part des produits complets, en pourcentage entier (0 sans produit).
  int get completenessPercent =>
      totalProducts == 0 ? 0 : (completeCount * 100 / totalProducts).round();

  /// Avancement de la complétion des fiches importées, entre 0 et 1 : part
  /// des fiches importées qui ne sont plus "à compléter".
  double get importedProgress => importedCount == 0
      ? 0
      : (importedCount - importedToCompleteCount) / importedCount;

  static bool _isFilled(String? value) =>
      value != null && value.trim().isNotEmpty;

  static bool isComplete(Product product) =>
      _isFilled(product.sku) &&
      _isFilled(product.barcode) &&
      product.sellPrice != null &&
      _isFilled(product.category) &&
      _isFilled(product.photoPath);

  static bool isImportedToComplete(Product product) =>
      product.importSource != null &&
      !_isFilled(product.sku) &&
      !_isFilled(product.barcode) &&
      !_isFilled(product.photoPath);
}
