import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../product_entry/product_entry_screen.dart';

/// Écran listant les produits enregistrés, avec recherche, édition,
/// duplication et suppression.
///
/// Apparence d'après la maquette Stitch "Liste des produits" : en-tête avec
/// compteur "X refs", barre de recherche, cartes blanches (vignette, nom,
/// prix FCFA, quantité, actions) et bouton flottant "Ajouter". Les éléments
/// de la maquette sans équivalent dans l'app ont été écartés : sous-titre
/// "Boutique Catalog · Principal", menu "...", scan depuis la recherche,
/// puces de filtre, point décoratif, vignettes colorées par catégorie.
///
/// La recherche filtre en temps réel le flux réactif par nom OU SKU
/// (partiel, insensible à la casse). Avec [onlyImportedToComplete], la liste
/// se restreint aux fiches importées (Word) dont SKU, code-barres et photo
/// sont encore vides : c'est la vue ouverte par le lien "Compléter les
/// fiches" de l'accueil. Une fiche quitte cette liste dès qu'un de ces champs
/// est renseigné.
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({
    super.key,
    required this.database,
    this.onlyImportedToComplete = false,
  });

  final AppDatabase database;
  final bool onlyImportedToComplete;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchController = TextEditingController();

  /// Flux des produits, créé une seule fois : le recréer à chaque `build`
  /// (donc à chaque frappe dans la recherche) ferait ré-abonner le
  /// StreamBuilder et repasser par l'état de chargement.
  late final Stream<List<Product>> _products = widget.onlyImportedToComplete
      ? widget.database.watchImportedProductsToComplete()
      : widget.database.watchAllProducts();

  /// Texte de recherche normalisé (minuscules, sans espaces de bord).
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  /// Produits dont le nom ou le SKU contient [_query] ; tous si vide.
  List<Product> _filter(List<Product> products) {
    if (_query.isEmpty) return products;
    return [
      for (final product in products)
        if (product.name.toLowerCase().contains(_query) ||
            (product.sku ?? '').toLowerCase().contains(_query))
          product,
    ];
  }

  /// Duplique [product] en tant que nouvelle variante du même article
  /// Loyverse : les deux produits partagent désormais le même `groupId`
  /// (généré s'il n'existait pas encore), afin d'être regroupés en un seul
  /// article à plusieurs variantes à l'export CSV et au push API.
  ///
  /// Le nom, la catégorie, la description, le coût et le prix sont des
  /// "attributs d'article" chez Loyverse : ils doivent rester identiques
  /// entre les membres d'un même groupe, donc sont copiés tels quels. Le
  /// SKU, le code-barres et la valeur d'option sont en revanche propres à
  /// chaque variante : ils sont vidés pour forcer une saisie distincte.
  ///
  /// Le produit obtenu partage un `groupId` avec l'original : c'est ce qui
  /// permet à la liste de l'afficher regroupé et étiqueté "Variante" (voir
  /// [_clusterByGroup]) plutôt que comme une fiche identique et ambiguë.
  Future<void> _duplicate(Product product) async {
    final database = widget.database;
    final now = DateTime.now();
    final groupId = product.groupId ?? const Uuid().v4();

    if (product.groupId == null) {
      await database.setGroupId(id: product.id, groupId: groupId);
    }

    final copy = ProductsCompanion(
      name: Value(product.name),
      category: Value(product.category),
      description: Value(product.description),
      costPrice: Value(product.costPrice),
      sellPrice: Value(product.sellPrice),
      quantity: Value(product.quantity),
      photoPath: Value(product.photoPath),
      optionName: Value(product.optionName),
      groupId: Value(groupId),
      // sku, barcode et optionValue restent absents (donc vides) : ce sont
      // les attributs propres à cette variante.
      createdAt: Value(now),
      updatedAt: Value(now),
      syncedToLoyverse: const Value(false),
    );
    await database.insertProduct(copy);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Variante de "${product.name}" créée : renseignez son SKU, '
            'code-barres et valeur d\'option.',
          ),
        ),
      );
    }
  }

  Future<bool> _confirmDelete(Product product) {
    return confirmDeleteProduct(context, productName: product.name);
  }

  /// Regroupe les produits *consécutifs* (dans l'ordre déjà trié par nom du
  /// flux) qui partagent un même `groupId` non nul : les variantes d'un même
  /// article ont le même nom par construction, donc sont déjà adjacentes une
  /// fois triées. Ce regroupement ne fait que les rassembler visuellement,
  /// sans changer l'ordre d'affichage (même logique que sur l'écran
  /// "Vérifier et exporter").
  List<List<Product>> _clusterByGroup(List<Product> products) {
    final clusters = <List<Product>>[];
    for (final product in products) {
      final groupId = product.groupId;
      final previous = clusters.isEmpty ? null : clusters.last;
      if (groupId != null &&
          previous != null &&
          previous.first.groupId == groupId) {
        previous.add(product);
      } else {
        clusters.add([product]);
      }
    }
    return clusters;
  }

  void _openEntry({Product? product}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ProductEntryScreen(
          database: widget.database,
          existingProduct: product,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.onlyImportedToComplete;
    return Scaffold(
      backgroundColor: AppPalette.listBackground,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Product>>(
          stream: _products,
          builder: (context, snapshot) {
            final products = snapshot.data;
            final visible = products == null ? null : _filter(products);

            return Column(
              children: [
                _Header(
                  title: filtered
                      ? 'Fiches importées à compléter'
                      : 'Liste des produits',
                  count: products?.length,
                  searchController: _searchController,
                  onQueryChanged: _onQueryChanged,
                ),
                Expanded(
                  child: visible == null
                      ? const Center(child: CircularProgressIndicator())
                      : _buildList(products!, visible),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(999)),
          boxShadow: AppPalette.floatingShadow,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _openEntry(),
          elevation: 0,
          backgroundColor: AppPalette.brand600,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          icon: const Icon(Icons.add),
          label: const Text(
            'Ajouter',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Product> all, List<Product> visible) {
    if (all.isEmpty) {
      return _EmptyState(
        icon: widget.onlyImportedToComplete
            ? Icons.task_alt
            : Icons.inventory_2_outlined,
        message: widget.onlyImportedToComplete
            ? 'Toutes les fiches importées sont complétées.'
            : 'Aucun produit pour le moment.\nAjoutez votre premier produit !',
      );
    }
    if (visible.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off,
        message: 'Aucun produit ne correspond à « ${_searchController.text.trim()} ».',
      );
    }

    // Une colonne en mobile (identique à la maquette), deux ou trois sur
    // grand écran. Les rangées restent construites à la demande par la
    // ListView : une longue liste reste virtualisée.
    final columns = context.cardColumns;
    final rows = chunkIntoRows(_clusterByGroup(visible), columns);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final row = rows[index];
            if (columns == 1) return _card(row.single);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: 12),
                  // Les dernières rangées peuvent être incomplètes : la
                  // place vide garde l'alignement des colonnes.
                  Expanded(
                    child: column < row.length
                        ? _card(row[column])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Carte d'un produit autonome ou d'un groupe de variantes.
  Widget _card(List<Product> cluster) {
    if (cluster.length == 1) {
      return _StandaloneProductCard(
        product: cluster.single,
        database: widget.database,
        onTap: () => _openEntry(product: cluster.single),
        onDuplicate: () => _duplicate(cluster.single),
        onConfirmDelete: () => _confirmDelete(cluster.single),
      );
    }
    return _ProductGroupCard(
      products: cluster,
      database: widget.database,
      onTap: (product) => _openEntry(product: product),
      onDuplicate: _duplicate,
      onConfirmDelete: _confirmDelete,
    );
  }
}

/// En-tête : bouton retour (uniquement si l'écran a été poussé, pas sous
/// l'onglet Produits), titre centré avec compteur "X refs", puis barre de
/// recherche.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.count,
    required this.searchController,
    required this.onQueryChanged,
  });

  final String title;
  final int? count;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      color: AppPalette.listBackground.withValues(alpha: 0.9),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Center(
        child: ConstrainedBox(
          // Aligné sur la largeur de la liste en dessous.
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: Column(
            children: [
              Row(
                children: [
                  if (canPop)
                    _RoundButton(
                      icon: Icons.arrow_back_ios_new,
                      tooltip: 'Retour',
                      onTap: () => Navigator.of(context).maybePop(),
                    )
                  else
                    const SizedBox(width: 40),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.slate900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (count != null) ...[
                          const SizedBox(width: 8),
                          _CountChip(count: count!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 12),
              _SearchField(
                controller: searchController,
                onChanged: onQueryChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille "X refs" à côté du titre.
class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.brand100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count ref${count > 1 ? 's' : ''}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppPalette.brand700,
        ),
      ),
    );
  }
}

/// Barre de recherche : loupe à gauche, croix d'effacement à droite dès
/// qu'un texte est saisi.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14, color: AppPalette.slate800),
            decoration: InputDecoration(
              hintText: 'Rechercher un produit ou un SKU...',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppPalette.slate400,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AppPalette.slate400,
              ),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.close, size: 18),
                      color: AppPalette.slate400,
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
              filled: true,
              fillColor: AppPalette.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              enabledBorder: border(AppPalette.cardBorder),
              focusedBorder: border(AppPalette.brand500, 1.5),
            ),
          );
        },
      ),
    );
  }
}

