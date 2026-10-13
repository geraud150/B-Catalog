import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/review/review_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/themed_app.dart';

Future<int> _insertProduct(
  AppDatabase database, {
  String name = 'Produit',
  String? sku = 'SKU-AAAA1111',
  String? category = 'Catégorie',
  double? sellPrice = 10,
}) {
  return database.insertProduct(
    ProductsCompanion.insert(
      name: name,
      sku: Value(sku),
      category: Value(category),
      sellPrice: Value(sellPrice),
    ),
  );
}

void main() {
  // Pas de tearDown(() => database.close()) ici : ReviewScreen garde une
  // souscription active sur le stream Drift (watchAllProducts()) tant que le
  // widget est monté. Drift ferme cette souscription via un Timer interne
  // (voir le commentaire dans stream_queries.dart : "please call and await
  // Database.close() in your Flutter widget tests!") ; tearDown() s'exécute
  // trop tard, après la vérification automatique de fin de test qui
  // échouerait alors avec "A Timer is still pending". `database.close()` est
  // donc appelé explicitement à la fin de chaque test, pendant que le widget
  // est encore monté : il attend lui-même que ce timer se vide avant de
  // retourner.
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  testWidgets(
    'un produit sans SKU (mais prix et catégorie renseignés) est signalé '
    'incomplet, en plus des cas prix/catégorie déjà couverts',
    (tester) async {
      await _insertProduct(database, name: 'Complet', sku: 'SKU-COMPLET');
      await _insertProduct(database, name: 'Sans SKU', sku: null);

      await tester.pumpWidget(
        themedApp(ReviewScreen(database: database)),
      );
      // Pas de pumpAndSettle() : le spinner de chargement initial
      // (CircularProgressIndicator, animation indéterminée) ne s'arrête
      // jamais tout seul, ce qui ferait boucler pumpAndSettle() jusqu'à son
      // timeout de 10 minutes. Quelques pumps suffisent pour laisser le
      // StreamBuilder recevoir le premier événement du stream Drift.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Un seul produit sur deux est incomplet : celui sans SKU.
      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('SKU non défini'), findsOneWidget);

      await database.close();
    },
  );

  testWidgets(
    'un produit avec SKU, prix et catégorie renseignés n\'est jamais signalé '
    'incomplet',
    (tester) async {
      await _insertProduct(database, name: 'Complet', sku: 'SKU-COMPLET');

      await tester.pumpWidget(
        themedApp(ReviewScreen(database: database)),
      );
      // Pas de pumpAndSettle() : voir commentaire ci-dessus.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.textContaining('SKU non défini'), findsNothing);

      await database.close();
    },
  );
}
