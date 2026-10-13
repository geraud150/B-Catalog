import 'package:boutique_catalog/app_shell.dart';
import 'package:boutique_catalog/core/app_version.dart';
import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/core/theme/app_breakpoints.dart';
import 'package:boutique_catalog/features/home/home_screen.dart';
import 'package:boutique_catalog/features/import/import_hub_screen.dart';
import 'package:boutique_catalog/features/product_list/product_list_screen.dart';
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

  /// Fixe la taille de la fenêtre puis monte [screen].
  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Widget screen,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(themedApp(screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  const phone = Size(430, 900);
  const desktop = Size(1400, 900);

  Future<int> insert(String name) => database.insertProduct(
    ProductsCompanion.insert(name: name, sellPrice: const Value(1000)),
  );

  group('points de rupture', () {
    test('la mise en page large commence au-dessus de 800 px', () {
      expect(AppBreakpoints.isWide(800), isFalse);
      expect(AppBreakpoints.isWide(801), isTrue);
      expect(AppBreakpoints.columnsFor(430), 1);
      expect(AppBreakpoints.columnsFor(800), 1);
      // Téléphone en paysage / petite tablette : deux colonnes y tiendraient
      // géométriquement, mais à moins de 420 px chacune — donc avec des noms
      // tronqués. On reste à une colonne.
      expect(AppBreakpoints.columnsFor(900), 1);
      expect(AppBreakpoints.columnsFor(1000), 2);
      expect(AppBreakpoints.columnsFor(1400), 2);
      expect(AppBreakpoints.columnsFor(1600), 3);
    });

    test('la largeur du contenu suit le nombre de colonnes', () {
      // Le défaut corrigé ici : les colonnes étaient calculées à partir de
      // la fenêtre pendant que la largeur du contenu restait figée. En
      // passant à trois colonnes, les cartes rétrécissaient donc alors que
      // la fenêtre venait de s'agrandir.
      expect(
        AppBreakpoints.contentMaxWidthFor(1600),
        greaterThan(AppBreakpoints.contentMaxWidthFor(1000)),
      );
    });

    test('une carte ne descend jamais sous sa largeur lisible', () {
      /// Largeur réelle d'une carte pour une fenêtre de [width] : le contenu
      /// est borné à la fois par sa largeur idéale et par la place restante
      /// une fois le rail déduit.
      double cardWidth(double width) {
        final columns = AppBreakpoints.columnsFor(width);
        final available = width - AppBreakpoints.railWidth;
        final content = AppBreakpoints.contentMaxWidthFor(width) < available
            ? AppBreakpoints.contentMaxWidthFor(width)
            : available;
        final usable = content -
            AppBreakpoints.listPadding -
            (columns - 1) * AppBreakpoints.gap;
        return usable / columns;
      }

      // Balayage de toutes les largeurs de fenêtre plausibles : aucune ne
      // doit produire de carte trop étroite, et surtout agrandir la fenêtre
      // ne doit jamais rétrécir les cartes d'un cran de colonne à l'autre.
      for (var width = 801.0; width <= 2600; width += 1) {
        expect(
          cardWidth(width),
          greaterThanOrEqualTo(419.9),
          reason: 'carte trop étroite à ${width.toInt()} px de large',
        );
      }
    });

    test('chunkIntoRows regroupe les éléments par colonnes', () {
      expect(chunkIntoRows([1, 2, 3], 1), [
        [1],
        [2],
        [3],
      ]);
      expect(chunkIntoRows([1, 2, 3], 2), [
        [1, 2],
        [3],
      ]);
      expect(chunkIntoRows(<int>[], 2), isEmpty);
    });
  });

  group('navigation', () {
    testWidgets('barre du bas sur petit écran, rail latéral sur grand', (
      tester,
    ) async {
      await pumpAt(tester, phone, AppShell(database: database));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      tester.view.physicalSize = desktop;
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // Mêmes destinations dans les deux formes.
      for (final label in ['Accueil', 'Produits', 'Import / Export']) {
        expect(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }

      await database.close();
    });

    testWidgets('le rail garde la navigation entre onglets fonctionnelle', (
      tester,
    ) async {
      await pumpAt(tester, desktop, AppShell(database: database));

      await tester.tap(find.text('Import / Export'));
      await tester.pumpAndSettle();
      expect(find.text('Import & export'), findsOneWidget);

      await tester.tap(find.text('Accueil'));
      await tester.pumpAndSettle();
      expect(find.text('Actions principales'), findsOneWidget);

      await database.close();
    });
  });

  group('mention de version', () {
    testWidgets('au bas du rail sur grand écran, sous l\'accueil sur mobile, '
        'jamais les deux à la fois', (tester) async {
      await pumpAt(tester, phone, AppShell(database: database));

      // Mobile : sous le contenu de l'accueil, donc plus bas que les
      // indicateurs, et hors du rail (qui n'existe pas à cette taille).
      expect(find.text(appVersionLabel), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(appVersionLabel)).dy,
        greaterThan(tester.getTopLeft(find.text('Produits').first).dy),
      );

      tester.view.physicalSize = desktop;
      await tester.pumpAndSettle();

      // Grand écran : une seule occurrence, dans la colonne du rail cette
      // fois — elle est posée sous lui, pas dedans, donc on la situe par sa
      // position plutôt que par la hiérarchie des widgets.
      expect(find.text(appVersionLabel), findsOneWidget);
      expect(
        tester.getCenter(find.text(appVersionLabel)).dx,
        lessThan(tester.getBottomRight(find.byType(NavigationRail)).dx),
      );

      await database.close();
    });

    testWidgets('reste sous les destinations du rail', (tester) async {
      await pumpAt(tester, desktop, AppShell(database: database));

      // Elle est poussée en bas : au-dessous de la dernière destination, et
      // dans la moitié basse de la fenêtre.
      final label = tester.getTopLeft(find.text(appVersionLabel)).dy;
      expect(label, greaterThan(tester.getTopLeft(find.text('Import / Export')).dy));
      expect(label, greaterThan(desktop.height / 2));

      await database.close();
    });
  });

  group('accueil', () {
    testWidgets('les quatre actions passent sur une seule rangée sur grand '
        'écran, et restent en 2×2 sur mobile', (tester) async {
      await pumpAt(tester, phone, HomeScreen(database: database));

      double top(String title) => tester.getTopLeft(find.text(title)).dy;
      double left(String title) => tester.getTopLeft(find.text(title)).dx;

      // Mobile : "Vérifier & Exporter" est sur la rangée du dessous.
      expect(top('Vérifier & Exporter'), greaterThan(top('Ajouter un produit')));

      tester.view.physicalSize = desktop;
      await tester.pumpAndSettle();

      // Grand écran : les quatre cartes partagent la même rangée (les
      // titres restent alignés à quelques pixels près, selon la hauteur du
      // contenu de chaque carte) et se suivent de gauche à droite.
      final reference = top('Ajouter un produit');
      for (final title in [
        'Liste des produits',
        'Vérifier & Exporter',
        'Importer un document',
      ]) {
        expect(top(title), closeTo(reference, 16));
      }
      expect(left('Liste des produits'), greaterThan(left('Ajouter un produit')));
      expect(
        left('Vérifier & Exporter'),
        greaterThan(left('Liste des produits')),
      );
      expect(
        left('Importer un document'),
        greaterThan(left('Vérifier & Exporter')),
      );

      await database.close();
    });
  });

  group('liste des produits', () {
    testWidgets('une colonne sur mobile, plusieurs sur grand écran', (
      tester,
    ) async {
      await insert('Alpha');
      await insert('Bravo');

      await pumpAt(tester, phone, ProductListScreen(database: database));
      final alphaTopPhone = tester.getTopLeft(find.text('Alpha')).dy;
      final bravoTopPhone = tester.getTopLeft(find.text('Bravo')).dy;
      expect(bravoTopPhone, greaterThan(alphaTopPhone));

      tester.view.physicalSize = desktop;
      await tester.pumpAndSettle();
      // Côte à côte : même hauteur, colonnes différentes.
      expect(
        tester.getTopLeft(find.text('Bravo')).dy,
        tester.getTopLeft(find.text('Alpha')).dy,
      );
      expect(
        tester.getTopLeft(find.text('Bravo')).dx,
        greaterThan(tester.getTopLeft(find.text('Alpha')).dx),
      );

      await database.close();
    });
  });

  group('hub import', () {
    testWidgets('cartes empilées sur mobile, côte à côte sur grand écran', (
      tester,
    ) async {
      await pumpAt(tester, phone, ImportHubScreen(database: database));
      expect(
        tester.getTopLeft(find.text('Vérifier et exporter')).dy,
        greaterThan(
          tester.getTopLeft(find.text('Importer un document Word')).dy,
        ),
      );

      tester.view.physicalSize = desktop;
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Vérifier et exporter')).dx,
        greaterThan(
          tester.getTopLeft(find.text('Importer un document Word')).dx,
        ),
      );

      await database.close();
    });
  });
}
