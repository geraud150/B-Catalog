import 'package:boutique_catalog/core/config.dart';
import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/export/csv_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

Product buildProduct({
  int id = 1,
  String name = 'Produit',
  String? sku = 'SKU1',
  String? category,
  String? description,
  String? barcode,
  double? costPrice,
  double? sellPrice,
  int quantity = 0,
  String? optionName,
  String? optionValue,
  String? groupId,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    name: name,
    sku: sku,
    category: category,
    description: description,
    barcode: barcode,
    costPrice: costPrice,
    sellPrice: sellPrice,
    quantity: quantity,
    optionName: optionName,
    optionValue: optionValue,
    groupId: groupId,
    createdAt: now,
    updatedAt: now,
    syncedToLoyverse: false,
    syncPending: true,
  );
}

void main() {
  group('sauvegarde du fichier', () {
    test('le nom de fichier est horodaté à la minute', () {
      expect(
        CsvExportService.defaultFileName(DateTime(2026, 9, 22, 18, 36)),
        'loyverse_import_20260922_1836.csv',
      );
      expect(
        CsvExportService.defaultFileName(DateTime(2026, 1, 5, 7, 4)),
        'loyverse_import_20260105_0704.csv',
      );
    });

    test('le premier dossier Téléchargements existant est retenu', () {
      final paths = CsvExportService.androidDownloadsPaths;
      expect(paths.first, '/storage/emulated/0/Download');

      expect(
        CsvExportService.firstExistingDirectory(
          paths,
          exists: (path) => path == paths.last,
        ),
        paths.last,
      );
      expect(
        CsvExportService.firstExistingDirectory(paths, exists: (_) => true),
        paths.first,
      );
      expect(
        CsvExportService.firstExistingDirectory(paths, exists: (_) => false),
        isNull,
      );
    });

    test('un export annulé n\'est pas considéré comme enregistré', () {
      expect(const CsvSaveResult.cancelled().isSaved, isFalse);
      expect(
        const CsvSaveResult(CsvSaveStatus.savedToDownloads).isSaved,
        isTrue,
      );
      expect(const CsvSaveResult(CsvSaveStatus.saved).isSaved, isTrue);
    });
  });

  const service = CsvExportService();

  test('en-tête conforme au format d\'import Loyverse', () {
    final lines = service.exportToCsv([]).split('\r\n');

    expect(
      lines.first,
      [
        'Handle',
        'SKU',
        'Name',
        'Category',
        'Description',
        'Sold by weight',
        'Option 1 name',
        'Option 1 value',
        'Option 2 name',
        'Option 2 value',
        'Option 3 name',
        'Option 3 value',
        'Cost',
        'Barcode',
        'SKU of included item',
        'Quantity of included item',
        'Track stock',
        'Available for sale [$kLoyverseStoreName]',
        'Price [$kLoyverseStoreName]',
        'In stock [$kLoyverseStoreName]',
        'Low stock [$kLoyverseStoreName]',
      ].join(','),
    );
  });

  test('les montants entiers sont exportés sans décimale superflue', () {
    final csv = service.exportToCsv([
      buildProduct(costPrice: 12, sellPrice: 65, quantity: 3),
    ]);
    final row = csv.split('\r\n')[1];

    expect(row.split(','), containsAll(<String>['12', '65', '3']));
    expect(row, isNot(contains('12.0')));
    expect(row, isNot(contains('65.0')));
  });

  test('les montants décimaux conservent leur partie fractionnaire', () {
    final csv = service.exportToCsv([buildProduct(sellPrice: 12.5)]);

    expect(csv.split('\r\n')[1], contains('12.5'));
  });

  test('Sold by weight vaut N pour ne pas basculer en vente au poids', () {
    final csv = service.exportToCsv([buildProduct()]);
    final fields = csv.split('\r\n')[1].split(',');

    expect(fields[5], 'N');
  });

  test('les champs contenant une virgule sont échappés', () {
    final csv = service.exportToCsv([
      buildProduct(description: 'Polo en coton léger, couleur rose'),
    ]);

    expect(csv, contains('"Polo en coton léger, couleur rose"'));
  });

  test('Handle vide pour un produit autonome', () {
    final csv = service.exportToCsv([buildProduct()]);
    final fields = csv.split('\r\n')[1].split(',');

    expect(fields[0], '');
  });

  test(
    'Handle identique et non vide pour deux produits partageant un groupId',
    () {
      final csv = service.exportToCsv([
        buildProduct(id: 1, name: 'Rouge à lèvres mat', groupId: 'g1'),
        buildProduct(id: 2, name: 'Rouge à lèvres mat', groupId: 'g1'),
      ]);
      final rows = csv.split('\r\n');
      final handle1 = rows[1].split(',')[0];
      final handle2 = rows[2].split(',')[0];

      expect(handle1, isNotEmpty);
      expect(handle1, handle2);
      expect(handle1, startsWith('rouge-a-levres-mat-'));
    },
  );

  test('productsMissingSku repère les SKU absents ou vides', () {
    final missing = service.productsMissingSku([
      buildProduct(id: 1, name: 'Avec SKU', sku: 'ABC'),
      buildProduct(id: 2, name: 'Sans SKU', sku: null),
      buildProduct(id: 3, name: 'SKU vide', sku: '   '),
    ]);

    expect(missing.map((p) => p.name), ['Sans SKU', 'SKU vide']);
  });
}
