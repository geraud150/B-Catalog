import 'package:flutter/material.dart';
import 'package:universal_barcode_scanner/universal_barcode_scanner.dart';

import '../../core/theme/app_palette.dart';

/// Boîte de dialogue de saisie de code-barres pour Windows Desktop.
///
/// Un champ de texte auto-focus reçoit soit la frappe d'une douchette
/// USB/Bluetooth (qui tape le code puis simule la touche Entrée), soit une
/// saisie manuelle au clavier validée par Entrée. Une troisième option ouvre
/// la webcam sous Windows sans modifier ces deux parcours.
///
/// Aucune maquette Stitch n'existe pour cet écran : l'habillage reprend la
/// charte déjà établie (violet de marque, coins arrondis, champs à fond très
/// clair) sans ajouter de fonctionnalité.
class DesktopBarcodeScanDialog extends StatefulWidget {
  const DesktopBarcodeScanDialog({super.key});

  @override
  State<DesktopBarcodeScanDialog> createState() =>
      _DesktopBarcodeScanDialogState();
}

class _DesktopBarcodeScanDialogState extends State<DesktopBarcodeScanDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isOpeningWebcam = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  Future<void> _scanWithWebcam() async {
    if (_isOpeningWebcam) return;
    setState(() => _isOpeningWebcam = true);

    try {
      final value = await UniversalBarcodeScanner.scan(
        context,
        // Les mêmes familles 1D que le scanner mobile : pas de QR code dans
        // un champ destiné aux codes produits.
        scanFormat: ScanFormat.onlyBarcode,
        scanWindow: ScanWindow.wide,
        lineColor: AppPalette.primary,
        flip: false,
        bar: const ScannerBar(
          title: 'Scanner avec la webcam',
          centerTitle: true,
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          cancelLabel: 'Fermer le scanner webcam',
        ),
        labels: ScannerLabels.french,
        // Permet de sélectionner l'autre caméra lorsqu'un PC en expose
        // plusieurs (webcam USB, caméra intégrée, etc.).
        buttons: const <ScannerButton>{
          ScannerButton.zoom,
          ScannerButton.switchCamera,
        },
      );
      if (!mounted || value == null || value.trim().isEmpty) return;
      Navigator.of(context).pop(value.trim());
    } finally {
      if (mounted) {
        setState(() => _isOpeningWebcam = false);
        _focusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return Dialog(
      backgroundColor: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppPalette.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppPalette.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: AppPalette.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Scannez ou tapez le code-barres',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Utilisez la douchette, ou saisissez le code au clavier puis '
                'appuyez sur Entrée.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppPalette.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: ['Consolas', 'Courier New'],
                  fontSize: 15,
                  color: AppPalette.text,
                ),
                decoration: InputDecoration(
                  hintText: 'ex. 3760123456789',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppPalette.muted.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: AppPalette.fieldBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: border(AppPalette.border),
                  focusedBorder: border(AppPalette.primary, 1.5),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isOpeningWebcam ? null : _scanWithWebcam,
                icon: _isOpeningWebcam
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.videocam_outlined),
                label: Text(
                  _isOpeningWebcam
                      ? 'Ouverture de la webcam…'
                      : 'Scanner avec la webcam',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.primary,
                  minimumSize: const Size.fromHeight(46),
                  side: const BorderSide(color: AppPalette.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Autorisez l’accès à la caméra lorsqu’il est demandé.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppPalette.muted),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: AppPalette.slate100,
                        foregroundColor: AppPalette.slate700,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Valider'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
