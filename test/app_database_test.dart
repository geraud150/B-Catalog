import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  group('assignMissingSkus', () {
    Future<int> insert({String? sku}) {
      return database.insertProduct(
        ProductsCompanion.insert(name: 'Produit test', sku: Value(sku)),
      );
    }

    test('assigne un SKU généré aux produits sans SKU (null ou vide), '
        'sans toucher aux autres', () async {
      final withoutSku = await insert(sku: null);
      final withBlankSku = await insert(sku: '   ');
      final withSku = await insert(sku: 'SKU-EXISTANT');

      final fixedCount = await database.assignMissingSkus();

      expect(fixedCount, 2);

      final productWithoutSku = await database.getProductById(withoutSku);
      final productWithBlankSku = await database.getProductById(withBlankSku);
      final productWithSku = await database.getProductById(withSku);

      expect(productWithoutSku!.sku, matches(RegExp(r'^SKU-[0-9A-F]{8}$')));
      expect(productWithBlankSku!.sku, matches(RegExp(r'^SKU-[0-9A-F]{8}$')));
      // Le SKU déjà renseigné n'est jamais écrasé.
      expect(productWithSku!.sku, 'SKU-EXISTANT');
    });

    test(
      'ne fait rien et retourne 0 si tous les produits ont déjà un SKU',
      () async {
        await insert(sku: 'SKU-AAAA1111');
        await insert(sku: 'SKU-BBBB2222');

        final fixedCount = await database.assignMissingSkus();

        expect(fixedCount, 0);
      },
    );
  });

  group('insertProductsInTransaction', () {
    ProductsCompanion imported(String name) => ProductsCompanion.insert(
      name: name,
      importSource: const Value('docx_import'),
      importBatchId: const Value('lot-1'),
    );

    test(
      'insère toutes les lignes par paquets et rapporte la progression',
      () async {
        final companions = [for (var i = 0; i < 7; i++) imported('P$i')];
        final progress = <(int, int)>[];

        final count = await database.insertProductsInTransaction(
          companions,
          chunkSize: 3,
          onProgress: (done, total) => progress.add((done, total)),
        );

        expect(count, 7);
        expect(progress, [(3, 7), (6, 7), (7, 7)]);
        final all = await database.select(database.products).get();
        expect(all, hasLength(7));
        expect(all.every((p) => p.importBatchId == 'lot-1'), isTrue);
      },
    );

    test(
      'annule tout le lot si une ligne échoue (transaction unique)',
      () async {
        // Une ligne dont l'id est forcé en doublon viole la clé primaire.
        final companions = [
          imported('OK 1').copyWith(id: const Value(1)),
          imported('OK 2').copyWith(id: const Value(2)),
          imported('Doublon').copyWith(id: const Value(1)),
        ];

        await expectLater(
          database.insertProductsInTransaction(companions, chunkSize: 1),
          throwsA(anything),
        );

        final all = await database.select(database.products).get();
        expect(all, isEmpty);
      },
    );
  });

  group('countImportedProductsToComplete', () {
    Future<int> insert({
      String? importSource = 'docx_import',
      String? sku,
      String? barcode,
      String? photoPath,
    }) {
      return database.insertProduct(
        ProductsCompanion.insert(
          name: 'Produit',
          importSource: Value(importSource),
          sku: Value(sku),
          barcode: Value(barcode),
          photoPath: Value(photoPath),
        ),
      );
    }

    test(
      'compte les fiches importées dont SKU, code-barres et photo sont vides',
      () async {
        await insert(); // tout vide -> comptée
        await insert(sku: '   '); // SKU blanc -> toujours comptée
        await insert(sku: 'SKU-1'); // SKU renseigné -> sortie du compte
        await insert(barcode: '123'); // code-barres renseigné -> sortie
        await insert(photoPath: '/p.jpg'); // photo renseignée -> sortie
        await insert(importSource: null); // saisie manuelle -> jamais comptée

        expect(await database.countImportedProductsToComplete(), 2);
      },
    );

    test('diminue au fur et à mesure que les fiches sont complétées', () async {
      final id = await insert();
      await insert();
      expect(await database.countImportedProductsToComplete(), 2);

      await (database.update(database.products)
            ..where((tbl) => tbl.id.equals(id)))
          .write(const ProductsCompanion(sku: Value('SKU-ABCD1234')));

      expect(await database.countImportedProductsToComplete(), 1);
    });

    test('retourne 0 sans produit importé', () async {
      await insert(importSource: null);
      expect(await database.countImportedProductsToComplete(), 0);
    });
  });
}
