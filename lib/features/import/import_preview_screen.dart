import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:drift/drift.dart' show Value;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/config.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/number_parser.dart';
import 'docx_import_service.dart';

/// Filtre d'affichage des lignes détectées (onglets "Tous / Valides /
/// Erreurs"). Purement visuel : l'import enregistre toujours toutes les
/// lignes lues, y compris celles en anomalie (voir [ImportPreviewRow]).
enum _RowFilter { all, valid, errors }

/// Largeur maximale du contenu : celle de la maquette en mobile, élargie
/// sur grand écran en fonction du nombre de colonnes.
double _maxWidth(BuildContext context) => context.contentMaxWidth;

/// Valeur de `importSource` pour les produits créés depuis un .docx.
const kDocxImportSource = 'docx_import';

/// Nom attribué à une ligne importée dont la colonne "Nom de l'article" est
/// vide, pour ne perdre aucune ligne du tableau tout en la rendant facile à
/// repérer dans la liste des produits.
const kMissingNamePlaceholder = 'Article sans nom';

/// Une ligne du tableau Word interprétée pour l'aperçu : valeurs brutes
/// conservées pour l'affichage, valeurs converties pour l'enregistrement,
/// et liste des points à vérifier (nom vide, nombre illisible...).
class ImportPreviewRow {
  const ImportPreviewRow({
    required this.name,
    required this.category,
    required this.description,
    required this.rawQuantity,
    required this.rawSellPrice,
    required this.rawCostPrice,
    required this.quantity,
    required this.sellPrice,
    required this.costPrice,
    required this.warnings,
  });

  /// Interprète une ligne brute renvoyée par
  /// [DocxImportService.parseDocxTable]. Ne lève jamais : un nombre
  /// illisible devient un avertissement, pas une erreur.
  factory ImportPreviewRow.fromRaw(Map<String, String> raw) {
    String cell(String field) => (raw[field] ?? '').trim();

    final name = cell(DocxImportService.fieldName);
    final rawQuantity = cell(DocxImportService.fieldQuantity);
    final rawSellPrice = cell(DocxImportService.fieldSellPrice);
    final rawCostPrice = cell(DocxImportService.fieldCostPrice);
    final warnings = <String>[];

    if (name.isEmpty) {
      warnings.add(
        'Nom manquant : sera importé sous « $kMissingNamePlaceholder »',
      );
    }

    var quantity = 0;
    if (rawQuantity.isNotEmpty) {
      final parsed = parseFrenchNumber(rawQuantity);
      if (parsed == null) {
        warnings.add('Quantité illisible (« $rawQuantity »), mise à 0');
      } else if (parsed != parsed.roundToDouble()) {
        quantity = parsed.round();
        warnings.add(
          'Quantité non entière (« $rawQuantity »), arrondie à $quantity',
        );
      } else {
        quantity = parsed.toInt();
      }
    }

    double? price(String rawValue, String label) {
      if (rawValue.isEmpty) return null;
      final parsed = parseFrenchNumber(rawValue);
      if (parsed == null) {
        warnings.add('$label illisible (« $rawValue »), laissé vide');
      }
      return parsed;
    }

    final sellPrice = price(rawSellPrice, 'Prix');
    final costPrice = price(rawCostPrice, 'Coût');

    return ImportPreviewRow(
      name: name,
      category: cell(DocxImportService.fieldCategory),
      description: cell(DocxImportService.fieldDescription),
      rawQuantity: rawQuantity,
      rawSellPrice: rawSellPrice,
      rawCostPrice: rawCostPrice,
      quantity: quantity,
      sellPrice: sellPrice,
      costPrice: costPrice,
      warnings: warnings,
    );
  }

  final String name;
  final String category;
  final String description;
  final String rawQuantity;
  final String rawSellPrice;
  final String rawCostPrice;
  final int quantity;
  final double? sellPrice;
  final double? costPrice;
  final List<String> warnings;

  bool get needsReview => warnings.isNotEmpty;

