import 'product_variant.dart';

/// Modèle métier représentant un produit du catalogue.
class Product {
  final int? id;
  final String? barcode;
  final String? sku;
  final String name;
  final String? category;
  final String? description;
  final double? costPrice;
  final double? sellPrice;
  final int quantity;
  final String? photoPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncedToLoyverse;
  final ProductVariant? variant;

  const Product({
    this.id,
    this.barcode,
    this.sku,
    required this.name,
    this.category,
    this.description,
    this.costPrice,
    this.sellPrice,
    this.quantity = 0,
    this.photoPath,
    required this.createdAt,
    required this.updatedAt,
    this.syncedToLoyverse = false,
    this.variant,
  });
}
