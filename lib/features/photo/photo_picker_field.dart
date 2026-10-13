import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'photo_service.dart';

enum _PhotoSource { camera, gallery }

/// Champ de formulaire pour associer UNE photo à un produit.
///
/// Sur Android, propose caméra ou galerie ; sur Windows Desktop, propose la
/// sélection d'un fichier existant. Affiche un aperçu miniature une fois une
/// photo choisie, avec des boutons pour la remplacer ou la supprimer.
///
/// Apparence d'après la maquette Stitch "Ajouter un produit" (zone en
/// pointillés, vignette caméra, pastille "Choisir une image"). La maquette
/// proposait aussi des vignettes "autres angles (max 4)" : non reprises,
/// l'app ne gère qu'une seule photo par produit.
class PhotoPickerField extends StatefulWidget {
  const PhotoPickerField({
    super.key,
    required this.photoPath,
    required this.onChanged,
    required this.skuProvider,
    required this.barcodeProvider,
    this.photoService = const PhotoService(),
  });

  final String? photoPath;
  final ValueChanged<String?> onChanged;
  final String? Function() skuProvider;
  final String? Function() barcodeProvider;
  final PhotoService photoService;

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  bool _isProcessing = false;

  Future<void> _pickAndSave(Future<Uint8List?> Function() pick) async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await pick();
      if (bytes == null) return;

      final savedPath = await widget.photoService.saveCompressed(
        bytes,
        sku: widget.skuProvider(),
        barcode: widget.barcodeProvider(),
      );
      if (savedPath == null) return;

      final previousPath = widget.photoPath;
      widget.onChanged(savedPath);
      if (previousPath != null && previousPath != savedPath) {
        await widget.photoService.deletePhoto(previousPath);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _choosePhoto() async {
    if (Platform.isAndroid) {
      final source = await showModalBottomSheet<_PhotoSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir depuis la galerie'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == _PhotoSource.camera) {
        await _pickAndSave(widget.photoService.pickFromCamera);
      } else if (source == _PhotoSource.gallery) {
        await _pickAndSave(widget.photoService.pickFromGallery);
      }
    } else {
      await _pickAndSave(widget.photoService.pickFromFileSystem);
    }
  }

  Future<void> _removePhoto() async {
    final path = widget.photoPath;
    widget.onChanged(null);
    if (path != null) {
      await widget.photoService.deletePhoto(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.photoPath != null && widget.photoPath!.isNotEmpty;

    if (_isProcessing) {
      return const _DropZone(
        child: SizedBox(
          height: 120,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (hasPhoto) {
      return _DropZone(
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.photoPath!),
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  color: AppPalette.surface,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppPalette.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PillButton(
                    icon: Icons.sync_alt,
                    label: 'Remplacer',
                    onPressed: _choosePhoto,
                  ),
                  _PillButton(
                    icon: Icons.delete_outline,
                    label: 'Supprimer',
                    foreground: AppPalette.rose700,
                    onPressed: _removePhoto,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isAndroid = Platform.isAndroid;
    return _DropZone(
      onTap: _choosePhoto,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppPalette.border.withValues(alpha: 0.6),
              ),
              boxShadow: AppPalette.softShadow,
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              color: AppPalette.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          _PillButton(
            icon: Icons.add,
            label: isAndroid ? 'Ajouter une photo' : 'Choisir une image',
            onPressed: _choosePhoto,
          ),
          const SizedBox(height: 6),
          Text(
            isAndroid
                ? 'Prendre une photo ou choisir dans la galerie'
                : 'Sélectionner un fichier image sur cet ordinateur',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppPalette.muted),
          ),
          const SizedBox(height: 4),
          Text(
            'JPG, PNG, WebP ou BMP · compressée automatiquement',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: AppPalette.muted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zone en pointillés sur fond dégradé, cliquable si [onTap] est fourni.
class _DropZone extends StatelessWidget {
  const _DropZone({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppPalette.border,
        radius: 16,
        strokeWidth: 2,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFAF8FC), Color(0x99F3EFF8)],
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton-pastille blanc ("+ Choisir une image", "Remplacer"...).
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.foreground = AppPalette.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: AppPalette.surface,
        side: const BorderSide(color: AppPalette.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    );
  }
}

/// Bordure arrondie en pointillés (Flutter n'en propose pas nativement).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  static const dashLength = 6.0;
  static const gapLength = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(strokeWidth / 2),
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      strokeWidth != oldDelegate.strokeWidth;
}
