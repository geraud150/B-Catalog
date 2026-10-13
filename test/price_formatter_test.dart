import 'package:boutique_catalog/core/utils/price_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatAmount', () {
    test('retire la décimale superflue', () {
      expect(formatAmount(12), '12');
      expect(formatAmount(450000), '450 000');
    });

    test('garde la décimale quand elle est significative', () {
      expect(formatAmount(12.5), '12.5');
    });

    test('ajoute un espace tous les 3 chiffres', () {
      expect(formatAmount(1000), '1 000');
      expect(formatAmount(1250000), '1 250 000');
      expect(formatAmount(999), '999');
    });

    test('gère les montants négatifs', () {
      expect(formatAmount(-1000), '-1 000');
    });
  });

  group('formatPrice', () {
    test('ajoute la devise après le montant', () {
      expect(formatPrice(450000), '450 000 FCFA');
    });

    test('indique l\'absence de prix', () {
      expect(formatPrice(null), 'Prix non défini');
    });
  });
}
