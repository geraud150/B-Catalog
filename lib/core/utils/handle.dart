import '../database/app_database.dart';

/// Génère le Handle Loyverse d'un [product].
///
/// - Un produit autonome (`groupId` nul) n'a pas besoin de Handle : Loyverse
///   lui en attribue un automatiquement à l'import. On retourne alors une
///   chaîne vide.
/// - Un produit membre d'un groupe de variantes doit partager le même
///   Handle que les autres membres, pour que Loyverse les regroupe en un
///   seul article à plusieurs variantes plutôt que de créer un article par
///   ligne. Le slug est dérivé du nom du produit (identique entre membres
///   d'un même groupe), suivi d'un court suffixe dérivé du groupId pour
///   distinguer deux groupes portant un nom similaire, par exemple
///   "rouge-a-levres-mat-a1b2c3".
String generateHandle(Product product) {
  final groupId = product.groupId;
  if (groupId == null || groupId.isEmpty) return '';

  final slug = _slugify(product.name);
  final suffix = _shortSuffix(groupId);
  return slug.isEmpty ? suffix : '$slug-$suffix';
}

/// Minuscules, accents supprimés, tout ce qui n'est pas alphanumérique
/// remplacé par un tiret (tirets superflus ou en bordure retirés).
String _slugify(String input) {
  const accented = 'àâäáãåèéêëìíîïòóôöõùúûüçñÀÂÄÁÃÅÈÉÊËÌÍÎÏÒÓÔÖÕÙÚÛÜÇÑ';
  const plain = 'aaaaaaeeeeiiiiooooouuuucnAAAAAAEEEEIIIIOOOOOUUUUCN';

  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final index = accented.indexOf(char);
    buffer.write(index == -1 ? char : plain[index]);
  }

  return buffer
      .toString()
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Court suffixe stable dérivé de [groupId] (déjà un UUID, donc composé
/// pour l'essentiel de caractères hexadécimaux) : les 6 premiers caractères
/// alphanumériques, en minuscules.
String _shortSuffix(String groupId) {
  final cleaned = groupId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  if (cleaned.isEmpty) return 'grp';
  return cleaned.length <= 6 ? cleaned : cleaned.substring(0, 6);
}
