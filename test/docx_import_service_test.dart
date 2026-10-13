import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:boutique_catalog/features/import/docx_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fabrique un .docx minimal (archive ZIP contenant word/document.xml) dont
/// le corps est constitué des [tables] fournies, chaque table étant une
/// liste de lignes, chaque ligne une liste de cellules. Chaque cellule est
/// découpée en plusieurs `<w:t>` (comme Word le fait selon la mise en
/// forme) pour vérifier que le service recolle bien les fragments.
Uint8List buildDocx(List<List<List<String>>> tables, {String? extraBody}) {
  final buffer = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>',
    );
  for (final table in tables) {
    buffer.write('<w:tbl>');
    for (final row in table) {
      buffer.write('<w:tr>');
      for (final cell in row) {
        buffer.write('<w:tc><w:p>');
        // Coupe le texte en deux runs pour simuler la fragmentation Word.
        final middle = cell.length ~/ 2;
        buffer.write('<w:r><w:t xml:space="preserve">');
        buffer.write(_escape(cell.substring(0, middle)));
        buffer.write('</w:t></w:r><w:r><w:t xml:space="preserve">');
        buffer.write(_escape(cell.substring(middle)));
        buffer.write('</w:t></w:r></w:p></w:tc>');
      }
      buffer.write('</w:tr>');
    }
    buffer.write('</w:tbl>');
  }
  if (extraBody != null) buffer.write(extraBody);
  buffer.write('</w:body></w:document>');

  return buildDocxFromXml(buffer.toString());
}

