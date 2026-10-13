import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/product_list/product_list_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/themed_app.dart';

void main() {
  // Même raison que dans product_list_screen_test.dart : database.close()
  // est appelé explicitement en fin de test, pendant que le widget est
  // encore affiché.
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  Future<int> insert({
    required String name,
    String? sku,
    double? sellPrice,
    int quantity = 0,
  }) {
    return database.insertProduct(
      ProductsCompanion.insert(
        name: name,
        sku: Value(sku),
        sellPrice: Value(sellPrice),
        quantity: Value(quantity),
      ),
    );
  }

  Future<void> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themedApp(ProductListScreen(database: database)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('affiche le compteur, les prix FCFA et les quantités réels', (
    tester,
  ) async {
    await insert(name: 'Casque', sku: 'SKU-CASQUE01', sellPrice: 18000, quantity: 15);
    await insert(name: 'Chargeur', sku: 'SKU-CHARGE01', sellPrice: 15000);

    await pumpList(tester);

    expect(find.text('Liste des produits'), findsOneWidget);
    expect(find.text('2 refs'), findsOneWidget);
    expect(find.text('18 000 FCFA'), findsOneWidget);
    expect(find.text('15 000 FCFA'), findsOneWidget);
    expect(find.text('Qté 15'), findsOneWidget);
    expect(find.text('Qté 0'), findsOneWidget);
    expect(find.text('Ajouter'), findsOneWidget);
    expect(find.byTooltip('Dupliquer'), findsNWidgets(2));
    expect(find.byTooltip('Supprimer'), findsNWidgets(2));

    // Écartés : sans équivalent dans l'app.
    expect(find.textContaining('Principal'), findsNothing);
    expect(find.text('Tous'), findsNothing);
    expect(find.text('Stock faible'), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.byIcon(Icons.qr_code_scanner), findsNothing);

    await database.close();
  });

  testWidgets('la recherche filtre par nom ou SKU, partiel et sans casse', (
    tester,
  ) async {
    await insert(name: 'Casque Bluetooth', sku: 'SKU-AAAA1111');
    await insert(name: 'Chargeur universel', sku: 'SKU-BBBB2222');
    await insert(name: 'Clavier USB', sku: 'SKU-CCCC3333');

    await pumpList(tester);
    final search = find.byType(TextField);

    await tester.enterText(search, 'casQUE');
    await tester.pump();
    expect(find.text('Casque Bluetooth'), findsOneWidget);
    expect(find.text('Chargeur universel'), findsNothing);
    expect(find.text('Clavier USB'), findsNothing);
    // Le compteur reste le total du catalogue.
    expect(find.text('3 refs'), findsOneWidget);

    await tester.enterText(search, 'bbbb');
    await tester.pump();
    expect(find.text('Chargeur universel'), findsOneWidget);
    expect(find.text('Casque Bluetooth'), findsNothing);

    await tester.enterText(search, 'introuvable');
    await tester.pump();
    expect(find.textContaining('Aucun produit ne correspond'), findsOneWidget);

    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pump();
    expect(find.text('Casque Bluetooth'), findsOneWidget);
    expect(find.text('Chargeur universel'), findsOneWidget);
    expect(find.text('Clavier USB'), findsOneWidget);

    await database.close();
  });

  testWidgets('la liste réagit aux ajouts en base pendant une recherche', (
    tester,
  ) async {
    await insert(name: 'Casque');
    await pumpList(tester);

    await tester.enterText(find.byType(TextField), 'cas');
    await tester.pump();
    expect(find.text('Casque'), findsOneWidget);

    await insert(name: 'Casquette');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Casquette'), findsOneWidget);
    expect(find.text('2 refs'), findsOneWidget);

    await database.close();
  });
}
