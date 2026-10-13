import 'package:boutique_catalog/core/utils/sku_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateSafeSku', () {
    test('respecte le format "SKU-" + 8 caractères hexadécimaux majuscules', () {
      final sku = generateSafeSku();

      expect(sku, startsWith('SKU-'));
      expect(sku, matches(RegExp(r'^SKU-[0-9A-F]{8}$')));
    });

    test('ne contient aucun accent ni caractère spécial hors le tiret', () {
      final sku = generateSafeSku();

      // Alphanumérique + un unique tiret (celui du préfixe) : rien d'autre.
      expect(sku, matches(RegExp(r'^[A-Z0-9-]+$')));
      expect('-'.allMatches(sku).length, 1);
    });

    test('deux appels successifs ne produisent pas le même SKU', () {
      // Techniquement pas garanti à 100 % (32 bits de hasard), mais une
      // collision immédiate en test signalerait un générateur cassé (valeur
      // figée, mauvaise troncature...).
      final skus = List.generate(50, (_) => generateSafeSku());

      expect(skus.toSet().length, skus.length);
    });
  });
}