Uint8List buildDocxFromXml(String documentXml) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.bytes(
        'word/document.xml',
        Uint8List.fromList(utf8.encode(documentXml)),
      ),
    )
    ..addFile(
      ArchiveFile.bytes(
        '[Content_Types].xml',
        Uint8List.fromList(utf8.encode('<Types/>')),
      ),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

void main() {
  const service = DocxImportService();

  const header = [
    "Nom de l'article",
    'Catégorie',
    'Quantité',
    'Prix',
    'Coût',
    'Description',
  ];

  group('normalizeHeader / fieldForHeader', () {
    test('normalise casse, accents, apostrophes et espaces', () {
      expect(
        DocxImportService.normalizeHeader('  NOM  DE  L’ARTICLE '),
        "nom de l'article",
      );
      expect(DocxImportService.normalizeHeader('Catégorie'), 'categorie');
      expect(DocxImportService.normalizeHeader('COÛT'), 'cout');
    });

    test(
      'associe chaque intitulé au bon champ, quelle que soit la position',
      () {
        expect(DocxImportService.fieldForHeader("nom de l'article"), 'name');
        expect(DocxImportService.fieldForHeader('nom'), 'name');
        expect(DocxImportService.fieldForHeader('categorie'), 'category');
        expect(DocxImportService.fieldForHeader('quantite'), 'quantity');
        expect(DocxImportService.fieldForHeader('prix'), 'sellPrice');
        expect(DocxImportService.fieldForHeader('prix de vente'), 'sellPrice');
        expect(DocxImportService.fieldForHeader('cout'), 'costPrice');
        expect(DocxImportService.fieldForHeader('description'), 'description');
      },
    );

    test('ne confond pas un mot contenant "nom" ou "prix" avec le champ', () {
      expect(DocxImportService.fieldForHeader('nombre'), isNull);
      expect(DocxImportService.fieldForHeader('reference'), isNull);
      expect(
        DocxImportService.fieldForHeader('prix de revient (cout)'),
        'costPrice',
      );
    });
  });

  group('parseDocxBytes', () {
    test('lit les lignes du tableau en recollant les fragments de texte', () {
      final bytes = buildDocx([
        [
          header,
          [
            'Rouge à lèvres',
            'Maquillage',
            '12',
            '9,90',
            '4,50',
            'Teinte corail',
          ],
          ['Vernis', 'Ongles', '5', '6', '', ''],
        ],
      ]);

      final rows = service.parseDocxBytes(bytes);

      expect(rows, hasLength(2));
      expect(rows[0], {
        'name': 'Rouge à lèvres',
        'category': 'Maquillage',
        'quantity': '12',
        'sellPrice': '9,90',
        'costPrice': '4,50',
        'description': 'Teinte corail',
      });
      expect(rows[1]['name'], 'Vernis');
      expect(rows[1]['costPrice'], '');
      expect(rows[1]['description'], '');
    });

    test('fait correspondre les colonnes par intitulé et non par position', () {
      final bytes = buildDocx([
        [
          ['Description', 'PRIX', 'Nom', 'Colonne inconnue', 'quantité'],
          ['Doux', '3,20', 'Savon', 'ignorée', '40'],
        ],
      ]);

      final rows = service.parseDocxBytes(bytes);

      expect(rows.single, {
        'name': 'Savon',
        'sellPrice': '3,20',
        'description': 'Doux',
        'quantity': '40',
      });
    });

    test('lève une exception claire si la colonne nom est absente', () {
      final bytes = buildDocx([
        [
          ['Référence', 'Prix'],
          ['ABC', '10'],
        ],
      ]);

      expect(
        () => service.parseDocxBytes(bytes),
        throwsA(
          isA<DocxImportException>().having(
            (e) => e.message,
            'message',
            allOf(contains("Nom de l'article"), contains('Référence')),
          ),
        ),
      );
    });

    test(
      'lève une exception claire si le document ne contient aucun tableau',
      () {
        final bytes = buildDocx(
          [],
          extraBody: '<w:p><w:r><w:t>Bonjour</w:t></w:r></w:p>',
        );

        expect(
          () => service.parseDocxBytes(bytes),
          throwsA(
            isA<DocxImportException>().having(
              (e) => e.message,
              'message',
              contains('Aucun tableau'),
            ),
          ),
        );
      },
    );

    test('lève une exception claire si le fichier n\'est pas un .docx', () {
      expect(
        () => service.parseDocxBytes(
          Uint8List.fromList(utf8.encode('pas un zip')),
        ),
        throwsA(isA<DocxImportException>()),
      );
    });

    test('parcourt toutes les tables, en sautant un en-tête répété', () {
      final bytes = buildDocx([
        [
          header,
          ['Produit 1', '', '1', '', '', ''],
        ],
        [
          header, // en-tête répété (tableau coupé en deux dans Word)
          ['Produit 2', '', '2', '', '', ''],
        ],
        [
          ['Produit 3', '', '3', '', '', ''], // table sans en-tête
        ],
      ]);

      final rows = service.parseDocxBytes(bytes);

      expect(rows.map((r) => r['name']), [
        'Produit 1',
        'Produit 2',
        'Produit 3',
      ]);
    });

    test(
      'ignore les lignes entièrement vides et complète les cellules manquantes',
      () {
        final bytes = buildDocx([
          [
            header,
            ['', '', '', '', '', ''],
            ['Court'], // ligne avec moins de cellules que l'en-tête
          ],
        ]);

        final rows = service.parseDocxBytes(bytes);

        expect(rows, hasLength(1));
        expect(rows.single['name'], 'Court');
        expect(rows.single['description'], '');
      },
    );

    test('joint les paragraphes d\'une cellule par un retour à la ligne', () {
      const xml =
          '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
          '<w:body><w:tbl>'
          '<w:tr><w:tc><w:p><w:r><w:t>Nom</w:t></w:r></w:p></w:tc>'
          '<w:tc><w:p><w:r><w:t>Description</w:t></w:r></w:p></w:tc></w:tr>'
          '<w:tr><w:tc><w:p><w:r><w:t>Crème</w:t></w:r></w:p></w:tc>'
          '<w:tc><w:p><w:r><w:t>Ligne 1</w:t></w:r></w:p>'
          '<w:p><w:r><w:t>Ligne 2</w:t></w:r></w:p></w:tc></w:tr>'
          '</w:tbl></w:body></w:document>';

      final rows = service.parseDocxBytes(buildDocxFromXml(xml));

      expect(rows.single['description'], 'Ligne 1\nLigne 2');
    });
  });

  group('parseDocxTable', () {
    test('lit un fichier .docx depuis le disque', () async {
      final dir = await Directory.systemTemp.createTemp('docx_import_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/catalogue.docx');
      await file.writeAsBytes(
        buildDocx([
          [
            header,
            ['Depuis fichier', 'Cat', '1', '2', '1', 'Desc'],
          ],
        ]),
      );

      final rows = await service.parseDocxTable(file);

      expect(rows.single['name'], 'Depuis fichier');
    });

    test('lève une DocxImportException si le fichier est introuvable', () {
      expect(
        () => service.parseDocxTable(File('n_existe_pas.docx')),
        throwsA(isA<DocxImportException>()),
      );
    });
  });
}
