import 'dart:convert' show utf8;
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Erreur d'import explicite, destinée à être affichée telle quelle à
/// l'utilisatrice (fichier illisible, colonne obligatoire absente...).
class DocxImportException implements Exception {
  const DocxImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lit le tableau de produits contenu dans un document Word (.docx).
///
/// Un .docx est une archive ZIP dont `word/document.xml` décrit le contenu
/// en WordprocessingML : les tableaux sont des `<w:tbl>`, leurs lignes des
/// `<w:tr>`, leurs cellules des `<w:tc>`, et le texte est réparti en
/// fragments `<w:t>` (un par "run" de mise en forme) qu'il faut recoller.
class DocxImportService {
  const DocxImportService();

  /// Espace de noms WordprocessingML (préfixe `w:` dans document.xml).
  static const _wordNamespace =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

  /// Clés des maps retournées par [parseDocxTable], dans l'ordre d'affichage.
  static const fieldName = 'name';
  static const fieldCategory = 'category';
  static const fieldQuantity = 'quantity';
  static const fieldSellPrice = 'sellPrice';
  static const fieldCostPrice = 'costPrice';
  static const fieldDescription = 'description';

  /// Intitulés de colonne reconnus (déjà normalisés par [normalizeHeader]),
  /// testés dans cet ordre : les mots les plus spécifiques d'abord, pour
  /// qu'un en-tête comme "Prix de revient (coût)" ne soit pas rangé dans le
  /// prix de vente. Chaque motif doit correspondre à un mot entier.
  static const _headerPatterns = <(String, String)>[
    ('description', fieldDescription),
    ('quantite', fieldQuantity),
    ('categorie', fieldCategory),
    ('cout', fieldCostPrice),
    ('prix', fieldSellPrice),
    ('nom', fieldName),
  ];

  /// Décompresse [file], lit son tableau et retourne une map "texte brut"
  /// par ligne de données (clés : [fieldName], [fieldCategory], ...), sans
  /// aucune conversion en [Product] : c'est l'écran d'aperçu qui interprète
  /// les nombres et signale les lignes douteuses.
  ///
  /// Lève une [DocxImportException] si le fichier n'est pas un .docx
  /// valide, ne contient aucun tableau, ou si sa colonne "Nom de l'article"
  /// est introuvable.
  Future<List<Map<String, String>>> parseDocxTable(File file) async {
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      throw DocxImportException('Impossible de lire le fichier : $e');
    }
    return parseDocxBytes(bytes);
  }

  /// Variante de [parseDocxTable] travaillant sur le contenu déjà chargé en
  /// mémoire (utile pour les tests, sans passer par le système de fichiers).
  List<Map<String, String>> parseDocxBytes(Uint8List bytes) {
    final documentXml = _extractDocumentXml(bytes);
    final tables = _parseTables(documentXml);
    if (tables.isEmpty) {
      throw const DocxImportException(
        'Aucun tableau trouvé dans ce document. Le fichier doit contenir '
        'un tableau Word avec une colonne "Nom de l\'article".',
      );
    }

    final headerRow = tables.first.first;
    final columnMapping = _mapHeader(headerRow);
    if (!columnMapping.containsValue(fieldName)) {
      throw DocxImportException(
        'Colonne "Nom de l\'article" introuvable dans l\'en-tête du tableau '
        '(colonnes lues : ${_describeHeader(headerRow)}). Import impossible '
        'sans cette colonne.',
      );
    }

    final rows = <Map<String, String>>[];
    for (var tableIndex = 0; tableIndex < tables.length; tableIndex++) {
      final table = tables[tableIndex];
      for (var rowIndex = 0; rowIndex < table.length; rowIndex++) {
        final cells = table[rowIndex];
        // L'en-tête n'est lu que sur la première ligne de la première
        // table ; s'il est répété en tête d'une table suivante (tableau
        // coupé en deux dans Word), on l'ignore plutôt que de l'importer
        // comme un produit nommé "Nom de l'article".
        if (rowIndex == 0 &&
            (tableIndex == 0 || _isSameHeader(cells, headerRow))) {
          continue;
        }
        if (cells.every((cell) => cell.isEmpty)) continue;

        final row = <String, String>{};
        columnMapping.forEach((columnIndex, field) {
          row[field] = columnIndex < cells.length ? cells[columnIndex] : '';
        });
        rows.add(row);
      }
    }
    return rows;
  }

