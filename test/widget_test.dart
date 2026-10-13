import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boutique_catalog/app_shell.dart';
import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/home/home_screen.dart';

import 'helpers/themed_app.dart';

void main() {
  // HomeScreen garde une souscription active sur watchAllProducts() tant
  // qu'il est monté : database.close() est appelé explicitement en fin de
  // test, pendant que le widget est encore affiché.
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  Future<int> insert({
    String name = 'Produit',
    String? category,
    String? sku,
    String? barcode,
    double? sellPrice,
    String? photoPath,
    String? importSource,
  }) {
    return database.insertProduct(
      ProductsCompanion.insert(
        name: name,
        category: Value(category),
        sku: Value(sku),
        barcode: Value(barcode),
        sellPrice: Value(sellPrice),
        photoPath: Value(photoPath),
        importSource: Value(importSource),
      ),
    );
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(themedApp(HomeScreen(database: database)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('HomeScreen affiche les quatre actions principales', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Ajouter un produit'), findsOneWidget);
    expect(find.text('Liste des produits'), findsOneWidget);
    expect(find.text('Vérifier & Exporter'), findsOneWidget);
    expect(find.text('Importer un document'), findsOneWidget);

    // Éléments de la maquette volontairement écartés.
    expect(find.text('Pro'), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    expect(find.textContaining('ERP'), findsNothing);

    await database.close();
  });

  testWidgets('les indicateurs reflètent les produits en base', (
    tester,
  ) async {
    await insert(
      name: 'Complet',
      category: 'Soins',
      sku: 'SKU-1',
      barcode: '123',
      sellPrice: 10,
      photoPath: '/p.jpg',
    );
    await insert(name: 'Incomplet', category: 'soins ');
    await insert(name: 'Autre', category: 'Maquillage');
    await insert(name: 'Sans catégorie');

    await pumpHome(tester);

    expect(find.text('4'), findsOneWidget); // Produits
    expect(find.text('2'), findsOneWidget); // Catégories distinctes
    expect(find.text('25%'), findsOneWidget); // 1 complet sur 4
    expect(find.text('4 réfs'), findsOneWidget);
    expect(find.textContaining('restent à compléter'), findsNothing);

    await database.close();
  });

  testWidgets('la bannière des fiches importées apparaît et mène à la liste '
      'filtrée', (tester) async {
    await insert(name: 'Importée à compléter', importSource: 'docx_import');
    await insert(name: 'Importée à compléter bis', importSource: 'docx_import');
    await insert(
      name: 'Importée déjà complétée',
      importSource: 'docx_import',
      sku: 'SKU-2',
    );
    await insert(name: 'Saisie manuelle');

    await pumpHome(tester);

    expect(
      find.text('2 fiches importées restent à compléter'),
      findsOneWidget,
    );
    expect(find.text('2 / 3 fiches'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, closeTo(1 / 3, 0.001));

    await tester.tap(find.text('Compléter les fiches'));
    await tester.pumpAndSettle();

    expect(find.text('Fiches importées à compléter'), findsOneWidget);
    expect(find.text('Importée à compléter'), findsOneWidget);
    expect(find.text('Importée à compléter bis'), findsOneWidget);
    expect(find.text('Importée déjà complétée'), findsNothing);
    expect(find.text('Saisie manuelle'), findsNothing);

    await database.close();
  });

  testWidgets('AppShell propose les trois onglets et bascule entre eux', (
    tester,
  ) async {
    await tester.pumpWidget(themedApp(AppShell(database: database)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);
    expect(
      tester.widget<NavigationBar>(navBar).destinations,
      hasLength(3),
    );
    for (final label in ['Accueil', 'Produits', 'Import / Export']) {
      expect(
        find.descendant(of: navBar, matching: find.text(label)),
        findsOneWidget,
      );
    }
    // L'onglet Réglages (placeholder) a été retiré.
    expect(find.text('Réglages'), findsNothing);

    await tester.tap(find.descendant(of: navBar, matching: find.text('Import / Export')));
    await tester.pumpAndSettle();
    expect(find.text('Import & export'), findsOneWidget);
    expect(find.text('Importer un document Word'), findsOneWidget);
    expect(find.text('Vérifier et exporter'), findsOneWidget);
    // Éléments de la maquette écartés.
    expect(find.textContaining('GESTION DE FLUX'), findsNothing);
    expect(find.textContaining('Passerelle'), findsNothing);
    expect(find.textContaining('en attente'), findsNothing);
    expect(find.textContaining('RESSOURCES'), findsNothing);

    await database.close();
  });
}
