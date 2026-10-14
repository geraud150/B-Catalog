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

  group('catalog synchronization metadata', () {
    test('assigns a stable UUID to a local product', () async {
      final id = await database.insertProduct(
        ProductsCompanion.insert(name: 'Produit local'),
      );

      final product = await database.getProductById(id);

      expect(product!.syncId, isNotNull);
      expect(product.syncId, isNotEmpty);
      expect(product.syncPending, isTrue);
      expect(product.remoteRevision, isNull);
    });

    test('keeps a tombstone when a synchronized product is deleted', () async {
      final id = await database.insertProduct(
        ProductsCompanion.insert(name: 'Produit synchronisé'),
      );
      final product = await database.getProductById(id);
      await (database.update(
        database.products,
      )..where((tbl) => tbl.id.equals(id))).write(
        ProductsCompanion(
          remoteRevision: const Value(3),
          syncPending: const Value(false),
        ),
      );

      expect(await database.deleteProduct(id), 1);

      final tombstones = await database.getProductSyncTombstones();
      expect(tombstones, hasLength(1));
      expect(tombstones.single.syncId, product!.syncId);
      expect(tombstones.single.remoteRevision, 3);
    });
  });

  group('catalog duplicate reconciliation', () {
    test('adopts a remote identity while keeping the local change pending',
        () async {
      final id = await database.insertProduct(
        ProductsCompanion.insert(name: 'Produit local'),
      );

      await database.adoptRemoteProductIdentity(
        localId: id,
        syncId: '11111111-1111-4111-8111-111111111111',
        remoteRevision: 4,
      );

      final product = await database.getProductById(id);
      expect(product!.syncId, '11111111-1111-4111-8111-111111111111');
      expect(product.remoteRevision, 4);
      expect(product.syncPending, isTrue);
    });

    test('merges local duplicates without adding stock twice', () async {
      final canonicalId = await database.insertProduct(
        ProductsCompanion.insert(
          name: 'Produit',
          barcode: const Value('123'),
          quantity: const Value(5),
          description: const Value(''),
        ),
      );
      final duplicateId = await database.insertProduct(
        ProductsCompanion.insert(
          name: 'Produit complet',
          sku: const Value('SKU-123'),
          quantity: const Value(8),
          description: const Value('Description conservée'),
        ),
      );

      await database.mergeUnsyncedDuplicateInto(
        canonicalId: canonicalId,
        duplicateId: duplicateId,
      );

      final product = await database.getProductById(canonicalId);
      expect(await database.getProductById(duplicateId), isNull);
      expect(product!.barcode, '123');
      expect(product.sku, 'SKU-123');
      expect(product.description, 'Description conservée');
      expect(product.quantity, 8);
      expect(product.syncPending, isTrue);
    });
  });

  group('markProductSynced', () {
    test(
      'clears syncPending when the local row has not changed since upload',
      () async {
        final id = await database.insertProduct(
          ProductsCompanion.insert(name: 'Produit'),
        );
        final product = await database.getProductById(id);

        await database.markProductSynced(
          id: id,
          syncId: 'remote-1',
          revision: 2,
          updatedAt: DateTime(2026, 1, 2),
          expectedLocalUpdatedAt: product!.updatedAt,
        );

        final updated = await database.getProductById(id);
        expect(updated!.syncId, 'remote-1');
        expect(updated.remoteRevision, 2);
        expect(updated.syncPending, isFalse);
        expect(updated.updatedAt, DateTime(2026, 1, 2));
      },
    );

    test(
      'still records the server revision when the local row changed during '
      'upload, so the next attempt does not resend a stale expected '
      'revision forever, but leaves the concurrent edit queued',
      () async {
        final id = await database.insertProduct(
          ProductsCompanion.insert(
            name: 'Produit',
            updatedAt: Value(DateTime(2026, 1, 1)),
          ),
        );
        final original = await database.getProductById(id);

        // Simulates an edit made by the user while the first upload was in
        // flight: the local row moves on (to a distinctly later timestamp)
        // before the server's answer comes back for the revision that was
        // actually sent.
        await (database.update(
          database.products,
        )..where((tbl) => tbl.id.equals(id))).write(
          ProductsCompanion(
            name: const Value('Produit modifié'),
            updatedAt: Value(DateTime(2026, 1, 3)),
          ),
        );

        await database.markProductSynced(
          id: id,
          syncId: 'remote-1',
          revision: 1,
          updatedAt: DateTime(2026, 1, 2),
          expectedLocalUpdatedAt: original!.updatedAt,
        );

        final result = await database.getProductById(id);
        expect(result!.syncId, 'remote-1');
        expect(result.remoteRevision, 1);
        // The concurrent edit must still be sent next time, with its own
        // timestamp untouched.
        expect(result.syncPending, isTrue);
        expect(result.updatedAt, DateTime(2026, 1, 3));
      },
    );
  });
}
