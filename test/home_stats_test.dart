import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/home/home_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Product product({
    String? category,
    String? sku,
    String? barcode,
    double? sellPrice,
    String? photoPath,
    String? importSource,
  }) {
    final now = DateTime(2026);
    return Product(
      id: 0,
      name: 'Produit',
      category: category,
      sku: sku,
      barcode: barcode,
      sellPrice: sellPrice,
      photoPath: photoPath,
      importSource: importSource,
      quantity: 0,
      createdAt: now,
      updatedAt: now,
      syncedToLoyverse: false,
    );
  }

  final complete = product(
    category: 'Soins',
    sku: 'SKU-1',
    barcode: '123',
    sellPrice: 10,
    photoPath: '/p.jpg',
  );

  test('sans produit, tous les indicateurs sont à zéro', () {
    final stats = HomeStats.fromProducts(const []);
    expect(stats, isNotNull);
    expect(stats.totalProducts, 0);
    expect(stats.categoryCount, 0);
    expect(stats.completenessPercent, 0);
    expect(stats.importedProgress, 0);
  });

  test('compte les catégories distinctes sans tenir compte de la casse', () {
    final stats = HomeStats.fromProducts([
      product(category: 'Soins'),
      product(category: ' soins'),
      product(category: 'Maquillage'),
      product(category: '   '),
      product(),
    ]);
    expect(stats.categoryCount, 2);
  });

  test(
    'la complétude exige SKU, code-barres, prix, catégorie et photo',
    () {
      expect(HomeStats.isComplete(complete), isTrue);
      expect(
        HomeStats.isComplete(
          product(
            category: 'Soins',
            sku: 'SKU-1',
            barcode: '123',
            sellPrice: 10,
            photoPath: ' ',
          ),
        ),
        isFalse,
      );
      expect(
        HomeStats.isComplete(
          product(
            category: 'Soins',
            sku: 'SKU-1',
            barcode: '123',
            photoPath: '/p.jpg',
          ),
        ),
        isFalse,
      );

      final stats = HomeStats.fromProducts([complete, product(), product()]);
      expect(stats.completeCount, 1);
      expect(stats.completenessPercent, 33);
    },
  );

  test('les fiches importées à compléter suivent la règle du compteur', () {
    final stats = HomeStats.fromProducts([
      product(importSource: 'docx_import'),
      product(importSource: 'docx_import', sku: '  '),
      product(importSource: 'docx_import', barcode: '123'),
      product(importSource: 'docx_import', photoPath: '/p.jpg'),
      product(), // saisie manuelle, jamais comptée
    ]);
    expect(stats.importedCount, 4);
    expect(stats.importedToCompleteCount, 2);
    expect(stats.importedProgress, 0.5);
  });
}
