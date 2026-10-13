import 'dart:io';

import 'package:boutique_catalog/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('version affichée', () {
    test('la constante correspond au champ version du pubspec', () {
      // Seul garde-fou de la méthode retenue : la version est une constante
      // Dart (Flutter n'expose pas le pubspec à l'exécution), donc rien
      // n'empêcherait les deux de diverger après un changement de version.
      // Ce test échoue alors, avec la marche à suivre.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*(\S+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(match, isNotNull, reason: 'aucun champ "version:" dans pubspec.yaml');
      expect(
        appVersion,
        match!.group(1),
        reason: 'pubspec.yaml et lib/core/app_version.dart ont divergé : '
            'reportez la nouvelle version dans la constante appVersion',
      );
    });

    test('le libellé masque le numéro de build', () {
      // Le "+1" n'intéresse que les stores : l'utilisatrice lit "v1.0.0".
      expect(appVersionLabel, 'v${appVersion.split('+').first}');
      expect(appVersionLabel, startsWith('v'));
      expect(appVersionLabel, isNot(contains('+')));
    });
  });
}
