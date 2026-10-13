import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/price_formatter.dart';
import '../export/csv_export_service.dart';
import '../sync/sync_service.dart';

/// Écran de récapitulatif avant export/synchronisation.
///
/// Permet de sélectionner un sous-ensemble de produits et d'en vérifier la
/// complétude (prix de vente, catégorie et SKU renseignés) avant de préparer
/// l'export CSV ou l'envoi vers Loyverse.
///
/// Apparence d'après la maquette Stitch "Vérifier et exporter" : trois
/// indicateurs (produits / sélectionnés / incomplets), barre "Tout
/// sélectionner" avec filtre "Incomplets", cartes blanches avec case à
/// cocher, motifs d'incomplétude réels et badge de synchronisation, deux
/// boutons d'action fixés en bas. Le menu "..." de la maquette a été écarté.
///
/// Le SKU est en principe toujours renseigné depuis la Phase 11 (génération
/// automatique à la saisie et migration de rattrapage pour les produits
/// existants) : cette vérification reste un filet de sécurité pour un cas
/// imprévu (bug futur, import externe direct en base...), afin de ne jamais
/// laisser passer silencieusement un export avec SKU manquant.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final Set<int> _selectedIds = {};
  final CsvExportService _csvExportService = const CsvExportService();
  late final SyncService _syncService = SyncService(database: widget.database);
  List<Product> _latestProducts = [];
  bool _isSyncing = false;

  /// Flux des produits, créé une seule fois : le recréer à chaque `build`
  /// (donc à chaque coche) ferait ré-abonner le StreamBuilder et repasser
  /// par l'état de chargement.
  late final Stream<List<Product>> _products = widget.database
      .watchAllProducts();

  /// Filtre "Incomplets" : n'affiche que les produits auxquels il manque au
  /// moins un critère (voir [_missingFields]). La sélection est conservée
  /// quand on active ou désactive le filtre.
  bool _showOnlyIncomplete = false;

  bool _isComplete(Product product) => _missingFields(product).isEmpty;

  /// Critères de complétude manquants pour [product], dans l'ordre
  /// d'affichage : ce sont exactement ceux que vérifie l'export.
  static List<String> _missingFields(Product product) => [
    if (product.sellPrice == null) 'Prix non défini',
    if (product.category == null || product.category!.trim().isEmpty)
      'Catégorie non définie',
    if (product.sku == null || product.sku!.trim().isEmpty) 'SKU non défini',
  ];

  /// Regroupe les produits *consécutifs* (dans l'ordre déjà trié par nom du
  /// flux) qui partagent un même `groupId` non nul. Les membres d'un groupe
  /// ayant un nom identique par construction, ils sont déjà adjacents une
  /// fois triés par nom : ce regroupement ne fait que les rassembler
  /// visuellement, sans changer l'ordre d'affichage.
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

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// Coche tous les produits *visibles* (donc seulement les incomplets quand
  /// le filtre est actif), ou les décoche tous s'ils l'étaient déjà. Les
  /// produits masqués par le filtre gardent leur état.
  void _toggleSelectAll(List<Product> visible) {
    setState(() {
      final visibleIds = visible.map((p) => p.id);
      if (_allSelected(visible)) {
        _selectedIds.removeAll(visibleIds);
      } else {
        _selectedIds.addAll(visibleIds);
      }
    });
  }

  /// Carte d'un produit autonome ou d'un groupe de variantes.
  Widget _card(List<Product> cluster) {
    if (cluster.length == 1) {
      final product = cluster.single;
      return _ProductCard(
        product: product,
        selected: _selectedIds.contains(product.id),
        missing: _missingFields(product),
        onChanged: () => _toggleSelection(product.id),
      );
    }
    return _ProductGroupCard(
      products: cluster,
      selectedIds: _selectedIds,
      missingFields: _missingFields,
      onToggle: _toggleSelection,
    );
  }

  bool _allSelected(List<Product> visible) =>
      visible.isNotEmpty && visible.every((p) => _selectedIds.contains(p.id));

  List<Product> get _selectedProducts =>
      _latestProducts.where((p) => _selectedIds.contains(p.id)).toList();

  Future<void> _exportCsv() async {
    final selected = _selectedProducts;
    if (selected.isEmpty) return;

    final missingSku = _csvExportService.productsMissingSku(selected);
    if (missingSku.isNotEmpty) {
      await _showMissingSkuDialog(missingSku);
      return;
    }

    final csvContent = _csvExportService.exportToCsv(selected);
    final result = await _csvExportService.saveCsv(csvContent);
    if (!mounted || !result.isSaved) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_exportMessage(result, selected.length))),
    );
  }

  /// Message de confirmation adapté à l'endroit où le fichier a atterri.
  static String _exportMessage(CsvSaveResult result, int count) {
    return switch (result.status) {
      CsvSaveStatus.savedToDownloads =>
        'Fichier CSV enregistré dans Téléchargements.',
      // Le dossier public n'était pas accessible : autant dire où chercher.
      CsvSaveStatus.savedToAppFolder =>
        'Fichier CSV enregistré dans ${result.path}',
      CsvSaveStatus.saved ||
      CsvSaveStatus.cancelled => '$count produit(s) exporté(s) en CSV',
    };
  }

  Future<void> _showMissingSkuDialog(List<Product> missing) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SKU manquant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Loyverse exige un SKU unique pour chaque article. '
              'Renseignez le SKU des produits suivants avant de les exporter :',
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final product in missing) Text('• ${product.name}'),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendToLoyverse() async {
    final selected = _selectedProducts;
    if (selected.isEmpty || _isSyncing) return;

    setState(() => _isSyncing = true);

    final progress = ValueNotifier<(int, int)>((0, selected.length));
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _SyncProgressDialog(progress: progress),
      ),
    );

    final results = await _syncService.syncProducts(
      selected,
      onProgress: (done, total) => progress.value = (done, total),
    );

    progress.dispose();
    if (!mounted) return;
    Navigator.of(context).pop(); // Ferme la boîte de progression.
    setState(() => _isSyncing = false);

    await _showSyncSummaryDialog(results);
  }

  Future<void> _showSyncSummaryDialog(List<SyncResult> results) {
    final successes = results.where((r) => r.success).toList();
    final failures = results.where((r) => !r.success).toList();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Synchronisation Loyverse'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${successes.length}/${results.length} produit(s) synchronisé(s) avec succès.',
                ),
                if (failures.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${failures.length} échec(s) :',
                    style: Theme.of(dialogContext).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  for (final failure in failures)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${failure.product.name} : ${failure.errorMessage}',
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAct = _selectedIds.isNotEmpty && !_isSyncing;

    return Scaffold(
      backgroundColor: AppPalette.formBackground,
      appBar: const _ReviewAppBar(),
      body: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!;
          _latestProducts = products;
          if (products.isEmpty) {
            return const _EmptyState(
              icon: Icons.inventory_2_outlined,
              message: 'Aucun produit pour le moment.',
            );
          }

          final incompleteCount = products.where((p) => !_isComplete(p)).length;
          final visible = _showOnlyIncomplete
              ? products.where((p) => !_isComplete(p)).toList()
              : products;
          // Une colonne de cartes en mobile (identique à la maquette), deux
          // ou trois sur grand écran.
          final columns = context.cardColumns;
          final rows = chunkIntoRows(_clusterByGroup(visible), columns);

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      children: [
                        _MetricsRow(
                          total: products.length,
                          selected: _selectedIds.length,
                          incomplete: incompleteCount,
                        ),
                        const SizedBox(height: 12),
                        _SelectionBar(
                          allSelected: _allSelected(visible),
                          selectedCount: visible
                              .where((p) => _selectedIds.contains(p.id))
                              .length,
                          visibleCount: visible.length,
                          onToggleAll: () => _toggleSelectAll(visible),
                          filterActive: _showOnlyIncomplete,
                          onToggleFilter: () => setState(
                            () => _showOnlyIncomplete = !_showOnlyIncomplete,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? const _EmptyState(
                            icon: Icons.task_alt,
                            message: 'Tous les produits sont complets.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              if (columns == 1) return _card(row.single);
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (
                                    var column = 0;
                                    column < columns;
                                    column++
                                  ) ...[
                                    if (column > 0) const SizedBox(width: 10),
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
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _ActionBar(
        onExportCsv: canAct ? _exportCsv : null,
        onSendToLoyverse: canAct ? _sendToLoyverse : null,
      ),
    );
  }
}

/// Barre supérieure : bouton retour rond, titre et sous-titre centrés.
class _ReviewAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ReviewAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: AppPalette.formBackground.withValues(alpha: 0.9),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leadingWidth: 64,
      shape: Border(
        bottom: BorderSide(color: AppPalette.brand100.withValues(alpha: 0.6)),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: Material(
            color: AppPalette.surface,
            shape: CircleBorder(
              side: BorderSide(
                color: AppPalette.brand100.withValues(alpha: 0.7),
              ),
            ),
            elevation: 2,
            shadowColor: AppPalette.brand600.withValues(alpha: 0.12),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: AppPalette.brand700,
                ),
              ),
            ),
          ),
        ),
      ),
      title: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Vérifier et exporter',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppPalette.slate900,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
          Text(
            'Catalogue & Loyverse POS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xCC614F8A),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trois indicateurs : produits, sélectionnés, incomplets (carte rose dès
/// qu'il y en a au moins un).
class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.total,
    required this.selected,
    required this.incomplete,
  });

  final int total;
  final int selected;
  final int incomplete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            value: '$total',
            label: 'Produits',
            valueColor: AppPalette.slate800,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            value: '$selected',
            label: 'Sélectionnés',
            valueColor: AppPalette.brand600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            value: '$incomplete',
            label: 'Incomplets',
            alert: incomplete > 0,
            valueColor: incomplete > 0
                ? AppPalette.danger
                : AppPalette.slate800,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.valueColor,
    this.alert = false,
  });

  final String value;
  final String label;
  final Color valueColor;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: alert
            ? AppPalette.alertBackground.withValues(alpha: 0.8)
            : AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert
              ? AppPalette.alertBorder.withValues(alpha: 0.9)
              : AppPalette.brand100.withValues(alpha: 0.8),
        ),
        boxShadow: AppPalette.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: alert ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0.8,
              color: alert ? AppPalette.danger : AppPalette.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre "Tout sélectionner (X sur Y)" + bouton-filtre "Incomplets".
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.allSelected,
    required this.selectedCount,
    required this.visibleCount,
    required this.onToggleAll,
    required this.filterActive,
    required this.onToggleFilter,
  });

  final bool allSelected;
  final int selectedCount;
  final int visibleCount;
  final VoidCallback onToggleAll;
  final bool filterActive;
  final VoidCallback onToggleFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.brand100.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: visibleCount == 0 ? null : onToggleAll,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    onChanged: visibleCount == 0 ? null : (_) => onToggleAll(),
                    activeColor: AppPalette.brand600,
                    side: const BorderSide(
                      color: AppPalette.brand200,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Tout sélectionner',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.slate700,
                        ),
                        children: [
                          TextSpan(
                            text: '  ($selectedCount sur $visibleCount)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppPalette.slate400,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _FilterChip(active: filterActive, onTap: onToggleFilter),
        ],
      ),
    );
  }
}

