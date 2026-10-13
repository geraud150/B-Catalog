import '../config.dart';

/// Formate un montant pour l'affichage à l'écran (liste des produits, écran
/// de vérification...) : sans décimale superflue (`450000.0` -> `450 000`),
/// avec un espace tous les 3 chiffres comme c'est l'usage en FCFA.
///
/// Ne pas utiliser pour l'export CSV Loyverse : celui-ci a besoin d'un
/// nombre brut, sans séparateur de milliers (voir `CsvExportService`).
String formatAmount(double value) {
  final rounded = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
  final parts = rounded.split('.');
  final digits = parts.first;
  final negative = digits.startsWith('-');
  final unsigned = negative ? digits.substring(1) : digits;

  final buffer = StringBuffer();
  for (var i = 0; i < unsigned.length; i++) {
    if (i > 0 && (unsigned.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(unsigned[i]);
  }

  final integerPart = '${negative ? '-' : ''}$buffer';
  return parts.length > 1 ? '$integerPart.${parts[1]}' : integerPart;
}

/// Formate un prix avec sa devise ([kCurrencySymbol]), ou un texte indiquant
/// son absence si [value] est `null`.
String formatPrice(double? value) {
  if (value == null) return 'Prix non défini';
  return '${formatAmount(value)} $kCurrencySymbol';
}
