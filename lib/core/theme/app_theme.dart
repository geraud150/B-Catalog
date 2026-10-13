import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'app_palette.dart';

/// Rayons d'arrondi utilisés dans l'app, extraits des écrans déjà restylés
/// d'après les maquettes Stitch.
abstract final class AppRadius {
  /// Petites étiquettes et pastilles carrées (prix, catégorie...).
  static const tag = 6.0;

  /// Champs compacts (variante) et vignettes secondaires.
  static const small = 8.0;

  /// Onglets de filtre, petites vignettes d'icône.
  static const tab = 10.0;

  /// Champs de saisie et vignettes d'icône de section.
  static const field = 12.0;

  /// Boutons d'action.
  static const button = 14.0;

  /// Cartes de contenu (produit, ligne d'import, indicateurs).
  static const card = 16.0;

  /// Grandes cartes de section (formulaire, hub, en-tête d'import).
  static const section = 24.0;

  /// Boîtes de dialogue.
  static const dialog = 28.0;

  /// Pastilles entièrement arrondies (badges, chips).
  static const pill = 999.0;
}

/// Espacements standards (multiples de 2 dérivés des maquettes).
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Marge latérale des écrans.
  static const screenHorizontal = 20.0;

  /// Largeur maximale du contenu, pour rester lisible sur un écran large
  /// (l'app tourne aussi sous Windows) tout en gardant la mise en page
  /// mobile des maquettes.
  static const contentMaxWidth = 520.0;
}

/// Graisses et tailles de texte utilisées dans l'app.
abstract final class AppTypography {
  /// Police : celle du système (aucune police personnalisée n'est embarquée
  /// dans le pubspec ; les maquettes utilisaient des polices Google non
  /// packagées). `null` laisse Flutter choisir la police système de la
  /// plateforme.
  static const String? fontFamily = null;

  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semiBold = FontWeight.w600;
  static const bold = FontWeight.w700;
  static const extraBold = FontWeight.w800;

  // Tailles, de la plus grande (titre d'écran du hub) à la plus petite
  // (étiquettes et compteurs).
  static const display = 26.0;
  static const headline = 24.0;
  static const title = 20.0;
  static const screenTitle = 18.0;
  static const sectionTitle = 16.0;
  static const body = 14.0;
  static const bodySmall = 13.0;
  static const label = 12.0;
  static const caption = 11.0;
  static const micro = 10.0;
}

/// Thème global de l'app : source de vérité du style violet des maquettes
/// Stitch, pour que tout composant non stylé à la main (dialogue, SnackBar,
/// indicateur de progression, futur écran) hérite automatiquement des bonnes
/// couleurs, formes et typographies.
///
/// Les écrans restylés continuent de poser leurs propres décorations
/// (dégradés, ombres, bordures) via [AppPalette] : le thème couvre ce qui
/// reste aux valeurs par défaut de Material.
abstract final class AppTheme {
  /// Barre d'état Android transparente avec icônes sombres : le fond clair
  /// de l'écran remonte alors jusqu'en haut, au lieu du bandeau gris que
  /// laissait le réglage système par défaut.
  static const statusBarStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppPalette.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData build() {
    final colorScheme = _colorScheme;
    final textTheme = _textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      visualDensity: VisualDensity.comfortable,
      scaffoldBackgroundColor: AppPalette.formBackground,

      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.formBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
        systemOverlayStyle: statusBarStyle,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppPalette.primary.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          side: const BorderSide(color: AppPalette.border),
        ),
        titleTextStyle: const TextStyle(
          fontSize: AppTypography.sectionTitle,
          fontWeight: AppTypography.bold,
          color: AppPalette.text,
        ),
        contentTextStyle: const TextStyle(
          fontSize: AppTypography.bodySmall,
          height: 1.5,
          color: AppPalette.muted,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.brand900,
        contentTextStyle: const TextStyle(
          fontSize: AppTypography.bodySmall,
          fontWeight: AppTypography.medium,
          color: Colors.white,
        ),
        actionTextColor: AppPalette.brand200,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: _buttonShape,
          textStyle: _buttonTextStyle,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppPalette.border,
          disabledForegroundColor: AppPalette.muted,
          shape: _buttonShape,
          textStyle: _buttonTextStyle,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.primary,
          backgroundColor: AppPalette.surface,
          side: const BorderSide(color: AppPalette.brand200),
          shape: _buttonShape,
          textStyle: _buttonTextStyle,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.primary,
          shape: _buttonShape,
          textStyle: _buttonTextStyle,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppPalette.brand600,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),