  /// Produit à insérer pour cette ligne. SKU, code-barres, option et photo
  /// restent volontairement vides : ils seront complétés fiche par fiche
  /// dans l'app (voir le compteur "fiches importées à compléter" sur
  /// l'écran d'accueil).
  ProductsCompanion toCompanion({
    required String batchId,
    required DateTime now,
  }) {
    return ProductsCompanion(
      name: Value(name.isEmpty ? kMissingNamePlaceholder : name),
      category: Value(category.isEmpty ? null : category),
      description: Value(description.isEmpty ? null : description),
      quantity: Value(quantity),
      sellPrice: Value(sellPrice),
      costPrice: Value(costPrice),
      importSource: const Value(kDocxImportSource),
      importBatchId: Value(batchId),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncedToLoyverse: const Value(false),
    );
  }
}

/// Aperçu des lignes lues dans un tableau Word avant leur enregistrement.
///
/// Point d'entrée habituel : [ImportPreviewScreen.pickAndImport], qui ouvre
/// le sélecteur de fichier, lit le document et pousse cet écran.
class ImportPreviewScreen extends StatefulWidget {
  const ImportPreviewScreen({
    super.key,
    required this.database,
    required this.rows,
    required this.fileName,
    this.fileSizeInBytes,
  });

  final AppDatabase database;
  final List<ImportPreviewRow> rows;
  final String fileName;

  /// Taille du document lu, affichée à côté de son nom. Null si elle n'a pas
  /// pu être obtenue (le fichier reste importable : sa taille n'est
  /// qu'indicative).
  final int? fileSizeInBytes;

  /// Au-delà de ce nombre de lignes, une barre de progression est affichée
  /// pendant l'enregistrement.
  static const progressThreshold = 20;