/// Bouton-filtre "Incomplets" : violet clair au repos, plein quand actif.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : AppPalette.brand700;
    return Material(
      color: active ? AppPalette.brand600 : AppPalette.brand50,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 14,
                color: active ? Colors.white : AppPalette.brand600,
              ),
              const SizedBox(width: 4),
              Text(
                'Incomplets',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
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

/// Carte d'un produit autonome (ne fait partie d'aucun groupe de variantes).
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.selected,
    required this.missing,
    required this.onChanged,
  });

  final Product product;
  final bool selected;
  final List<String> missing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _CardSurface(
      highlighted: selected,
      child: _ProductTile(
        product: product,
        selected: selected,
        missing: missing,
        onChanged: onChanged,
      ),
    );
  }
}

/// Carte regroupant visuellement tous les membres d'un même groupe de
/// variantes, pour que l'utilisateur comprenne qu'ils forment un seul
/// article Loyverse à plusieurs variantes plutôt que des produits distincts.
class _ProductGroupCard extends StatelessWidget {
  const _ProductGroupCard({
    required this.products,
    required this.selectedIds,
    required this.missingFields,
    required this.onToggle,
  });

  final List<Product> products;
  final Set<int> selectedIds;
  final List<String> Function(Product) missingFields;
  final void Function(int id) onToggle;

