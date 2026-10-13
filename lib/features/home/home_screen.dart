import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_version.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/relative_time.dart';
import '../import/import_preview_screen.dart';
import '../product_entry/product_entry_screen.dart';
import '../product_list/product_list_screen.dart';
import '../review/review_screen.dart';
import 'home_stats.dart';

/// Écran d'accueil (onglet "Accueil" du shell), d'après la maquette Stitch
/// "Tableau de bord" : bannière "fiches importées à compléter", grille des
/// actions principales et indicateurs du catalogue.
///
/// Toutes les valeurs affichées sont dérivées du flux `watchAllProducts()`
/// (voir [HomeStats]) : elles se rafraîchissent d'elles-mêmes au retour d'un
/// écran de saisie ou après un import, sans recomptage manuel.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.database, this.onShowProducts});

  final AppDatabase database;

  /// Appelé par la carte "Liste des produits" : le shell y bascule vers
  /// l'onglet Produits. À défaut (écran utilisé hors shell), la liste est
  /// poussée comme un écran classique.
  final VoidCallback? onShowProducts;

  /// Largeur maximale du contenu en mise en page mobile (celle de la
  /// maquette). Sur grand écran, le contenu s'élargit avec le nombre de
  /// colonnes de cartes et les actions passent sur une seule rangée : voir
  /// [maxWidthFor].
  static const contentMaxWidth = AppBreakpoints.mobileContentMaxWidth;

  static double maxWidthFor(BuildContext context) => context.contentMaxWidth;

  Future<void> _push(BuildContext context, Widget screen) {
    return Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _showProducts(BuildContext context) {
    final onShowProducts = this.onShowProducts;
    if (onShowProducts != null) {
      onShowProducts();
    } else {
      _push(context, ProductListScreen(database: database));
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Product>>(
          stream: database.watchAllProducts(),
          builder: (context, snapshot) {
            final stats = snapshot.hasData
                ? HomeStats.fromProducts(snapshot.data!)
                : HomeStats.empty;

            return Column(
              children: [
                const _Header(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxWidthFor(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (stats.importedToCompleteCount > 0) ...[
                              _ImportedToCompleteBanner(
                                stats: stats,
                                onComplete: () => _push(
                                  context,
                                  ProductListScreen(
                                    database: database,
                                    onlyImportedToComplete: true,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            _QuickActions(
                              productCount: stats.totalProducts,
                              onAddProduct: () => _push(
                                context,
                                ProductEntryScreen(database: database),
                              ),
                              onShowProducts: () => _showProducts(context),
                              onReview: () => _push(
                                context,
                                ReviewScreen(database: database),
                              ),
                              onImport: () => _importDocument(context),
                            ),
                            const SizedBox(height: 24),
                            _MetricsCard(stats: stats),
                            // L'activité récente comble la moitié basse de
                            // la fenêtre, vide en mise en page large. En
                            // mobile la colonne est déjà pleine et l'onglet
                            // Produits est à un geste : l'ajouter ne ferait
                            // qu'allonger le défilement.
                            if (context.isWideLayout) ...[
                              const SizedBox(height: 24),
                              _RecentActivity(
                                database: database,
                                onOpenProduct: (product) => _push(
                                  context,
                                  ProductEntryScreen(
                                    database: database,
                                    existingProduct: product,
                                  ),
                                ),
                              ),
                            ],
                            // En mise en page large, la mention vit au bas
                            // du rail de navigation : l'afficher ici aussi
                            // la ferait apparaître deux fois à l'écran.
                            if (!context.isWideLayout) ...[
                              const SizedBox(height: 28),
                              const AppVersionLabel(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// En-tête : logo, nom de l'app et sous-titre. La maquette y ajoutait un
/// badge "PRO", une cloche de notifications et un avatar : retirés, l'app
/// étant mono-utilisatrice, sans abonnement ni notifications.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppPalette.background.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: AppPalette.purple100.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: HomeScreen.maxWidthFor(context)),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [AppPalette.brand700, AppPalette.brand500],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.brand700.withValues(alpha: 0.2),
                      offset: const Offset(0, 4),
                      blurRadius: 6,
                      spreadRadius: -1,
                    ),
                  ],
                ),
                // Pictogramme du lockup "Boutique Catalog / PRO ERP" de la
                // maquette Stitch : le glyphe Material `store`, blanc sur le
                // carré arrondi violet. Le texte "PRO ERP" reste hors
                // périmètre, comme le badge "PRO" écarté auparavant.
                child: const Icon(Icons.store, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'B-Catalog',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.slate900,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Bienvenue sur votre gestionnaire',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppPalette.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bannière "Action requise" : nombre de fiches importées (Word) qu'il reste
/// à compléter, avancement, et lien vers la liste filtrée sur ces fiches.
class _ImportedToCompleteBanner extends StatelessWidget {
  const _ImportedToCompleteBanner({
    required this.stats,
    required this.onComplete,
  });

  final HomeStats stats;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final remaining = stats.importedToCompleteCount;
    final title = remaining == 1
        ? '1 fiche importée reste à compléter'
        : '$remaining fiches importées restent à compléter';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.rose100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppPalette.rose200.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Halo décoratif en bas à droite.
            Positioned(
              right: -24,
              bottom: -24,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.rose200.withValues(alpha: 0.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: AppPalette.rose700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.rose200.withValues(
                                  alpha: 0.7,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Action requise',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppPalette.rose700,
                                ),
                              ),
                            ),
                            Text(
                              '$remaining / ${stats.importedCount} fiches',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppPalette.rose700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.slate900,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SKU, code-barres et photo restent à renseigner '
                          'avant l\'export.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppPalette.slate600,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: stats.importedProgress,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.8,
                            ),
                            color: AppPalette.rose500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _BannerLink(
                            label: 'Compléter les fiches',
                            onTap: onComplete,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton-lien blanc de la bannière ("Compléter les fiches ›").
class _BannerLink extends StatelessWidget {
  const _BannerLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.rose700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppPalette.rose700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section "Actions principales" : grille 2×2 des quatre actions de l'app.
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.productCount,
    required this.onAddProduct,
    required this.onShowProducts,
    required this.onReview,
    required this.onImport,
  });

  final int productCount;
  final VoidCallback onAddProduct;
  final VoidCallback onShowProducts;
  final VoidCallback onReview;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    const gap = 14.0;
    final cards = _cards();
    final columns = context.isWideLayout ? cards.length : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Actions principales',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.slate800,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Raccourcis',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppPalette.brand600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Deux colonnes en mobile (grille 2×2 de la maquette), les quatre
        // actions sur une seule rangée sur grand écran.
        for (final (rowIndex, row) in chunkIntoRows(cards, columns).indexed) ...[
          if (rowIndex > 0) const SizedBox(height: gap),
          _CardRow(
            children: [
              for (final (cardIndex, card) in row.indexed) ...[
                if (cardIndex > 0) const SizedBox(width: gap),
                Expanded(child: card),
              ],
            ],
          ),
        ],
      ],
    );
  }

  /// Les quatre cartes d'action, dans l'ordre d'affichage.
  List<Widget> _cards() => [
    _ActionCard.primary(
      icon: Icons.add,
      trailing: const _Chip(
        label: 'NOUVEAU',
        background: Color(0x33FFFFFF),
        foreground: AppPalette.purple100,
      ),
      title: 'Ajouter un produit',
      subtitle: 'Créer une fiche vierge',
      onTap: onAddProduct,
    ),
    _ActionCard(
      icon: Icons.menu,
      iconBackground: AppPalette.brand100,
      iconColor: AppPalette.brand700,
      trailing: Text(
        '$productCount réf${productCount > 1 ? 's' : ''}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppPalette.slate400,
        ),
      ),
      title: 'Liste des produits',
      subtitle: 'Catalogue complet',
      onTap: onShowProducts,
    ),
    _ActionCard(
      icon: Icons.check_circle_outline,
      iconBackground: AppPalette.purple50,
      iconColor: AppPalette.brand600,
      iconBorder: AppPalette.purple100,
      trailing: const Icon(
        Icons.arrow_forward,
        size: 16,
        color: AppPalette.slate300,
      ),
      title: 'Vérifier & Exporter',
      subtitle: 'CSV ou Loyverse',
      onTap: onReview,
    ),
    _ActionCard(
      icon: Icons.cloud_upload_outlined,
      iconBackground: AppPalette.purple100.withValues(alpha: 0.7),
      iconColor: AppPalette.brand700,
      title: 'Importer un document',
      subtitle: 'Catalogue Word (.docx)',
      onTap: onImport,
    ),
  ];
}

/// Rangée de deux cartes de même hauteur : [IntrinsicHeight] borne la
/// hauteur (le parent défile, donc ne la borne pas) pour que `stretch`
/// aligne les deux cartes sur la plus haute.
class _CardRow extends StatelessWidget {
  const _CardRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Carte d'action : vignette d'icône + élément de droite en haut, titre et
/// sous-titre en bas. La variante [_ActionCard.primary] (dégradé violet)
/// met en avant l'ajout d'un produit.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconBackground = AppPalette.brand100,
    this.iconColor = AppPalette.brand700,
    this.iconBorder,
    this.trailing,
  }) : isPrimary = false;

  const _ActionCard.primary({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  }) : isPrimary = true,
       iconBackground = const Color(0x33FFFFFF),
       iconColor = Colors.white,
       iconBorder = null;

  final bool isPrimary;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final Color? iconBorder;
  final Widget? trailing;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const _minHeight = 145.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final decoration = isPrimary
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppPalette.brand700, AppPalette.brand800],
            ),
            borderRadius: radius,
            boxShadow: AppPalette.primaryShadow,
          )
        : BoxDecoration(
            color: AppPalette.surface,
            borderRadius: radius,
            border: Border.all(
              color: AppPalette.purple100.withValues(alpha: 0.8),
            ),
            boxShadow: AppPalette.softShadow,
          );

    return Container(
      constraints: const BoxConstraints(minHeight: _minHeight),
      decoration: decoration,
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Stack(
              children: [
                if (isPrimary)
                  // Disque translucide décoratif en haut à droite.
                  Positioned(
                    right: -16,
                    top: -16,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: iconBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: iconBorder == null
                                  ? null
                                  : Border.all(color: iconBorder!),
                            ),
                            child: Icon(icon, size: 20, color: iconColor),
                          ),
                          ?trailing,
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isPrimary
                              ? Colors.white
                              : AppPalette.slate900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isPrimary
                              ? AppPalette.purple200
                              : AppPalette.slate500,
                        ),
                      ),
                    ],
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

/// Petite pastille arrondie ("NOUVEAU").
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: foreground,
        ),
      ),
    );
  }
}

