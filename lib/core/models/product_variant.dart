/// Variante simple d'un produit (ex: teinte, taille).
class ProductVariant {
  final String optionName;
  final String optionValue;

  const ProductVariant({
    required this.optionName,
    required this.optionValue,
  });
}
