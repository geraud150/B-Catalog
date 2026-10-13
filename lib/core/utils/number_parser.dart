/// Convertit un nombre écrit "à la française" en [double].
///
/// Tolère les formes courantes dans un tableau saisi à la main :
/// - séparateur de milliers par espace (`1 250`), y compris les espaces
///   insécables que Word insère automatiquement ;
/// - virgule décimale (`12,50`) ;
/// - une devise accolée ou non, avant ou après le nombre (`450 000 FCFA`,
///   `12,50 €`, `12€`, `XOF 8 500`).
///
/// Retourne `null` si [value] est vide ou ne représente pas un nombre : la
/// fonction ne lève jamais d'exception, l'appelant décide quoi faire d'une
/// valeur illisible.
double? parseFrenchNumber(String value) {
  // `\s` couvre aussi l'espace insécable (U+00A0) et l'espace fine
  // insécable (U+202F) utilisées par Word comme séparateurs de milliers.
  final normalized = value
      .replaceAll(RegExp(r'\s'), '')
      // Retire tout ce qui entoure le nombre et n'en fait pas partie
      // (devise, symbole, lettres) : "450000FCFA" -> "450000", "€12" -> "12".
      .replaceAll(RegExp(r'^[^\d\-+.,]+|[^\d\-+.,]+$'), '')
      .replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
