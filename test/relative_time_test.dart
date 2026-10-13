import 'package:boutique_catalog/core/utils/relative_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Référence fixe : sans elle, les cas proches des bornes basculeraient
  // d'une exécution à l'autre.
  final now = DateTime(2026, 9, 23, 14, 30);
  String at(Duration ago) => formatRelativeTime(now.subtract(ago), now: now);

  group('formatRelativeTime', () {
    test('les moins d\'une minute sont « à l\'instant »', () {
      expect(at(Duration.zero), 'à l\'instant');
      expect(at(const Duration(seconds: 59)), 'à l\'instant');
    });

    test('minutes puis heures', () {
      expect(at(const Duration(minutes: 1)), 'il y a 1 min');
      expect(at(const Duration(minutes: 59)), 'il y a 59 min');
      expect(at(const Duration(hours: 1)), 'il y a 1 h');
      expect(at(const Duration(hours: 23)), 'il y a 23 h');
    });

    test('hier, puis les jours jusqu\'à une semaine', () {
      expect(at(const Duration(days: 1)), 'hier');
      expect(at(const Duration(days: 2)), 'il y a 2 j');
      expect(at(const Duration(days: 6)), 'il y a 6 j');
    });

    test('au-delà d\'une semaine, une date absolue', () {
      // « il y a 23 j » n'aide plus : on donne le jour, sur deux chiffres.
      expect(at(const Duration(days: 7)), 'le 16/09/2026');
      expect(formatRelativeTime(DateTime(2026, 3, 4), now: now), 'le 04/03/2026');
    });

    test('un horodatage futur ne produit pas de durée négative', () {
      // Horloge système reculée ou date d'import erronée : mieux vaut
      // « à l'instant » que « il y a -3 min ».
      expect(
        formatRelativeTime(now.add(const Duration(hours: 5)), now: now),
        'à l\'instant',
      );
    });
  });
}
