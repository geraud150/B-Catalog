import 'package:boutique_catalog/app.dart';
import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/core/theme/app_palette.dart';
import 'package:boutique_catalog/core/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final theme = AppTheme.build();

  test('le colorScheme porte les couleurs des maquettes, pas deepPurple', () {
    final colors = theme.colorScheme;
    expect(colors.primary, AppPalette.primary);
    expect(colors.secondary, AppPalette.rose500);
    expect(colors.error, AppPalette.danger);
    expect(colors.surface, AppPalette.surface);
    expect(colors.brightness, Brightness.light);

    // Aucune teinte du violet par défaut de Flutter ne subsiste.
    final defaultPurples = {
      ...Colors.deepPurple.shades,
      ...Colors.purple.shades,
    };
    for (final color in [
      colors.primary,
      colors.onPrimary,
      colors.primaryContainer,
      colors.secondary,
      colors.secondaryContainer,
      colors.tertiary,
      colors.error,
      colors.surface,
      colors.surfaceContainerHighest,
      colors.outline,
      colors.inversePrimary,
    ]) {
      expect(
        defaultPurples.contains(color),
        isFalse,
        reason: '$color provient de la palette Material par défaut',
      );
    }
  });

  test('dialogues et SnackBars ont un style défini par le thème', () {
    final dialog = theme.dialogTheme;
    expect(dialog.backgroundColor, AppPalette.surface);
    expect(dialog.titleTextStyle?.fontWeight, AppTypography.bold);
    expect(dialog.titleTextStyle?.color, AppPalette.text);
    expect(
      (dialog.shape as RoundedRectangleBorder?)?.borderRadius,
      BorderRadius.circular(AppRadius.dialog),
    );

    final snackBar = theme.snackBarTheme;
    expect(snackBar.backgroundColor, AppPalette.brand900);
    expect(snackBar.contentTextStyle?.color, Colors.white);
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(
      (snackBar.shape as RoundedRectangleBorder?)?.borderRadius,
      BorderRadius.circular(AppRadius.button),
    );
  });

  test('les boutons et indicateurs suivent la couleur primaire', () {
    const states = <WidgetState>{};
    expect(
      theme.elevatedButtonTheme.style?.backgroundColor?.resolve(states),
      AppPalette.primary,
    );
    expect(
      theme.textButtonTheme.style?.foregroundColor?.resolve(states),
      AppPalette.primary,
    );
    expect(theme.progressIndicatorTheme.color, AppPalette.primary);
  });

  test('le textTheme reprend les tailles et graisses des écrans', () {
    expect(theme.textTheme.bodyMedium?.fontSize, AppTypography.body);
    expect(theme.textTheme.titleMedium?.fontWeight, AppTypography.bold);
    expect(theme.textTheme.titleMedium?.fontSize, AppTypography.screenTitle);
    expect(theme.textTheme.labelSmall?.fontSize, AppTypography.caption);
  });

  testWidgets('l\'app applique ce thème à sa racine', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(App(database: database));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final context = tester.element(find.byType(NavigationBar));
    final applied = Theme.of(context);
    expect(applied.colorScheme.primary, AppPalette.primary);
    expect(applied.snackBarTheme.backgroundColor, AppPalette.brand900);
    expect(applied.dialogTheme.backgroundColor, AppPalette.surface);

    await database.close();
  });
}

extension on MaterialColor {
  /// Toutes les teintes standard d'une couleur Material.
  Set<Color> get shades => {
    for (final shade in [50, 100, 200, 300, 400, 500, 600, 700, 800, 900])
      this[shade]!,
  };
}