/// Bouton rond blanc (retour).
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppPalette.surface,
        shape: const CircleBorder(side: BorderSide(color: AppPalette.cardBorder)),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 18, color: AppPalette.slate600),
          ),
        ),
      ),
    );
  }
}

/// État vide : icône et message centrés.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppPalette.brand300),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppPalette.slate500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte blanche d'un produit autonome (ne fait partie d'aucun groupe de
/// variantes), supprimable par glissement.
class _StandaloneProductCard extends StatelessWidget {
  const _StandaloneProductCard({
    required this.product,
    required this.database,
    required this.onTap,
    required this.onDuplicate,
    required this.onConfirmDelete,
  });

  final Product product;
  final AppDatabase database;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final Future<bool> Function() onConfirmDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(product.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onConfirmDelete(),
      onDismissed: (_) => database.deleteProduct(product.id),
      background: const _DeleteBackground(),
      child: _CardSurface(
        borderColor: AppPalette.cardBorder,
        child: _ProductTile(
          product: product,
          isVariant: false,
          database: database,
          onTap: onTap,
          onDuplicate: onDuplicate,
          onConfirmDelete: onConfirmDelete,
        ),
      ),
    );
  }
}

/// Carte regroupant visuellement tous les membres d'un même groupe de
/// variantes (issu d'une duplication, voir `_duplicate`), avec un en-tête
/// "N variantes liées" : sans ce regroupement, deux fiches issues d'une
/// duplication (même nom, même prix, même quantité) seraient indiscernables
/// l'une de l'autre dans la liste.
class _ProductGroupCard extends StatelessWidget {
  const _ProductGroupCard({
    required this.products,
    required this.database,
    required this.onTap,
    required this.onDuplicate,
    required this.onConfirmDelete,
  });

