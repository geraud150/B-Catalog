import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/import/import_preview_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/themed_app.dart';

ImportPreviewRow _row({
  required String name,
  String category = 'Maquillage',
  String quantity = '3',
  String sellPrice = '9,90',
  String costPrice = '5',
}) {
  return ImportPreviewRow.fromRaw({
    'name': name,
    'category': category,
    'description': 'Description de $name',
    'quantity': quantity,
    'sellPrice': sellPrice,
    'costPrice': costPrice,
  });
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<void> pumpPreview(
    WidgetTester tester,
    List<ImportPreviewRow> rows, {
    int? fileSizeInBytes = 24576,
  }) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themedApp(
        ImportPreviewScreen(
          database: database,
          rows: rows,
          fileName: 'tableau_produits.docx',
          fileSizeInBytes: fileSizeInBytes,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('affiche le fichier, sa taille et les compteurs réels', (
    tester,
  ) async {
    await pumpPreview(tester, [
      _row(name: 'Rouge à lèvres'),
      _row(name: 'Vernis', sellPrice: 'abc'), // prix illisible -> à vérifier
    ]);

    expect(find.text('Aperçu de l\'import'), findsOneWidget);
    expect(find.text('tableau_produits.docx'), findsOneWidget);
    expect(find.text('DOCX détecté'), findsOneWidget);
    expect(find.text('24 Ko'), findsOneWidget);
    expect(find.text('1 produit'), findsOneWidget); // prêt à l'import
    expect(find.text('1 à vérifier'), findsOneWidget);
    expect(find.text('Confirmer l\'import (2)'), findsOneWidget);
    expect(find.textContaining('Prix illisible'), findsOneWidget);

    // Menu "..." de la maquette écarté.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });

  testWidgets('sans taille de fichier, l\'aperçu reste utilisable', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      [_row(name: 'Rouge à lèvres')],
      fileSizeInBytes: null,
    );

    expect(find.text('tableau_produits.docx'), findsOneWidget);
    expect(find.textContaining('Ko'), findsNothing);
    expect(find.text('Confirmer l\'import (1)'), findsOneWidget);
  });

  testWidgets('les onglets Tous / Valides / Erreurs filtrent réellement', (
    tester,
  ) async {
    await pumpPreview(tester, [
      _row(name: 'Rouge à lèvres'),
      _row(name: 'Fond de teint'),
      _row(name: 'Vernis', quantity: 'abc'), // quantité illisible
    ]);

    // Onglet "Tous" par défaut : les trois lignes sont visibles.
    expect(find.text('Rouge à lèvres'), findsOneWidget);
    expect(find.text('Fond de teint'), findsOneWidget);
    expect(find.text('Vernis'), findsOneWidget);
    expect(find.text('OK'), findsNWidgets(2));
    expect(find.text('À vérifier'), findsOneWidget);

    await tester.tap(find.text('Valides'));
    await tester.pump();
    expect(find.text('Rouge à lèvres'), findsOneWidget);
    expect(find.text('Fond de teint'), findsOneWidget);
    expect(find.text('Vernis'), findsNothing);

    await tester.tap(find.text('Erreurs'));
    await tester.pump();
    expect(find.text('Vernis'), findsOneWidget);
    expect(find.text('Rouge à lèvres'), findsNothing);
    expect(find.text('Fond de teint'), findsNothing);
    // Le bouton de confirmation porte toujours sur toutes les lignes lues.
    expect(find.text('Confirmer l\'import (3)'), findsOneWidget);

    await tester.tap(find.text('Tous'));
    await tester.pump();
    expect(find.text('Rouge à lèvres'), findsOneWidget);
    expect(find.text('Vernis'), findsOneWidget);
  });

  testWidgets('l\'onglet Erreurs est désactivé quand tout est valide', (
    tester,
  ) async {
    await pumpPreview(tester, [_row(name: 'Rouge à lèvres')]);

    expect(find.text('Aucune anomalie'), findsOneWidget);

    await tester.tap(find.text('Erreurs'));
    await tester.pump();
    // Rien ne change : la ligne valide reste affichée.
    expect(find.text('Rouge à lèvres'), findsOneWidget);
  });
}
