import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'app_shell.dart';
import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Nom court : c'est celui affiché par le sélecteur de tâches Android
      // et, sur le lanceur, par `android:label` (AndroidManifest.xml).
      title: 'B-Catalog',
      theme: AppTheme.build(),
      // Les écrans sans AppBar (accueil, liste) n'imposent pas de style de
      // barre d'état : cette région le fait pour toute l'app.
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.statusBarStyle,
        child: AppShell(database: database),
      ),
    );
  }
}
