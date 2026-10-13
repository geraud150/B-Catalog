import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, FileSystemException, Platform;
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:path_provider/path_provider.dart';

import '../../core/config.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/handle.dart';

/// Issue d'une sauvegarde de CSV : ce qui a été fait du fichier, pour que
/// l'écran appelant puisse en informer l'utilisatrice justement.
enum CsvSaveStatus {
  /// L'utilisatrice a fermé le sélecteur "Enregistrer sous" (Desktop).
  cancelled,

  /// Écrit à l'emplacement choisi dans le sélecteur (Desktop).
  saved,

  /// Écrit dans le dossier public "Téléchargements" (Android).
  savedToDownloads,

  /// Repli Android : le dossier public n'était pas accessible, le fichier
  /// est dans le dossier de l'application.
  savedToAppFolder,
}

/// Résultat d'une sauvegarde, avec le chemin du fichier écrit le cas
/// échéant.
class CsvSaveResult {
  const CsvSaveResult(this.status, {this.path});

  const CsvSaveResult.cancelled() : status = CsvSaveStatus.cancelled, path = null;

  final CsvSaveStatus status;
  final String? path;

  bool get isSaved => status != CsvSaveStatus.cancelled;
}

/// Service de génération et de sauvegarde du fichier CSV au format d'import
/// Loyverse (r.loyverse.com/v2/goods/import).
class CsvExportService {
  const CsvExportService();

  static const List<String> _header = [
    'Handle',
    'SKU',
    'Name',
    'Category',
    'Description',
    'Sold by weight',
    'Option 1 name',
    'Option 1 value',
    'Option 2 name',
    'Option 2 value',
    'Option 3 name',
    'Option 3 value',
    'Cost',
    'Barcode',
    'SKU of included item',
    'Quantity of included item',
    'Track stock',
    'Available for sale [$kLoyverseStoreName]',
    'Price [$kLoyverseStoreName]',
    'In stock [$kLoyverseStoreName]',
    'Low stock [$kLoyverseStoreName]',
  ];

  /// Produits dont le SKU est absent.
  ///
  /// Loyverse exige un SKU unique pour chaque article : un fichier contenant
  /// une ligne sans SKU est rejeté à l'import.
  List<Product> productsMissingSku(List<Product> products) {
    return products
        .where((p) => p.sku == null || p.sku!.trim().isEmpty)
        .toList();
  }

  /// Génère le contenu CSV (en-tête inclus) pour les [products] fournis.
  ///
  /// L'échappement des virgules, guillemets et retours à la ligne dans les
  /// champs (ex. noms ou descriptions de produits) est géré automatiquement
  /// par le package `csv`.
  String exportToCsv(List<Product> products) {
    final rows = <List<dynamic>>[
      _header,
      for (final product in products) _rowFor(product),
    ];
    return const CsvEncoder().convert(rows);
  }

  List<dynamic> _rowFor(Product product) {
    return [
      // Vide pour un produit autonome (Loyverse générera un Handle à
      // l'import) ; identique entre membres d'un même groupe de variantes
      // sinon, pour qu'ils soient importés comme un seul article.
      generateHandle(product),
      product.sku ?? '',
      product.name,
      product.category ?? '',
      product.description ?? '',
      // Loyverse bascule l'article en vente au poids si la colonne est vide.
      'N', // Sold by weight
      product.optionName ?? '',
      product.optionValue ?? '',
      '', // Option 2 name
      '', // Option 2 value
      '', // Option 3 name
      '', // Option 3 value
      _formatNumber(product.costPrice),
      product.barcode ?? '',
      '', // SKU of included item
      '', // Quantity of included item
      'Y', // Track stock
      'Y', // Available for sale [store]
      _formatNumber(product.sellPrice),
      product.quantity,
      '', // Low stock [store]
    ];
  }

  /// Formate un montant sans décimale superflue : `12.0` devient `12`,
  /// `12.5` reste `12.5` (Loyverse attend un point comme séparateur).
  static String _formatNumber(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  /// Sauvegarde [csvContent] dans un fichier nommé
  /// `loyverse_import_AAAAMMJJ_HHmm.csv`, selon la plateforme :
  ///
  /// - Desktop (Windows...) : boîte de dialogue "Enregistrer sous", qui
  ///   laisse choisir l'emplacement ;
  /// - Android : écriture directe dans le dossier public
  ///   "Téléchargements", sans feuille de partage.
  Future<CsvSaveResult> saveCsv(String csvContent) async {
    final fileName = defaultFileName();
    final bytes = Uint8List.fromList(utf8.encode(csvContent));

    if (Platform.isAndroid) return _saveToDownloads(bytes, fileName);

    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (location == null) return const CsvSaveResult.cancelled();

    final file = XFile.fromData(bytes, mimeType: 'text/csv', name: fileName);
    await file.saveTo(location.path);
    return CsvSaveResult(CsvSaveStatus.saved, path: location.path);
  }

  /// Emplacements possibles du dossier public "Téléchargements" selon les
  /// constructeurs et les versions d'Android.
  @visibleForTesting
  static const androidDownloadsPaths = [
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/sdcard/Download',
  ];

  /// Premier dossier de [paths] qui existe, ou `null` si aucun. [exists] est
  /// injecté pour rester testable sans toucher au système de fichiers.
  @visibleForTesting
  static String? firstExistingDirectory(
    Iterable<String> paths, {
    required bool Function(String path) exists,
  }) {
    for (final path in paths) {
      if (exists(path)) return path;
    }
    return null;
  }

  /// Écrit le fichier dans le dossier public "Téléchargements". Si celui-ci
  /// est introuvable ou refusé (anciennes versions d'Android sans
  /// permission, stockage cloisonné restrictif), se rabat sur le dossier de
  /// l'application plutôt que de perdre l'export.
  Future<CsvSaveResult> _saveToDownloads(
    Uint8List bytes,
    String fileName,
  ) async {
    final downloads = firstExistingDirectory(
      androidDownloadsPaths,
      exists: (path) => Directory(path).existsSync(),
    );

    if (downloads != null) {
      try {
        final file = File('$downloads/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        return CsvSaveResult(
          CsvSaveStatus.savedToDownloads,
          path: file.path,
        );
      } on FileSystemException catch (e) {
        debugPrint(
          '[CsvExport] écriture impossible dans $downloads ($e) : '
          'repli sur le dossier de l\'application.',
        );
      }
    }

    final directory =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return CsvSaveResult(CsvSaveStatus.savedToAppFolder, path: file.path);
  }

  /// Nom de fichier horodaté, commun à toutes les plateformes.
  @visibleForTesting
  static String defaultFileName([DateTime? now]) {
    final date = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'loyverse_import_${date.year}${two(date.month)}${two(date.day)}_'
        '${two(date.hour)}${two(date.minute)}.csv';
  }
}
