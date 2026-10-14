import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Contenu affiché sous la barre d'état (Android) : le fond clair de
  // l'écran remplit alors le haut, au lieu du bandeau gris du système.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.statusBarStyle);

  await dotenv.load(fileName: '.env');
  await SupabaseBootstrap.initialize();

  final database = AppDatabase();
  // Requête minimale pour vérifier que la base locale est bien accessible.
  await database.select(database.products).get();
  debugPrint(
    '[BoutiqueCatalog] Base de données SQLite initialisée avec succès.',
  );

  runApp(App(database: database));
}