  final List<Product> products;
  final AppDatabase database;
  final void Function(Product product) onTap;
  final void Function(Product product) onDuplicate;
  final Future<bool> Function(Product product) onConfirmDelete;

  @override
  Widget build(BuildContext context) {
    return _CardSurface(
      borderColor: AppPalette.brand300,
      borderWidth: 1.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                const Icon(Icons.link, size: 16, color: AppPalette.brand600),
                const SizedBox(width: 6),
                Text(
                  '${products.length} variantes liées',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.brand600,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < products.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppPalette.cardBorder),
            Dismissible(
              key: ValueKey(products[i].id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => onConfirmDelete(products[i]),
              onDismissed: (_) => database.deleteProduct(products[i].id),
              background: const _DeleteBackground(),
              child: _ProductTile(
                product: products[i],
                isVariant: true,
                database: database,
                onTap: () => onTap(products[i]),
                onDuplicate: () => onDuplicate(products[i]),
                onConfirmDelete: () => onConfirmDelete(products[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Surface blanche arrondie commune aux cartes de la liste.
class _CardSurface extends StatelessWidget {
  const _CardSurface({
    required this.child,
    required this.borderColor,
    this.borderWidth = 1,
  });

  final Widget child;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F5E4B8B),
            offset: Offset(0, 4),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Fond rouge affiché derrière une fiche en cours de suppression par
/// glissement.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppPalette.rose100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline, color: AppPalette.rose700),
    );
  }
}

/// Ligne d'un produit : vignette, nom (avec badge "Variante" le cas échéant),
/// prix et quantité, actions dupliquer/supprimer. Réutilisée aussi bien pour
/// un produit autonome que pour chaque membre d'un groupe.
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.isVariant,
    required this.database,
    required this.onTap,
    required this.onDuplicate,
    required this.onConfirmDelete,
  });

  final Product product;
  final bool isVariant;
  final AppDatabase database;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final Future<bool> Function() onConfirmDelete;

  @override
  Widget build(BuildContext context) {
    final optionValue = product.optionValue?.trim();
    // Une variante fraîchement dupliquée n'a pas encore de valeur d'option
    // (voir `_duplicate` : c'est volontaire, à saisir manuellement) : on le
    // signale au lieu de laisser un badge "Variante" nu qui n'aiderait pas à
    // savoir ce qu'il reste à compléter.
    final variantLabel = isVariant
        ? (optionValue != null && optionValue.isNotEmpty
              ? optionValue
              : 'Variante à compléter')
        : null;

    // SKU et catégorie : ce sont les deux champs qu'on ne pouvait voir
    // qu'en ouvrant la fiche, alors que le SKU est la clé de l'export CSV
    // et Loyverse. Les deux sont facultatifs en base : on n'affiche la
    // ligne que si au moins l'un des deux est renseigné, plutôt que de
    // réserver une hauteur qui resterait vide sur un catalogue neuf.
    final meta = [
      for (final field in [product.sku, product.category])
        if (field != null && field.trim().isNotEmpty) field.trim(),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _ProductThumbnail(photoPath: product.photoPath),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.slate900,
                            ),
                          ),
                        ),
                        if (variantLabel != null) ...[
                          const SizedBox(width: 6),
                          _VariantBadge(label: variantLabel),
                        ],
                      ],
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta.join(' · '),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppPalette.slate500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            formatPrice(product.sellPrice),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.brand600,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '·',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppPalette.slate300,
                            ),
                          ),
                        ),
                        _QuantityChip(quantity: product.quantity),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.copy_outlined,
                tooltip: 'Dupliquer',
                background: AppPalette.slate50,
                border: AppPalette.slate100,
                foreground: AppPalette.slate500,
                onPressed: onDuplicate,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: Icons.delete_outline,
                tooltip: 'Supprimer',
                background: AppPalette.rose50.withValues(alpha: 0.7),
                border: AppPalette.rose100,
                foreground: AppPalette.rose500,
                onPressed: () async {
                  if (await onConfirmDelete()) {
                    await database.deleteProduct(product.id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille "Qté N" : verte dès qu'il reste du stock, rose à zéro. Aucun
/// seuil de "stock faible" n'existe dans l'app.
class _QuantityChip extends StatelessWidget {
  const _QuantityChip({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    final inStock = quantity > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: inStock ? AppPalette.emerald50 : AppPalette.rose50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Qté $quantity',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: inStock ? AppPalette.emerald700 : AppPalette.rose700,
        ),
      ),
    );
  }
}

/// Petit bouton rond d'action (dupliquer / supprimer).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.border,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color border;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size(32, 32),
        maximumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: CircleBorder(side: BorderSide(color: border)),
      ),
    );
  }
}

/// Petit badge coloré identifiant une fiche comme variante d'un groupe
/// (plutôt qu'un doublon accidentel), avec sa valeur d'option si déjà
/// renseignée, ou une mention "à compléter" sinon.
class _VariantBadge extends StatelessWidget {
  const _VariantBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isIncomplete = label == 'Variante à compléter';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isIncomplete ? AppPalette.rose100 : AppPalette.brand100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isIncomplete ? AppPalette.rose700 : AppPalette.brand700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Vignette de la photo produit, ou emplacement gris générique unique
/// (icône image) si aucune photo n'a été ajoutée ou si le fichier n'est
/// plus accessible.
class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.photoPath});

  final String? photoPath;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (path == null || path.isEmpty) return const _ThumbnailPlaceholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(path),
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const _ThumbnailPlaceholder(),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _ProductThumbnail._size,
      height: _ProductThumbnail._size,
      decoration: BoxDecoration(
        color: AppPalette.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.slate200.withValues(alpha: 0.6)),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: AppPalette.slate400,
        size: 24,
      ),
    );
  }
}
