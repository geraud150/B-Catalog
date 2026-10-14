import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_palette.dart';
import '../review/review_screen.dart';
import '../sync/catalog_sync_screen.dart';
import 'import_preview_screen.dart';

/// Onglet "Import" du shell, d'après la maquette Stitch "Import & export" :
/// deux cartes d'action vers les deux flux existants, qui restent distincts
/// car l'un est ponctuel (lecture d'un .docx, aperçu, enregistrement) et
/// l'autre est un écran de travail (sélection, vérification, export CSV /
/// envoi Loyverse).
///
/// Les éléments de la maquette sans équivalent dans l'app ont été écartés :
/// sur-titre "GESTION DE FLUX", icône de rafraîchissement, sous-titre
/// générique, bandeau "Passerelle Loyverse · En ligne" (aucun contrôle de
/// connexion n'existe), badge "10 en attente" (redondant avec les compteurs
/// de l'accueil et du récapitulatif) et section "Ressources & modèles" (ni
/// modèle Word téléchargeable ni historique des imports ne sont
/// implémentés).
///
/// Les écrans cibles ([ImportPreviewScreen], [ReviewScreen]) sont poussés
/// par-dessus le shell.
class ImportHubScreen extends StatelessWidget {
  const ImportHubScreen({super.key, required this.database});

  final AppDatabase database;

  Future<void> _importDocument(BuildContext context) async {
    final importedCount = await ImportPreviewScreen.pickAndImport(
      context,
      database,
    );
    if (importedCount == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$importedCount produit${importedCount > 1 ? 's' : ''} '
          'importé${importedCount > 1 ? 's' : ''}',
        ),
      ),
    );
  }

  void _openReview(BuildContext context) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => ReviewScreen(database: database)));
  }

  void _openCatalogSync(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => CatalogSyncScreen(database: database)),
    );
  }

  Widget _importCard(BuildContext context) => _HubCard(
    icon: Icons.cloud_upload_outlined,
    title: 'Importer un document Word',
    tag: 'DOCX',
    subtitle:
        'Lire le tableau de produits d\'un fichier .docx, '
        'vérifier l\'aperçu puis l\'ajouter au catalogue.',
    onTap: () => _importDocument(context),
  );

  Widget _reviewCard(BuildContext context) => _HubCard(
    icon: Icons.check_circle_outline,
    title: 'Vérifier et exporter',
    subtitle:
        'Contrôler la complétude des fiches, exporter en CSV '
        'ou envoyer vers Loyverse.',
    onTap: () => _openReview(context),
  );

  Widget _syncCard(BuildContext context) => _HubCard(
    icon: Icons.sync,
    title: 'Synchroniser le catalogue',
    subtitle: 'Partager les modifications avec les autres appareils.',
    onTap: () => _openCatalogSync(context),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.formBackground,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                const Text(
                  'Import & export',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.slate900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 20),
                _syncCard(context),
                const SizedBox(height: 16),
                // Cartes empilées en mobile, côte à côte sur grand écran.
                if (context.isWideLayout)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _importCard(context)),
                        const SizedBox(width: 16),
                        Expanded(child: _reviewCard(context)),
                      ],
                    ),
                  )
                else ...[
                  _importCard(context),
                  const SizedBox(height: 16),
                  _reviewCard(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte blanche cliquable : vignette d'icône, titre (avec étiquette
/// facultative), description et chevron.
class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tag,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: radius,
        border: Border.all(color: AppPalette.purple100.withValues(alpha: 0.6)),
        boxShadow: AppPalette.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppPalette.brand100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: AppPalette.brand700, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.slate900,
                            ),
                          ),
                          if (tag != null) _Tag(label: tag!),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    color: AppPalette.brand50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppPalette.brand600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Étiquette de format ("DOCX").
class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppPalette.brand800,
        ),
      ),
    );
  }
}
