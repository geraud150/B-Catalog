import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/home/home_screen.dart';
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

  const phone = Size(430, 900);
  const desktop = Size(1400, 900);

  Future<void> insert(String name, {required DateTime updatedAt}) {
    return database.insertProduct(
      ProductsCompanion.insert(
        name: name,
        sellPrice: const Value(1000),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(themedApp(HomeScreen(database: database)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('activité récente', () {
    testWidgets('liste les produits du plus récemment modifié au plus ancien', (
      tester,
    ) async {
      final now = DateTime.now();
      // Insérés dans le désordre pour que l'ordre affiché vienne bien du tri
      // sur updatedAt et non de l'ordre d'insertion.
      await insert('Ancien', updatedAt: now.subtract(const Duration(days: 3)));
      await insert('Récent', updatedAt: now.subtract(const Duration(minutes: 5)));
      await insert('Moyen', updatedAt: now.subtract(const Duration(hours: 4)));

      await pumpAt(tester, desktop);

      expect(find.text('Activité récente'), findsOneWidget);

      double top(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(top('Récent'), lessThan(top('Moyen')));
      expect(top('Moyen'), lessThan(top('Ancien')));

      // L'ancienneté accompagne chaque ligne.
      expect(find.text('il y a 5 min'), findsOneWidget);
      expect(find.text('il y a 4 h'), findsOneWidget);
      expect(find.text('il y a 3 j'), findsOneWidget);

      await database.close();
    });

    testWidgets('se limite à 8 lignes même avec davantage de produits', (
      tester,
    ) async {
      final now = DateTime.now();
      for (var i = 0; i < 12; i++) {
        await insert(
          'Produit $i',
          updatedAt: now.subtract(Duration(minutes: i + 1)),
        );
      }

      await pumpAt(tester, desktop);

      // Les 8 plus récents sont là, le 9e et au-delà non.
      expect(find.text('Produit 0'), findsOneWidget);
      expect(find.text('Produit 7'), findsOneWidget);
      expect(find.text('Produit 8'), findsNothing);
      expect(find.text('Produit 11'), findsNothing);

      await database.close();
    });

    testWidgets('ouvre la fiche en édition au clic sur une ligne', (
      tester,
    ) async {
      await insert('Casque', updatedAt: DateTime.now());

      await pumpAt(tester, desktop);
      await tester.tap(find.text('Casque'));
      await tester.pumpAndSettle();

      // L'écran de saisie s'ouvre sur la fiche existante, pas sur une
      // création : le titre le distingue.
      expect(find.text('Modifier le produit'), findsOneWidget);

      await database.close();
    });

    testWidgets('absente en mise en page mobile', (tester) async {
      await insert('Casque', updatedAt: DateTime.now());

      await pumpAt(tester, phone);

      // La colonne mobile est déjà pleine : le bloc ne s'y affiche pas.
      expect(find.text('Activité récente'), findsNothing);

      await database.close();
    });

    testWidgets('rien ne s\'affiche tant que le catalogue est vide', (
      tester,
    ) async {
      await pumpAt(tester, desktop);

      expect(find.text('Activité récente'), findsNothing);

      await database.close();
    });
  });

  group('indicateur Loyverse', () {
    /// Concatène les fragments du `Text.rich` de la tuile : la valeur est
    /// composée de trois spans de couleurs différentes, donc introuvable par
    /// `find.text`.
    String loyverseValue(WidgetTester tester) {
      final tile = tester.widget<Text>(
        find.descendant(
          of: find.byType(HomeScreen),
          matching: find.byWidgetPredicate(
            (w) => w is Text && w.textSpan != null,
          ),
        ),
      );
      return tile.textSpan!.toPlainText();
    }

    Future<void> insertSynced(String name, {required bool synced}) {
      return database.insertProduct(
        ProductsCompanion.insert(name: name, syncedToLoyverse: Value(synced)),
      );
    }

    testWidgets('affiche les synchronisés et ceux en attente, pas un seul '
        'chiffre', (tester) async {
      await insertSynced('Poussé', synced: true);
      await insertSynced('Poussé aussi', synced: true);
      await insertSynced('Pas encore', synced: false);

      await pumpAt(tester, desktop);

      expect(find.text('Loyverse'), findsOneWidget);
      // Deux synchronisés, un en attente : les deux nombres sont lisibles
      // côte à côte.
      expect(loyverseValue(tester), '2 / 1');
      expect(find.text('synchro. / en attente'), findsOneWidget);

      await database.close();
    });

    testWidgets('les deux nombres couvrent tout le catalogue', (tester) async {
      for (var i = 0; i < 5; i++) {
        await insertSynced('Produit $i', synced: i.isEven);
      }

      await pumpAt(tester, desktop);

      // 3 pairs synchronisés, 2 impairs en attente : la somme fait bien le
      // catalogue complet.
      expect(loyverseValue(tester), '3 / 2');

      await database.close();
    });

    testWidgets('la légende s\'efface en mobile, les deux nombres restent', (
      tester,
    ) async {
      await insertSynced('Poussé', synced: true);
      await insertSynced('Pas encore', synced: false);

      await pumpAt(tester, phone);

      // La tuile mobile est trop étroite pour la légende, mais la couleur
      // continue de distinguer les deux nombres.
      expect(find.text('synchro. / en attente'), findsNothing);
      expect(loyverseValue(tester), '1 / 1');

      await database.close();
    });
  });
}
