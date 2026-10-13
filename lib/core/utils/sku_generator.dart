import 'package:uuid/uuid.dart';

const _uuidGenerator = Uuid();

/// Génère un SKU sûr, pour ne plus jamais bloquer la saisie ni l'export sur
/// un SKU manquant.
///
/// Format : `SKU-` suivi des 8 premiers caractères hexadécimaux d'un UUID
/// v4 (le premier groupe du format `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`,
/// donc déjà exempt de tiret), mis en majuscules — par exemple
/// `SKU-A1B2C3D4`. Le résultat est purement alphanumérique à l'exception du
/// tiret de préfixe, donc sans accent ni caractère spécial, et reste
/// compatible avec le format d'import CSV Loyverse.
///
/// Le risque de collision entre deux appels (32 bits de hasard) est
/// négligeable pour la taille d'un catalogue boutique ; ce n'est pas un
/// identifiant cryptographique.
String generateSafeSku() {
  final shortCode = _uuidGenerator.v4().substring(0, 8).toUpperCase();
  return 'SKU-$shortCode';
}
