import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Sélection, compression et stockage local des photos produit.
///
/// Sur Android, la sélection se fait via `image_picker` (caméra ou
/// galerie). Sur Windows Desktop, via `file_selector` (choix d'un fichier
/// image existant — pas de capture caméra native à ce stade).
class PhotoService {
  const PhotoService();

  static const _maxDimension = 1024;
  static const _jpegQuality = 80;

  Future<Uint8List?> pickFromCamera() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    return picked?.readAsBytes();
  }

  Future<Uint8List?> pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    return picked?.readAsBytes();
  }

  Future<Uint8List?> pickFromFileSystem() async {
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    return file?.readAsBytes();
  }

  /// Redimensionne [bytes] pour que son plus grand côté ne dépasse pas
  /// 1024px, l'encode en JPEG qualité ~80, puis l'enregistre dans le
  /// sous-dossier `photos` du répertoire de documents de l'application.
  ///
  /// Retourne le chemin local du fichier créé, ou `null` si les octets
  /// fournis ne sont pas une image valide.
  Future<String?> saveCompressed(
    Uint8List bytes, {
    String? sku,
    String? barcode,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final largestSide = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final resized = largestSide > _maxDimension
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? _maxDimension : null,
            height: decoded.height > decoded.width ? _maxDimension : null,
          )
        : decoded;

    final jpegBytes = img.encodeJpg(resized, quality: _jpegQuality);

    final photosDir = await _photosDirectory();
    final file = File(
      p.join(photosDir.path, '${_fileNameFor(sku, barcode)}.jpg'),
    );
    await file.writeAsBytes(jpegBytes, flush: true);
    return file.path;
  }

  Future<void> deletePhoto(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Sur Android, le répertoire de documents de l'app est déjà un espace
  /// privé sandboxé, adapté au stockage de fichiers générés par l'app.
  ///
  /// Sur Windows (et les autres plateformes desktop), ce même répertoire
  /// pointe vers le dossier "Documents" personnel et visible de
  /// l'utilisatrice : y déposer des fichiers applicatifs le pollue. On
  /// utilise donc le répertoire de support applicatif, propre à l'app et
  /// non mélangé aux vrais documents de l'utilisatrice.
  Future<Directory> _photosDirectory() async {
    final baseDir = Platform.isAndroid
        ? await getApplicationDocumentsDirectory()
        : await getApplicationSupportDirectory();

    final photosDir = Directory(p.join(baseDir.path, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  String _fileNameFor(String? sku, String? barcode) {
    final base = _firstNonEmpty([sku, barcode]) ??
        DateTime.now().microsecondsSinceEpoch.toString();
    return _sanitize(base);
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  /// Retire accents et caractères spéciaux pour obtenir un nom de fichier
  /// sûr sur tous les systèmes de fichiers.
  String _sanitize(String input) {
    const accented = 'àâäáãåèéêëìíîïòóôöõùúûüçñÀÂÄÁÃÅÈÉÊËÌÍÎÏÒÓÔÖÕÙÚÛÜÇÑ';
    const plain = 'aaaaaaeeeeiiiiooooouuuucnAAAAAAEEEEIIIIOOOOOUUUUCN';

    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final index = accented.indexOf(char);
      buffer.write(index == -1 ? char : plain[index]);
    }

    final normalized = buffer
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return normalized.isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : normalized;
  }
}
