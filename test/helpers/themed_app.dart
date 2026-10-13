import 'package:boutique_catalog/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Enveloppe [home] dans un `MaterialApp` portant le thème réel de l'app
/// ([AppTheme.build]), pour que les tests widget s'exécutent dans le même
/// contexte de thème que l'application lancée.
///
/// Sans cela, les écrans seraient montés sous le thème Material par défaut :
/// les tests passeraient malgré une régression de thème (dialogue, SnackBar
/// ou indicateur revenu au violet par défaut de Flutter).
MaterialApp themedApp(Widget home) {
  return MaterialApp(theme: AppTheme.build(), home: home);
}