  /// Ouvre le sélecteur de fichier (.docx), lit le tableau du document et
  /// affiche l'aperçu. Retourne le nombre de produits importés, ou `null`
  /// si l'utilisatrice a annulé (sélecteur fermé, retour arrière) ou si le
  /// document n'a pas pu être lu (une boîte de dialogue explique alors
  /// pourquoi).
  static Future<int?> pickAndImport(
    BuildContext context,
    AppDatabase database,
  ) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Document Word',
          extensions: ['docx'],
          mimeTypes: [
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          ],
        ),
      ],
    );
    if (file == null || !context.mounted) return null;

    final List<Map<String, String>> rawRows;
    try {
      rawRows = await const DocxImportService().parseDocxTable(File(file.path));
    } on DocxImportException catch (e) {
      if (context.mounted) await _showErrorDialog(context, e.message);
      return null;
    }
    if (!context.mounted) return null;

    if (rawRows.isEmpty) {
      await _showErrorDialog(
        context,
        'Le tableau du document ne contient aucune ligne de produit sous '
        'son en-tête.',
      );
      return null;
    }

    final rows = rawRows.map(ImportPreviewRow.fromRaw).toList();
    int? sizeInBytes;
    try {
      sizeInBytes = await file.length();
    } catch (_) {
      // Taille purement indicative : son absence ne doit pas empêcher
      // l'aperçu ni l'import.
      sizeInBytes = null;
    }
    if (!context.mounted) return null;

    return Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ImportPreviewScreen(
          database: database,
          rows: rows,
          fileName: file.name,
          fileSizeInBytes: sizeInBytes,
        ),
      ),
    );
  }

  static Future<void> _showErrorDialog(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import impossible'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  bool _isSaving = false;
  _RowFilter _filter = _RowFilter.all;

  Future<void> _confirmImport() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final batchId = const Uuid().v4();
    final now = DateTime.now();
    final companions = [
      for (final row in widget.rows)
        row.toCompanion(batchId: batchId, now: now),
    ];

    final showProgress =
        companions.length > ImportPreviewScreen.progressThreshold;
    final progress = ValueNotifier<(int, int)>((0, companions.length));
    if (showProgress) {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ImportProgressDialog(progress: progress),
        ),
      );
    }

    int importedCount;
    try {
      importedCount = await widget.database.insertProductsInTransaction(
        companions,
        onProgress: (done, total) => progress.value = (done, total),
      );
    } catch (e) {
      // La transaction a tout annulé : aucun produit n'a été enregistré.
      progress.dispose();
      if (!mounted) return;
      if (showProgress) Navigator.of(context).pop();
      setState(() => _isSaving = false);
      await ImportPreviewScreen._showErrorDialog(
        context,
        'L\'enregistrement a échoué, aucun produit n\'a été importé : $e',
      );
      return;
    }

    progress.dispose();
    if (!mounted) return;
    if (showProgress) Navigator.of(context).pop(); // Ferme la progression.
    Navigator.of(context).pop(importedCount);
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final invalidCount = rows.where((r) => r.needsReview).length;
    final validCount = rows.length - invalidCount;

    // Le filtre "Erreurs" ne peut rester actif si plus aucune ligne n'est
    // en anomalie (cas théorique : la liste ne change pas après ouverture).
    final visible = switch (_filter) {
      _RowFilter.all => rows,
      _RowFilter.valid => rows.where((r) => !r.needsReview).toList(),
      _RowFilter.errors => rows.where((r) => r.needsReview).toList(),
    };
    final columns = context.cardColumns;

    return Scaffold(
      backgroundColor: AppPalette.formBackground,
      appBar: const _PreviewAppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _maxWidth(context)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _FileSummaryCard(
                fileName: widget.fileName,
                fileSizeInBytes: widget.fileSizeInBytes,
                validCount: validCount,
                invalidCount: invalidCount,
              ),
              const SizedBox(height: 16),
              _FilterTabs(
                selected: _filter,
                totalCount: rows.length,
                validCount: validCount,
                errorCount: invalidCount,
                onSelected: (filter) => setState(() => _filter = filter),
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                const _EmptyFilterState()
              else
                // Une colonne de lignes en mobile (identique à la maquette),
                // deux ou trois sur grand écran.
                for (final group in chunkIntoRows(visible, columns)) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: 12),
                        Expanded(
                          child: column < group.length
                              ? _PreviewRowCard(
                                  index: rows.indexOf(group[column]) + 1,
                                  row: group[column],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _ConfirmBar(
        count: rows.length,
        onConfirm: _isSaving ? null : _confirmImport,
      ),
    );
  }
}

