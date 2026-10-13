import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/core/utils/handle.dart';
import 'package:flutter_test/flutter_test.dart';

Product _buildProduct({String name = 'Produit', String? groupId}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: 1,
    name: name,
    groupId: groupId,
    quantity: 0,
    createdAt: now,
    updatedAt: now,
    syncedToLoyverse: false,
  );
}

void main() {
  test('chaîne vide pour un produit sans groupId', () {
    expect(generateHandle(_buildProduct(groupId: null)), '');
  });

  test('slug en minuscules, sans accents, espaces remplacés par des tirets', () {
    final handle = generateHandle(
      _buildProduct(name: 'Rouge à lèvres Mat', groupId: 'a1b2c3d4-e5f6'),
    );

    expect(handle, 'rouge-a-levres-mat-a1b2c3');
  });

  test('deux produits du même groupe ont exactement le même handle', () {
    const groupId = 'group-xyz';
    final handleA = generateHandle(
      _buildProduct(name: 'Polo', groupId: groupId),
    );
    final handleB = generateHandle(
      _buildProduct(name: 'Polo', groupId: groupId),
    );

    expect(handleA, handleB);
  });

  test('deux groupes différents avec un nom similaire ont des handles distincts', () {
    final handle1 = generateHandle(_buildProduct(name: 'Polo', groupId: 'group-1'));
    final handle2 = generateHandle(_buildProduct(name: 'Polo', groupId: 'group-2'));

    expect(handle1, isNot(handle2));
  });
}