  @override
  Widget build(BuildContext context) {
    return _CardSurface(
      highlighted: products.any((p) => selectedIds.contains(p.id)),
      grouped: true,
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
              Divider(
                height: 1,
                color: AppPalette.brand100.withValues(alpha: 0.9),
              ),
            _ProductTile(
              product: products[i],
              selected: selectedIds.contains(products[i].id),
              missing: missingFields(products[i]),
              onChanged: () => onToggle(products[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

/// Surface blanche arrondie des cartes ; bordure plus marquée quand le
/// produit est sélectionné ou pour un groupe de variantes.
class _CardSurface extends StatelessWidget {
  const _CardSurface({
    required this.child,
    required this.highlighted,
    this.grouped = false,
  });

  final Widget child;
  final bool highlighted;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: grouped
              ? AppPalette.brand300
              : highlighted
              ? AppPalette.brand200.withValues(alpha: 0.7)
              : AppPalette.brand100.withValues(alpha: 0.9),
          width: grouped ? 1.5 : 1,
        ),
        boxShadow: AppPalette.cardShadow,
      ),
      child: child,
    );
  }
}

/// Ligne d'un produit : case à cocher, avertissement de complétude, nom,
/// sous-titre prix/catégorie/SKU/option avec les motifs manquants en rose,
/// badge de synchronisation. Réutilisée aussi bien pour un produit autonome
/// que pour chaque membre d'un groupe.
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.selected,
    required this.missing,
    required this.onChanged,
  });

  final Product product;
  final bool selected;
  final List<String> missing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final category = product.category?.trim();
    final sku = product.sku?.trim();
    final optionValue = product.optionValue?.trim();
    const dot = TextSpan(
      text: '  ·  ',
      style: TextStyle(color: AppPalette.slate300, fontWeight: FontWeight.w400),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChanged,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onChanged(),
                activeColor: AppPalette.brand600,
                side: const BorderSide(color: AppPalette.slate300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (missing.isNotEmpty) ...[
                          const _WarningDot(),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            product.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.slate900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppPalette.slate500,
                        ),
                        children: [
                          // Un prix manquant est déjà signalé par sa
                          // pastille rose : pas de "Prix non défini" en
                          // double ici.
                          if (product.sellPrice != null)
                            TextSpan(text: formatPrice(product.sellPrice)),
                          if (category != null && category.isNotEmpty) ...[
                            if (product.sellPrice != null) dot,
                            TextSpan(text: category),
                          ],
                          if (sku != null && sku.isNotEmpty) ...[
                            dot,
                            TextSpan(
                              text: 'SKU: $sku',
                              style: const TextStyle(
                                color: AppPalette.brand700,
                              ),
                            ),
                          ],
                          if (optionValue != null && optionValue.isNotEmpty) ...[
                            dot,
                            TextSpan(text: optionValue),
                          ],
                        ],
                      ),
                    ),
                    if (missing.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final reason in missing)
                            _MissingChip(label: reason),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(synced: product.syncedToLoyverse),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petite pastille rose avec icône d'avertissement devant le nom d'un