/// Barre supérieure : bouton retour rond et titre centré. La maquette y
/// ajoutait un menu "..." : écarté, aucune action supplémentaire n'existe.
class _PreviewAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PreviewAppBar();

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
        bottom: BorderSide(color: AppPalette.purple100.withValues(alpha: 0.6)),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: Material(
            color: AppPalette.surface,
            shape: const CircleBorder(
              side: BorderSide(color: AppPalette.slate100),
            ),
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: AppPalette.slate700,
                ),
              ),
            ),
          ),
        ),
      ),
      title: const Text(
        'Aperçu de l\'import',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppPalette.slate900,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

/// Carte d'en-tête : document détecté (nom, taille) puis deux pastilles
/// "X produits prêts à l'import" / "Y à vérifier".
class _FileSummaryCard extends StatelessWidget {
  const _FileSummaryCard({
    required this.fileName,
    required this.fileSizeInBytes,
    required this.validCount,
    required this.invalidCount,
  });

  final String fileName;
  final int? fileSizeInBytes;
  final int validCount;
  final int invalidCount;

  /// Taille lisible ("24 Ko", "1,2 Mo"), ou null si inconnue.
  static String? formatSize(int? bytes) {
    if (bytes == null) return null;
    if (bytes < 1024) return '$bytes o';
    final kilobytes = bytes / 1024;
    if (kilobytes < 1024) return '${kilobytes.round()} Ko';
    final megabytes = kilobytes / 1024;
    return '${megabytes.toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final size = formatSize(fileSizeInBytes);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppPalette.purple100.withValues(alpha: 0.7)),
        boxShadow: AppPalette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.brand100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppPalette.brand700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.brand50,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'DOCX détecté',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.brand600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (size != null)
                          Text(
                            size,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppPalette.slate400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Tooltip(
                      message: fileName,
                      child: Text(
                        fileName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.slate800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppPalette.slate100),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.check,
                  background: const Color(0xFFEBF7EE),
                  borderColor: AppPalette.emerald200,
                  iconColor: AppPalette.emerald600,
                  title:
                      '$validCount produit${validCount > 1 ? 's' : ''}',
                  subtitle: 'Prêt${validCount > 1 ? 's' : ''} à l\'import',
                  titleColor: AppPalette.emerald700,
                  subtitleColor: AppPalette.emerald600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  icon: invalidCount > 0
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  background: invalidCount > 0
                      ? AppPalette.rose50
                      : AppPalette.brand50,
                  borderColor: invalidCount > 0
                      ? AppPalette.rose200
                      : AppPalette.brand100,
                  iconColor: invalidCount > 0
                      ? AppPalette.rose600
                      : AppPalette.brand700,
                  title: '$invalidCount à vérifier',
                  subtitle: invalidCount > 0
                      ? 'Importé${invalidCount > 1 ? 's' : ''} tel${invalidCount > 1 ? 's' : ''} quel${invalidCount > 1 ? 's' : ''}'
                      : 'Aucune anomalie',
                  titleColor: invalidCount > 0
                      ? AppPalette.rose700
                      : AppPalette.slate800,
                  subtitleColor: invalidCount > 0
                      ? AppPalette.rose600
                      : AppPalette.slate500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pastille d'un des deux compteurs de l'en-tête.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.background,
    required this.borderColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
  });

  final IconData icon;
  final Color background;
  final Color borderColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    height: 1.2,
                  ),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Onglets de filtre "Tous / Valides / Erreurs", chacun avec son compteur.
/// Un onglet dont le compteur est à zéro n'est pas sélectionnable.
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selected,
    required this.totalCount,
    required this.validCount,
    required this.errorCount,
    required this.onSelected,
  });

  final _RowFilter selected;
  final int totalCount;
  final int validCount;
  final int errorCount;
  final ValueChanged<_RowFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.purple100.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterTab(
              label: 'Tous',
              count: totalCount,
              active: selected == _RowFilter.all,
              onTap: () => onSelected(_RowFilter.all),
            ),
          ),
          Expanded(
            child: _FilterTab(
              label: 'Valides',
              count: validCount,
              active: selected == _RowFilter.valid,
              countBackground: AppPalette.emerald50,
              countForeground: AppPalette.emerald700,
              onTap: validCount == 0
                  ? null
                  : () => onSelected(_RowFilter.valid),
            ),
          ),
          Expanded(
            child: _FilterTab(
              label: 'Erreurs',
              count: errorCount,
              active: selected == _RowFilter.errors,
              countBackground: AppPalette.rose50,
              countForeground: AppPalette.rose700,
              onTap: errorCount == 0
                  ? null
                  : () => onSelected(_RowFilter.errors),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.countBackground = AppPalette.slate100,
    this.countForeground = AppPalette.slate500,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback? onTap;
  final Color countBackground;
  final Color countForeground;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final foreground = active
        ? Colors.white
        : disabled
        ? AppPalette.slate400
        : AppPalette.slate600;

    return Material(
      color: active ? AppPalette.brand600 : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.2)
                      : disabled
                      ? AppPalette.slate100
                      : countBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? Colors.white
                        : disabled
                        ? AppPalette.slate400
                        : countForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Affiché quand le filtre actif ne laisse aucune ligne (cas limite : une
/// liste entièrement valide filtrée sur "Erreurs" n'est pas atteignable,
/// l'onglet étant alors désactivé).
class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.filter_alt_off_outlined, size: 36, color: AppPalette.brand300),
          SizedBox(height: 10),
          Text(
            'Aucune ligne dans ce filtre.',
            style: TextStyle(fontSize: 13, color: AppPalette.slate500),
          ),
        ],
      ),
    );
  }
}

