import 'package:boutique_catalog/core/utils/number_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseFrenchNumber', () {
    test('lit les entiers et décimaux à point', () {
      expect(parseFrenchNumber('12'), 12);
      expect(parseFrenchNumber('12.5'), 12.5);
    });

    test('remplace la virgule décimale par un point', () {
      expect(parseFrenchNumber('12,50'), 12.5);
      expect(parseFrenchNumber('0,99'), 0.99);
    });

    test('retire les espaces de milliers, y compris insécables', () {
      expect(parseFrenchNumber('1 250'), 1250);
      expect(parseFrenchNumber('1 250,75'), 1250.75);
      expect(parseFrenchNumber('1 250'), 1250);
      expect(parseFrenchNumber('  42  '), 42);
    });

    test('ignore une devise avant ou après le nombre', () {
      expect(parseFrenchNumber('12,50 €'), 12.5);
      expect(parseFrenchNumber('12€'), 12);
      expect(parseFrenchNumber('450 000 FCFA'), 450000);
      expect(parseFrenchNumber('8 500 F CFA'), 8500);
      expect(parseFrenchNumber('XOF 8 500'), 8500);
      expect(parseFrenchNumber('12 000 F'), 12000);
    });

    test('ne retourne pas de nombre sur une devise seule', () {
      expect(parseFrenchNumber('FCFA'), isNull);
      expect(parseFrenchNumber('€'), isNull);
    });

    test('retourne null sur une valeur vide ou illisible, sans planter', () {
      expect(parseFrenchNumber(''), isNull);
      expect(parseFrenchNumber('   '), isNull);
      expect(parseFrenchNumber('abc'), isNull);
      expect(parseFrenchNumber('12,5,3'), isNull);
      expect(parseFrenchNumber('N/A'), isNull);
    });
  });
}