/// produit incomplet.
class _WarningDot extends StatelessWidget {
  const _WarningDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: AppPalette.alertBackground,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.warning_amber_rounded,
        size: 12,
        color: AppPalette.danger,
      ),
    );
  }
}

/// Motif d'incomplétude ("Prix non défini", "Catégorie non définie", "SKU
/// non défini").
class _MissingChip extends StatelessWidget {
  const _MissingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.rose50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppPalette.rose600,
        ),
      ),
    );
  }
}

/// Badge indiquant l'état de synchronisation du produit avec Loyverse.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.synced});

  final bool synced;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: synced ? AppPalette.brand100 : AppPalette.pink100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: synced
              ? AppPalette.brand200
              : AppPalette.pink200.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (synced)
            const Icon(Icons.check, size: 12, color: AppPalette.brand600)
          else
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppPalette.pink500,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 5),
          Text(
            synced ? 'Synchronisé' : 'En attente',
            style: TextStyle(
              color: synced ? AppPalette.brand800 : AppPalette.pink700,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre d'actions fixée en bas : export CSV (contour) et envoi Loyverse
/// (plein), désactivés tant qu'aucun produit n'est sélectionné.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onExportCsv,
    required this.onSendToLoyverse,
  });

  final VoidCallback? onExportCsv;
  final VoidCallback? onSendToLoyverse;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: AppPalette.brand100)),
        boxShadow: AppPalette.bottomBarShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          // heightFactor: 1 → la barre ne prend que la hauteur des boutons.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onExportCsv,
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      label: const Text('Exporter en CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.brand700,
                        backgroundColor: AppPalette.surface,
                        side: const BorderSide(color: AppPalette.brand200),
                        minimumSize: const Size.fromHeight(48),
                        shape: shape,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onSendToLoyverse,
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Vers Loyverse'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.brand600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: shape,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Boîte de dialogue non-annulable affichant la progression de la
/// synchronisation ("X/Y synchronisés...").
class _SyncProgressDialog extends StatelessWidget {
  const _SyncProgressDialog({required this.progress});

  final ValueListenable<(int, int)> progress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (context, value, _) {
            final (done, total) = value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Text('$done/$total synchronisés...'),
              ],
            );
          },
        ),
      ),
    );
  }
}
