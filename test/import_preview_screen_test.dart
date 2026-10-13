import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/import/import_preview_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/themed_app.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  group('ImportPreviewRow.fromRaw', () {
    test(
      'convertit les nombres français et ne signale rien si tout est lisible',
      () {
        final row = ImportPreviewRow.fromRaw({
          'name': ' Crème ',
          'category': 'Soin',
          'quantity': '12',
          'sellPrice': '9,90',
          'costPrice': '4 500,50',
          'description': 'Hydratante',
        });

        expect(row.name, 'Crème');
        expect(row.quantity, 12);
        expect(row.sellPrice, 9.9);
        expect(row.costPrice, 4500.5);
        expect(row.needsReview, isFalse);
      },
    );

    test('signale un nom vide et des nombres illisibles sans planter', () {
      final row = ImportPreviewRow.fromRaw({
        'name': '',
        'quantity': 'douze',
        'sellPrice': 'gratuit',
        'costPrice': '',
      });

      expect(row.needsReview, isTrue);
      expect(row.warnings, hasLength(3));
      expect(row.quantity, 0);
      expect(row.sellPrice, isNull);
      expect(row.costPrice, isNull);
    });

    test('signale une quantité non entière et l\'arrondit', () {
      final row = ImportPreviewRow.fromRaw({'name': 'X', 'quantity': '2,5'});

      expect(row.quantity, 3);
      expect(row.warnings.single, contains('non entière'));
    });
  });

  testWidgets(
    'affiche le compteur, les avertissements, puis enregistre toutes les '
    'lignes avec le même importBatchId à la confirmation',
    (tester) async {
      final rows = [
        ImportPreviewRow.fromRaw({
          'name': 'Rouge à lèvres',
          'category': 'Maquillage',
          'quantity': '3',
          'sellPrice': '9,90',
        }),
        ImportPreviewRow.fromRaw({'name': '', 'sellPrice': 'abc'}),
      ];
      int? result;

      await tester.pumpWidget(
        themedApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<int>(
                    MaterialPageRoute(
                      builder: (_) => ImportPreviewScreen(
                        database: database,
                        rows: rows,
                        fileName: 'catalogue.docx',
                      ),
                    ),
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      // En-tête : 1 ligne prête à l'import, 1 en anomalie (nom manquant et
      // prix illisible sur la même ligne).
      expect(find.text('1 produit'), findsOneWidget);
      expect(find.text('1 à vérifier'), findsOneWidget);
      expect(find.text('Rouge à lèvres'), findsOneWidget);
      expect(find.text(kMissingNamePlaceholder), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      expect(find.textContaining('Prix illisible'), findsOneWidget);

      // Rien n'est enregistré avant la confirmation.
      expect(await database.select(database.products).get(), isEmpty);

      await tester.tap(find.text('Confirmer l\'import (2)'));
      await tester.pumpAndSettle();

      expect(result, 2);
      final saved = await database.select(database.products).get();
      expect(saved, hasLength(2));
      expect(saved.every((p) => p.importSource == kDocxImportSource), isTrue);
      expect(saved.map((p) => p.importBatchId).toSet(), hasLength(1));
      expect(saved.first.importBatchId, isNotNull);
      // SKU, code-barres, option et photo restent vides.
      expect(saved.every((p) => p.sku == null), isTrue);
      expect(saved.every((p) => p.barcode == null), isTrue);
      expect(saved.every((p) => p.photoPath == null), isTrue);
      expect(saved.every((p) => p.optionName == null), isTrue);

      final lipstick = saved.singleWhere((p) => p.name == 'Rouge à lèvres');
      expect(lipstick.category, 'Maquillage');
      expect(lipstick.quantity, 3);
      expect(lipstick.sellPrice, 9.9);
      final unnamed = saved.singleWhere(
        (p) => p.name == kMissingNamePlaceholder,
      );
      expect(unnamed.sellPrice, isNull);

      // Retour à l'écran appelant après confirmation.
      expect(find.text('ouvrir'), findsOneWidget);
      expect(await database.countImportedProductsToComplete(), 2);
    },
  );
}
