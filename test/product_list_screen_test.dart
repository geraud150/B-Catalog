import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/product_list/product_list_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/themed_app.dart';

void main() {
  // Même raison que dans review_screen_test.dart : ProductListScreen garde
  // une souscription active sur watchAllProducts() tant qu'il est monté ;
  // database.close() est donc appelé explicitement en fin de test, pendant
  // que le widget est encore affiché.
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  Future<int> insert({
    String name = 'Produit',
    String? groupId,
    String? optionValue,
    String? sku,
    String? category,
  }) {
    return database.insertProduct(
      ProductsCompanion.insert(
        name: name,
        groupId: Value(groupId),
        optionValue: Value(optionValue),
        sku: Value(sku),
        category: Value(category),
      ),
    );
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(themedApp(ProductListScreen(database: database)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('un produit autonome ne porte aucun badge de variante', (
    tester,
  ) async {
    await insert(name: 'Savon');

    await tester.pumpWidget(
      themedApp(ProductListScreen(database: database)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Savon'), findsOneWidget);
    expect(find.textContaining('Variante'), findsNothing);
    expect(find.textContaining('variantes liées'), findsNothing);

    await database.close();
  });

  testWidgets(
    'deux produits issus d\'une duplication (même groupId) sont regroupés '
    'et étiquetés, distinguables l\'un de l\'autre',
    (tester) async {
      await insert(name: 'Rouge à lèvres', groupId: 'g1', optionValue: 'Rouge');
      await insert(name: 'Rouge à lèvres', groupId: 'g1', optionValue: null);

      await tester.pumpWidget(
        themedApp(ProductListScreen(database: database)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Regroupement visuel avec en-tête.
      expect(find.text('2 variantes liées'), findsOneWidget);
      // La variante déjà renseignée affiche sa valeur d'option...
      expect(find.text('Rouge'), findsOneWidget);
      // ...celle qui ne l'est pas encore est signalée distinctement.
      expect(find.text('Variante à compléter'), findsOneWidget);

      await database.close();
    },
  );

  testWidgets(
    'des produits sans lien de groupe ne sont jamais regroupés même avec '
    'le même nom',
    (tester) async {
      await insert(name: 'Vernis');
      await insert(name: 'Vernis');

      await tester.pumpWidget(
        themedApp(ProductListScreen(database: database)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Vernis'), findsNWidgets(2));
      expect(find.textContaining('variantes liées'), findsNothing);
      expect(find.textContaining('Variante'), findsNothing);

      await database.close();
    },
  );

  group('SKU et catégorie', () {
    // Le SKU est la clé de l'export CSV et Loyverse : il devait jusqu'ici
    // être lu fiche par fiche, la liste ne montrant que nom, prix et
    // quantité.
    testWidgets('sont affichés sous le nom quand ils sont renseignés', (
      tester,
    ) async {
      await insert(name: 'Savon', sku: 'SKU-3F9A21', category: 'Hygiène');

      await pump(tester);

      expect(find.text('SKU-3F9A21 · Hygiène'), findsOneWidget);

      await database.close();
    });

    testWidgets('un seul des deux suffit, sans séparateur orphelin', (
      tester,
    ) async {
      await insert(name: 'Savon', sku: 'SKU-3F9A21');
      await insert(name: 'Vernis', category: 'Beauté');

      await pump(tester);

      // L'égalité stricte vaut assertion sur le séparateur : s'il était
      // ajouté malgré le champ manquant, le texte ne correspondrait plus.
      expect(find.text('SKU-3F9A21'), findsOneWidget);
      expect(find.text('Beauté'), findsOneWidget);

      await database.close();
    });

    testWidgets('un champ réduit à des espaces compte comme absent', (
      tester,
    ) async {
      // Les champs sont facultatifs en base et une chaîne vide vaut absence :
      // réserver la hauteur laisserait un blanc sur un catalogue neuf.
      await insert(name: 'Savon', sku: '   ', category: null);
      await insert(name: 'Vernis', sku: 'SKU-7B2C');

      await pump(tester);

      expect(find.text('Savon'), findsOneWidget);
      // Seul Vernis porte une ligne de métadonnées ; le SKU vide de Savon
      // n'en crée pas. ("SKU-" et non "SKU" : le champ de recherche dit
      // déjà "Rechercher un produit ou un SKU...".)
      expect(find.textContaining('SKU-'), findsOneWidget);

      await database.close();
    });
  });
}
