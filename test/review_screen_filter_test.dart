import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/review/review_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/themed_app.dart';

void main() {
  // Voir review_screen_test.dart pour la raison du database.close() explicite
  // en fin de test.
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  Future<int> insert({
    required String name,
    String? sku = 'SKU-AAAA1111',
    String? category = 'Catégorie',
    double? sellPrice = 10,
    bool synced = false,
  }) {
    return database.insertProduct(
      ProductsCompanion.insert(
        name: name,
        sku: Value(sku),
        category: Value(category),
        sellPrice: Value(sellPrice),
        syncedToLoyverse: Value(synced),
      ),
    );
  }

  Future<void> pumpReview(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(themedApp(ReviewScreen(database: database)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder inNavBar(String text) => find.descendant(
    of: find.byType(OutlinedButton).first,
    matching: find.text(text),
  );

  testWidgets('les motifs d\'incomplétude reflètent ce qui manque réellement', (
    tester,
  ) async {
    await insert(name: 'Complet', synced: true);
    await insert(name: 'Sans prix', sellPrice: null);
    await insert(name: 'Sans catégorie', category: '  ');
    await insert(name: 'Sans rien', sellPrice: null, category: null, sku: null);

    await pumpReview(tester);

    expect(find.text('Catalogue & Loyverse POS'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);

    // Compteurs : 4 produits, 0 sélectionné, 3 incomplets.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('(0 sur 4)'), findsOneWidget);

    expect(find.text('Prix non défini'), findsNWidgets(2));
    expect(find.text('Catégorie non définie'), findsNWidgets(2));
    expect(find.text('SKU non défini'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(3));

    expect(find.text('Synchronisé'), findsOneWidget);
    expect(find.text('En attente'), findsNWidgets(3));
    // Le SKU fait partie d'un Text.rich : recherche par contenu.
    expect(find.textContaining('SKU: SKU-AAAA1111'), findsNWidgets(3));

    await database.close();
  });

  testWidgets('le filtre "Incomplets" restreint la liste et "Tout sélectionner" '
      'porte sur les produits visibles', (tester) async {
    await insert(name: 'Complet');
    await insert(name: 'Sans prix', sellPrice: null);

    await pumpReview(tester);
    expect(inNavBar('Exporter en CSV'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).enabled,
      isFalse,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isFalse,
    );

    await tester.tap(find.text('Incomplets')); // le bouton-filtre
    await tester.pump();
    expect(find.text('Complet'), findsNothing);
    expect(find.text('Sans prix'), findsOneWidget);
    expect(find.textContaining('(0 sur 1)'), findsOneWidget);

    await tester.tap(find.textContaining('Tout sélectionner'));
    await tester.pump();
    expect(find.textContaining('(1 sur 1)'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).enabled,
      isTrue,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isTrue,
    );

    // Filtre désactivé : la sélection est conservée, seul l'incomplet est coché.
    await tester.tap(find.text('Incomplets'));
    await tester.pump();
    expect(find.text('Complet'), findsOneWidget);
    expect(find.textContaining('(1 sur 2)'), findsOneWidget);

    await database.close();
  });
}