  /// Normalise un intitulé de colonne pour la correspondance : minuscules,
  /// accents supprimés, apostrophes typographiques ramenées à `'`, espaces
  /// multiples réduits à un seul et bords rognés.
  static String normalizeHeader(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_accentMap[char] ?? char);
    }
    return buffer
        .toString()
        .replaceAll(RegExp('[’‘`´]'), "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Retourne le champ associé à un intitulé de colonne normalisé, ou null
  /// si la colonne n'est pas reconnue (elle est alors ignorée).
  static String? fieldForHeader(String normalizedHeader) {
    for (final (pattern, field) in _headerPatterns) {
      if (RegExp('(^|[^a-z])$pattern([^a-z]|\$)').hasMatch(normalizedHeader)) {
        return field;
      }
    }
    return null;
  }

  Uint8List _extractDocumentXml(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const DocxImportException(
        'Ce fichier n\'est pas un document Word (.docx) valide.',
      );
    }
    final entry = archive.findFile('word/document.xml');
    if (entry == null) {
      throw const DocxImportException(
        'Ce fichier n\'est pas un document Word (.docx) : contenu '
        '"word/document.xml" introuvable.',
      );
    }
    return entry.content;
  }

  /// Retourne, pour chaque tableau de premier niveau du document, la liste
  /// de ses lignes, chaque ligne étant la liste du texte de ses cellules.
  List<List<List<String>>> _parseTables(Uint8List documentXml) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(utf8.decode(documentXml));
    } catch (_) {
      throw const DocxImportException(
        'Le contenu du document Word est illisible (XML invalide).',
      );
    }

    final tables = <List<List<String>>>[];
    for (final table in document.findAllElements(
      'tbl',
      namespaceUri: _wordNamespace,
    )) {
      // Un tableau imbriqué dans une cellule d'un autre tableau n'est pas
      // un tableau de produits à part entière : son texte est déjà lu
      // avec la cellule qui le contient.
      if (_hasTableAncestor(table)) continue;

      final rows = <List<String>>[];
      for (final row in table.findElements(
        'tr',
        namespaceUri: _wordNamespace,
      )) {
        rows.add([
          for (final cell in row.findElements(
            'tc',
            namespaceUri: _wordNamespace,
          ))
            _cellText(cell),
        ]);
      }
      if (rows.isNotEmpty) tables.add(rows);
    }
    return tables;
  }

  bool _hasTableAncestor(XmlElement element) {
    for (final ancestor in element.ancestorElements) {
      if (ancestor.localName == 'tbl' &&
          ancestor.namespaceUri == _wordNamespace) {
        return true;
      }
    }
    return false;
  }

  /// Texte d'une cellule : tous ses `<w:t>` concaténés, paragraphe par
  /// paragraphe (un retour à la ligne entre deux paragraphes, comme dans
  /// Word), puis rogné.
  String _cellText(XmlElement cell) {
    final paragraphs = <String>[];
    for (final paragraph in cell.findAllElements(
      'p',
      namespaceUri: _wordNamespace,
    )) {
      final buffer = StringBuffer();
      for (final node in paragraph.descendantElements) {
        if (node.namespaceUri != _wordNamespace) continue;
        switch (node.localName) {
          case 't':
            buffer.write(node.innerText);
          case 'tab':
            buffer.write('\t');
          case 'br':
          case 'cr':
            buffer.write('\n');
        }
      }
      paragraphs.add(buffer.toString());
    }
    return paragraphs.join('\n').trim();
  }

  /// Associe l'index de chaque colonne reconnue de l'en-tête au champ
  /// correspondant. Si deux colonnes désignent le même champ, la première
  /// l'emporte.
  Map<int, String> _mapHeader(List<String> headerRow) {
    final mapping = <int, String>{};
    for (var i = 0; i < headerRow.length; i++) {
      final field = fieldForHeader(normalizeHeader(headerRow[i]));
      if (field != null && !mapping.containsValue(field)) {
        mapping[i] = field;
      }
    }
    return mapping;
  }

  bool _isSameHeader(List<String> cells, List<String> headerRow) {
    if (cells.length != headerRow.length) return false;
    for (var i = 0; i < cells.length; i++) {
      if (normalizeHeader(cells[i]) != normalizeHeader(headerRow[i])) {
        return false;
      }
    }
    return true;
  }

  String _describeHeader(List<String> headerRow) {
    final labels = headerRow.where((c) => c.isNotEmpty).toList();
    return labels.isEmpty ? 'aucune' : labels.map((c) => '"$c"').join(', ');
  }

  /// Table de suppression des accents pour les lettres rencontrées en
  /// français (le texte est déjà en minuscules à ce stade).
  static const _accentMap = <String, String>{
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'œ': 'oe',
    'æ': 'ae',
  };
}
