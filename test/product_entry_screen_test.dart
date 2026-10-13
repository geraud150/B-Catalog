import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/product_entry/product_entry_screen.dart';
import 'package:drift/drift.dart' show Value;
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

  Future<void> pumpEntry(WidgetTester tester, {Product? existing}) async {
    // Fenêtre de type téléphone, pour rester proche de la maquette.
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      themedApp(
        ProductEntryScreen(database: database, existingProduct: existing),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder fieldWithHint(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );

  testWidgets('affiche les sections de la maquette sans les éléments écartés', (
    tester,
  ) async {
    await pumpEntry(tester);

    expect(find.text('Ajouter un produit'), findsOneWidget);
    expect(find.text('VISUEL DU PRODUIT'), findsOneWidget);
    expect(find.text('Informations générales'), findsOneWidget);
    expect(find.text('Code-barres / EAN-13'), findsOneWidget);
    expect(find.text('Tarifs & quantités'), findsOneWidget);
    expect(find.text('Variante'), findsOneWidget);
    expect(find.text('Enregistrer le produit'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);

    // Écartés : sans équivalent dans l'app.
    expect(find.text('NOUVEAU'), findsNothing);
    expect(find.text('Catalogue principal'), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.textContaining('Recommandé'), findsNothing);
    expect(find.textContaining('autres angles'), findsNothing);
    expect(find.textContaining('brouillon'), findsNothing);
    expect(find.textContaining('Ajouter une autre variante'), findsNothing);
    expect(find.textContaining('HT'), findsNothing);
    expect(find.textContaining('TTC'), findsNothing);
    expect(find.textContaining('€'), findsNothing);
  });

  testWidgets('"Générer auto" remplit le SKU, qui reste modifiable', (
    tester,
  ) async {
    await pumpEntry(tester);

    final skuField = fieldWithHint('ex. SKU-3F9A21C4');
    expect(tester.widget<TextField>(skuField).controller!.text, isEmpty);

    await tester.tap(find.text('Générer auto'));
    await tester.pump();

    final generated = tester.widget<TextField>(skuField).controller!.text;
    expect(generated, matches(RegExp(r'^SKU-[0-9A-F]{8}$')));

    await tester.enterText(skuField, 'MON-SKU');
    expect(tester.widget<TextField>(skuField).controller!.text, 'MON-SKU');
  });

  testWidgets('les prix utilisent le FCFA formaté, jamais le symbole €', (
    tester,
  ) async {
    await pumpEntry(tester);

    expect(find.text('FCFA'), findsNWidgets(2)); // suffixes des deux champs
    expect(find.text('Optionnel'), findsWidgets); // aide prix de revient
    expect(find.text('Obligatoire'), findsOneWidget);

    final priceFields = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.suffixText == 'FCFA',
    );
    await tester.enterText(priceFields.last, '12500');
    await tester.pump();

    expect(find.text('12 500 FCFA'), findsOneWidget);
    expect(find.textContaining('€'), findsNothing);
  });

  testWidgets('le stepper ajuste la quantité et le clavier reste possible', (
    tester,
  ) async {
    await pumpEntry(tester);

    final quantityField = find.byWidgetPredicate(
      (w) => w is TextField && w.textAlign == TextAlign.center,
    );
    String quantity() =>
        tester.widget<TextField>(quantityField).controller!.text;

    expect(quantity(), '0');
    expect(find.text('Rupture'), findsOneWidget);

    await tester.tap(find.byTooltip('Diminuer la quantité'));
    await tester.pump();
    expect(quantity(), '0'); // jamais négatif

    await tester.tap(find.byTooltip('Augmenter la quantité'));
    await tester.tap(find.byTooltip('Augmenter la quantité'));
    await tester.pump();
    expect(quantity(), '2');
    expect(find.text('En stock'), findsOneWidget);

    await tester.enterText(quantityField, '150');
    await tester.pump();
    expect(quantity(), '150');

    await tester.tap(find.byTooltip('Augmenter la quantité'));
    await tester.pump();
    expect(quantity(), '151');
  });

  testWidgets(
    'la catégorie propose en autocomplétion les catégories déjà en base',
    (tester) async {
      Future<void> insert(String? category) => database.insertProduct(
        ProductsCompanion.insert(name: 'P', category: Value(category)),
      );
      await insert('Soins du visage');
      await insert('Soins du visage');
      await insert('  Maquillage ');
      await insert(null);
      await insert('   ');

      await pumpEntry(tester);

      final categoryField = fieldWithHint(
        'Saisir ou choisir une catégorie existante',
      );
      expect(categoryField, findsOneWidget);

      // Champ vide + focus : toutes les catégories connues, dédoublonnées et
      // nettoyées, dans l'ordre alphabétique.
      await tester.tap(categoryField);
      await tester.pumpAndSettle();
      expect(find.text('Maquillage'), findsOneWidget);
      expect(find.text('Soins du visage'), findsOneWidget);

      // Filtrage insensible à la casse.
      await tester.enterText(categoryField, 'soin');
      await tester.pumpAndSettle();
      expect(find.text('Maquillage'), findsNothing);
      expect(find.text('Soins du visage'), findsOneWidget);

      // Sélection d'une suggestion → champ rempli, texte libre conservé
      // possible ensuite.
      await tester.tap(find.text('Soins du visage'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(categoryField).controller!.text,
        'Soins du visage',
      );

      await tester.enterText(categoryField, 'Nouvelle catégorie');
      expect(
        tester.widget<TextField>(categoryField).controller!.text,
        'Nouvelle catégorie',
      );
    },
  );

  testWidgets('en mode édition, les valeurs existantes sont préchargées', (
    tester,
  ) async {
    final id = await database.insertProduct(
      ProductsCompanion.insert(
        name: 'Crème hydratante',
        sku: const Value('SKU-ABCDEF12'),
        category: const Value('Soins'),
        sellPrice: const Value(4500),
        quantity: const Value(3),
      ),
    );
    final product = (await database.getProductById(id))!;

    await pumpEntry(tester, existing: product);

    expect(find.text('Modifier le produit'), findsOneWidget);
    expect(find.text('Enregistrer les modifications'), findsOneWidget);
    expect(find.text('Crème hydratante'), findsOneWidget);
    expect(find.text('SKU-ABCDEF12'), findsOneWidget);
    expect(find.text('4 500 FCFA'), findsOneWidget);
    expect(find.text('En stock'), findsOneWidget);
  });
}
