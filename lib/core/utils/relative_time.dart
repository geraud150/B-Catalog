/// Met en mots l'ancienneté d'un horodatage, pour l'activité récente de
/// l'accueil.
///
/// Le format reste volontairement court (une ligne de métadonnée sous un nom
/// de produit) et bascule sur une date absolue au-delà d'une semaine, où
/// « il y a 23 j » n'apprend plus rien d'utile.
///
/// [now] n'est là que pour les tests : en production elle vaut l'heure
/// courante.
String formatRelativeTime(DateTime timestamp, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final elapsed = reference.difference(timestamp);

  // Horodatage dans le futur (horloge système reculée, fiche importée avec
  // une date erronée) : le traiter comme « à l'instant » plutôt que
  // d'afficher « il y a -3 min ».
  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'à l\'instant';
  if (elapsed.inHours < 1) return 'il y a ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'il y a ${elapsed.inHours} h';
  if (elapsed.inDays == 1) return 'hier';
  if (elapsed.inDays < 7) return 'il y a ${elapsed.inDays} j';

  final day = timestamp.day.toString().padLeft(2, '0');
  final month = timestamp.month.toString().padLeft(2, '0');
  return 'le $day/$month/${timestamp.year}';
}