/// Activité récente, d'après la maquette Stitch "Tableau de Bord - Logiciel
/// Desktop" : les derniers produits créés ou modifiés, du plus récent au plus
/// ancien.
///
/// La maquette en faisait un tableau (prix, stock, statut POS, actions) avec
/// un filtre par rayon et un lien "Voir tout" ; seuls le nom, la vignette et
/// l'ancienneté sont repris ici, le reste étant hors du périmètre demandé.
///
/// Le flux est distinct de celui des indicateurs : il est trié et limité en
/// SQL, pour ne pas relire tout le catalogue à chaque changement.
class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.database, required this.onOpenProduct});

  final AppDatabase database;
  final ValueChanged<Product> onOpenProduct;

  /// Haut de la fourchette demandée : sur un écran large, huit lignes
  /// occupent l'espace disponible sans imposer de défilement.
  static const _limit = 8;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: database.watchRecentlyTouchedProducts(limit: _limit),
      builder: (context, snapshot) {
        final products = snapshot.data;
        // Tant que la première valeur n'est pas arrivée, ne rien réserver :
        // un bloc vide qui se remplit ensuite ferait sauter la mise en page.
        if (products == null || products.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.purple100),
            boxShadow: AppPalette.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activité récente',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.slate900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Derniers produits créés ou modifiés',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppPalette.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              for (final product in products)
                _RecentActivityRow(
                  product: product,
                  isFirst: product == products.first,
                  onTap: () => onOpenProduct(product),
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

/// Une ligne d'activité : vignette, nom, ancienneté. Toute la ligne ouvre la
/// fiche en édition.
class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({
    required this.product,
    required this.isFirst,
    required this.onTap,
  });

  final Product product;
  final bool isFirst;
  final VoidCallback onTap;

  static const _thumbnailSize = 36.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              // Filet entre les lignes seulement : au-dessus de la première,
              // il doublerait la séparation avec l'en-tête.
              top: isFirst
                  ? BorderSide.none
                  : BorderSide(
                      color: AppPalette.purple100.withValues(alpha: 0.6),
                    ),
            ),
          ),
          child: Row(
            children: [
              _RecentActivityThumbnail(
                photoPath: product.photoPath,
                size: _thumbnailSize,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  product.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.slate900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatRelativeTime(product.updatedAt),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppPalette.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vignette d'une ligne d'activité : la photo du produit si elle existe et
/// reste lisible, sinon la même pastille neutre que la liste des produits.
class _RecentActivityThumbnail extends StatelessWidget {
  const _RecentActivityThumbnail({
    required this.photoPath,
    required this.size,
  });

  final String? photoPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (path != null && path.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Une photo supprimée du disque depuis la saisie ne doit pas
          // casser l'accueil : on retombe sur la pastille.
          errorBuilder: (context, error, stackTrace) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppPalette.slate50,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppPalette.slate100),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 17,
        color: AppPalette.slate300,
      ),
    );
  }
}