      cardTheme: CardThemeData(
        color: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppPalette.cardBorder),
        ),
      ),

      // Sans cela, les indicateurs non stylés (chargement d'une liste,
      // progression d'import/sync) restaient sur le violet par défaut de
      // Material.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.primary,
        linearTrackColor: AppPalette.primaryLight,
        circularTrackColor: Colors.transparent,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.brand100,
        indicatorShape: const CircleBorder(),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 20,
            color: states.contains(WidgetState.selected)
                ? AppPalette.brand700
                : AppPalette.slate400,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: AppTypography.caption,
            fontWeight: states.contains(WidgetState.selected)
                ? AppTypography.bold
                : AppTypography.semiBold,
            color: states.contains(WidgetState.selected)
                ? AppPalette.brand700
                : AppPalette.slate400,
          ),
        ),
      ),

      // Rail latéral affiché à la place de la barre d'onglets sur grand
      // écran : mêmes couleurs et mêmes graisses que `navigationBarTheme`.
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppPalette.surface,
        indicatorColor: AppPalette.brand100,
        indicatorShape: const CircleBorder(),
        selectedIconTheme: const IconThemeData(
          size: 20,
          color: AppPalette.brand700,
        ),
        unselectedIconTheme: const IconThemeData(
          size: 20,
          color: AppPalette.slate400,
        ),
        selectedLabelTextStyle: const TextStyle(
          fontSize: AppTypography.caption,
          fontWeight: AppTypography.bold,
          color: AppPalette.brand700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: AppTypography.caption,
          fontWeight: AppTypography.semiBold,
          color: AppPalette.slate400,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.fieldBackground,
        hintStyle: TextStyle(
          fontSize: AppTypography.body,
          color: AppPalette.muted.withValues(alpha: 0.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg - 2,
          vertical: AppSpacing.md,
        ),
        enabledBorder: _fieldBorder(AppPalette.border),
        focusedBorder: _fieldBorder(AppPalette.primary, 1.5),
        errorBorder: _fieldBorder(AppPalette.rose500),
        focusedErrorBorder: _fieldBorder(AppPalette.rose500, 1.5),
        errorStyle: const TextStyle(
          fontSize: AppTypography.caption,
          color: AppPalette.rose700,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppPalette.brand600
              : Colors.transparent,
        ),
        side: const BorderSide(color: AppPalette.slate300, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tag),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppPalette.cardBorder,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          fontSize: AppTypography.body,
          color: AppPalette.text,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: AppTypography.label,
          color: AppPalette.muted,
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppPalette.brand900,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        textStyle: const TextStyle(
          fontSize: AppTypography.caption,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Violet de marque en primaire, rose des alertes en secondaire : les deux
  /// couleurs portantes des maquettes.
  static const _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.primary,
    onPrimary: Colors.white,
    primaryContainer: AppPalette.primaryLight,
    onPrimaryContainer: AppPalette.brand800,
    secondary: AppPalette.rose500,
    onSecondary: Colors.white,
    secondaryContainer: AppPalette.rose100,
    onSecondaryContainer: AppPalette.rose700,
    tertiary: AppPalette.emerald600,
    onTertiary: Colors.white,
    tertiaryContainer: AppPalette.emerald50,
    onTertiaryContainer: AppPalette.emerald700,
    error: AppPalette.danger,
    onError: Colors.white,
    errorContainer: AppPalette.alertBackground,
    onErrorContainer: AppPalette.rose700,
    surface: AppPalette.surface,
    onSurface: AppPalette.text,
    surfaceContainerLowest: AppPalette.surface,
    surfaceContainerLow: AppPalette.fieldBackground,
    surfaceContainer: AppPalette.formBackground,
    surfaceContainerHigh: AppPalette.primarySubtle,
    surfaceContainerHighest: AppPalette.primaryLight,
    onSurfaceVariant: AppPalette.muted,
    outline: AppPalette.border,
    outlineVariant: AppPalette.cardBorder,
    inverseSurface: AppPalette.brand900,
    onInverseSurface: Colors.white,
    inversePrimary: AppPalette.brand200,
    shadow: Color(0x1A604C82),
    scrim: Color(0x991B1229),
  );

  static const _textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: AppTypography.display,
      fontWeight: AppTypography.extraBold,
      color: AppPalette.slate900,
      letterSpacing: -0.6,
    ),
    headlineSmall: TextStyle(
      fontSize: AppTypography.headline,
      fontWeight: AppTypography.extraBold,
      color: AppPalette.slate900,
      letterSpacing: -0.5,
    ),
    titleLarge: TextStyle(
      fontSize: AppTypography.title,
      fontWeight: AppTypography.bold,
      color: AppPalette.slate900,
      letterSpacing: -0.3,
    ),
    titleMedium: TextStyle(
      fontSize: AppTypography.screenTitle,
      fontWeight: AppTypography.bold,
      color: AppPalette.text,
      letterSpacing: -0.3,
    ),
    titleSmall: TextStyle(
      fontSize: AppTypography.sectionTitle,
      fontWeight: AppTypography.bold,
      color: AppPalette.text,
    ),
    bodyLarge: TextStyle(
      fontSize: AppTypography.sectionTitle,
      fontWeight: AppTypography.regular,
      color: AppPalette.text,
    ),
    bodyMedium: TextStyle(
      fontSize: AppTypography.body,
      fontWeight: AppTypography.regular,
      color: AppPalette.text,
    ),
    bodySmall: TextStyle(
      fontSize: AppTypography.bodySmall,
      fontWeight: AppTypography.regular,
      color: AppPalette.muted,
      height: 1.5,
    ),
    labelLarge: TextStyle(
      fontSize: AppTypography.bodySmall,
      fontWeight: AppTypography.semiBold,
      color: AppPalette.text,
    ),
    labelMedium: TextStyle(
      fontSize: AppTypography.label,
      fontWeight: AppTypography.semiBold,
      color: AppPalette.text,
    ),
    labelSmall: TextStyle(
      fontSize: AppTypography.caption,
      fontWeight: AppTypography.medium,
      color: AppPalette.muted,
    ),
  );

  static const _buttonTextStyle = TextStyle(
    fontSize: AppTypography.bodySmall,
    fontWeight: AppTypography.semiBold,
  );

  static final _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.button),
  );

  static OutlineInputBorder _fieldBorder(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