/// Carte d'une ligne détectée : numéro, nom, badge OK/à vérifier,
/// description, puis étiquettes catégorie / quantité / prix / coût et la
/// liste des avertissements le cas échéant.
class _PreviewRowCard extends StatelessWidget {
  const _PreviewRowCard({required this.index, required this.row});

  final int index;
  final ImportPreviewRow row;

  @override
  Widget build(BuildContext context) {
    final hasName = row.name.isNotEmpty;
    final needsReview = row.needsReview;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: needsReview ? AppPalette.rose200 : AppPalette.slate100,
        ),
        boxShadow: AppPalette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: needsReview ? AppPalette.rose50 : AppPalette.brand50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: needsReview
                        ? AppPalette.rose200
                        : AppPalette.brand100,
                  ),
                ),
                child: Icon(
                  needsReview
                      ? Icons.warning_amber_rounded
                      : Icons.inventory_2_outlined,
                  size: 22,
                  color: needsReview
                      ? AppPalette.rose600
                      : AppPalette.brand700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#$index',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.slate400,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hasName ? row.name : kMissingNamePlaceholder,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.slate900,
                              fontStyle: hasName
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(needsReview: needsReview),
                      ],
                    ),
                    if (row.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        row.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.slate500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppPalette.slate100),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (row.category.isNotEmpty) _MetaTag(label: row.category),
              _MetaTag(label: 'Qté : ${orDash(row.rawQuantity)}'),
              _MetaTag(
                label: '${orDash(row.rawSellPrice)} $kCurrencySymbol',
                emphasized: true,
              ),
              Text(
                'Coût : ${orDash(row.rawCostPrice)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppPalette.slate400,
                ),
              ),
            ],
          ),
          for (final warning in row.warnings) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 13,
                  color: AppPalette.rose600,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    warning,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.rose600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String orDash(String value) => value.isEmpty ? '—' : value;
}

/// Badge "OK" (vert) ou "À vérifier" (rose) en haut à droite d'une ligne.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.needsReview});

  final bool needsReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: needsReview ? AppPalette.rose50 : AppPalette.emerald50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: needsReview
              ? AppPalette.rose200
              : AppPalette.emerald200.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            needsReview ? Icons.priority_high : Icons.check,
            size: 10,
            color: needsReview ? AppPalette.rose700 : AppPalette.emerald700,
          ),
          const SizedBox(width: 3),
          Text(
            needsReview ? 'À vérifier' : 'OK',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: needsReview ? AppPalette.rose700 : AppPalette.emerald700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Étiquette grise (catégorie, quantité) ou violette (prix) d'une ligne.
class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized ? AppPalette.brand50 : AppPalette.slate100,
        borderRadius: BorderRadius.circular(6),
        border: emphasized
            ? Border.all(color: AppPalette.brand100)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          color: emphasized ? AppPalette.brand700 : AppPalette.slate700,
        ),
      ),
    );
  }
}

/// Barre fixée en bas : "Confirmer l'import (X)". Le compteur porte sur la
/// totalité des lignes lues, filtre d'affichage ou non : l'import enregistre
/// toujours tout le document.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.count, required this.onConfirm});

  final int count;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: AppPalette.purple100.withValues(alpha: 0.7)),
        ),
        boxShadow: AppPalette.bottomBarShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          // heightFactor: 1 → la barre ne prend que la hauteur du bouton.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _maxWidth(context)),
              child: FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text('Confirmer l\'import ($count)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.brand600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Boîte de dialogue non-annulable affichant la progression de
/// l'enregistrement ("X/Y enregistrés..." avec barre de progression).
class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({required this.progress});

  final ValueListenable<(int, int)> progress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Import en cours'),
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (context, value, _) {
            final (done, total) = value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: total == 0 ? null : done / total,
                ),
                const SizedBox(height: 12),
                Text('$done/$total enregistrés...'),
              ],
            );
          },
        ),
      ),
    );
  }
}