/// Carte des indicateurs : produits, catégories, complétude, et références
/// déjà synchronisées vers Loyverse. Les quatre valeurs viennent du même flux
/// `watchAllProducts()` et s'affichent telles qu'elles arrivent.
class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.purple100),
        boxShadow: AppPalette.softShadow,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _Metric(value: '${stats.totalProducts}', label: 'Produits'),
            const _MetricDivider(),
            _Metric(value: '${stats.categoryCount}', label: 'Catégories'),
            const _MetricDivider(),
            _Metric(
              value: '${stats.completenessPercent}%',
              label: 'Complétude',
              valueColor: AppPalette.emerald600,
            ),
            const _MetricDivider(),
            _Metric(
              label: 'Loyverse',
              // Deux nombres plutôt qu'un : « 3 » seul ne dit pas s'il reste
              // des fiches à pousser. La couleur porte la distinction, et la
              // légende en dessous nomme les deux chiffres là où il y a la
              // place de l'écrire.
              valueWidget: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${stats.syncedToLoyverseCount}',
                      style: _Metric.valueTextStyle.copyWith(
                        color: AppPalette.emerald600,
                      ),
                    ),
                    TextSpan(
                      text: ' / ',
                      style: _Metric.valueTextStyle.copyWith(
                        color: AppPalette.slate300,
                      ),
                    ),
                    TextSpan(
                      text: '${stats.pendingLoyverseCount}',
                      style: _Metric.valueTextStyle.copyWith(
                        color: AppPalette.brand600,
                      ),
                    ),
                  ],
                ),
              ),
              detail: context.isWideLayout ? 'synchro. / en attente' : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    this.value,
    this.valueColor = AppPalette.brand900,
    this.valueWidget,
    this.detail,
  }) : assert(
         value != null || valueWidget != null,
         'une tuile doit porter soit une valeur texte, soit un widget',
       );

  final String? value;
  final String label;
  final Color valueColor;

  /// Remplace le texte de [value] quand la valeur mêle plusieurs couleurs
  /// (cas de Loyverse). La taille et la graisse restent celles de
  /// [valueTextStyle] pour que les tuiles gardent la même typographie.
  final Widget? valueWidget;

  /// Légende sous le libellé, en mise en page large seulement : elle dit ce
  /// que sont les deux nombres d'une valeur composite.
  final String? detail;

  static const valueTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          valueWidget ??
              Text(value!, style: valueTextStyle.copyWith(color: valueColor)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppPalette.slate500,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 1),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppPalette.slate400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: AppPalette.purple100.withValues(alpha: 0.8),
    );
  }
}
