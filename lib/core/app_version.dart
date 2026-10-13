import 'package:flutter/material.dart';

import 'theme/app_palette.dart';
import 'theme/app_theme.dart';

/// Version du logiciel, tenue en phase avec le champ `version` du
/// `pubspec.yaml`.
///
/// Flutter n'expose pas la version du pubspec à l'exécution : il faut soit un
/// greffon natif (`package_info_plus`), soit une constante. La constante
/// évite d'ajouter une dépendance native et un appel asynchrone pour un
/// simple libellé de coin d'écran ; `test/app_version_test.dart` relit le
/// pubspec et échoue si les deux divergent, ce qui referme le seul vrai
/// risque de cette méthode.
const appVersion = '1.0.0+1';

/// Libellé affiché. Le numéro de build (`+1`) ne sert qu'aux stores et aux
/// métadonnées de l'exécutable : il n'apprend rien à qui lit un coin
/// d'écran, donc on ne garde que le nom de version.
String get appVersionLabel => 'v${appVersion.split('+').first}';

/// Mention de version, volontairement secondaire : la plus petite taille de
/// l'échelle typographique, le gris le plus clair de la palette et une
/// opacité réduite. Elle doit se lire quand on la cherche, et disparaître
/// le reste du temps.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.7,
      child: Text(
        appVersionLabel,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: AppTypography.micro,
          fontWeight: AppTypography.medium,
          color: AppPalette.slate400,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
