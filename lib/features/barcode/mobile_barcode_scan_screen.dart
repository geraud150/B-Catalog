import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_palette.dart';

/// Écran plein écran utilisant la caméra pour scanner un code-barres.
///
/// Se ferme automatiquement (en renvoyant la valeur scannée via
/// [Navigator.pop]) dès qu'un code-barres est détecté.
///
/// Aucune maquette Stitch n'existe pour cet écran : l'habillage reprend la
/// charte déjà établie (boutons ronds, coins arrondis, violet de marque) sur
/// un fond sombre imposé par l'aperçu caméra, sans ajouter de
/// fonctionnalité.
class MobileBarcodeScanScreen extends StatefulWidget {
  const MobileBarcodeScanScreen({super.key});

  @override
  State<MobileBarcodeScanScreen> createState() =>
      _MobileBarcodeScanScreenState();
}

class _MobileBarcodeScanScreenState extends State<MobileBarcodeScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    // Uniquement les formats de codes-barres produit : un QR code (ou tout
    // autre format 2D) n'est pas détecté et ne peut donc plus être confondu
    // avec un code-barres produit.
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.itf14,
      BarcodeFormat.codabar,
    ],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: _OverlayButton(
              icon: Icons.arrow_back,
              tooltip: 'Fermer le scanner',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        title: const Text(
          'Scanner un code-barres',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, state, child) {
                  final torchOn = state.torchState == TorchState.on;
                  return _OverlayButton(
                    icon: torchOn ? Icons.flash_on : Icons.flash_off,
                    tooltip: torchOn ? 'Éteindre la lampe' : 'Allumer la lampe',
                    active: torchOn,
                    onTap: () => _controller.toggleTorch(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Cadre de visée : les coins arrondis violets reprennent la charte
          // des autres écrans.
          const Center(child: _ScanFrame()),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Alignez le code-barres dans le cadre : la fiche se ferme '
                  'dès qu\'il est reconnu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton rond translucide posé sur l'aperçu caméra.
class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? AppPalette.brand600
            : Colors.black.withValues(alpha: 0.45),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Cadre de visée aux quatre coins violets.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 180,
      child: Stack(
        children: [
          for (final alignment in [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(alignment: alignment, child: _Corner(alignment: alignment)),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppPalette.brand300, width: 3);
    const radius = Radius.circular(12);
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? side : BorderSide.none,
          bottom: isTop ? BorderSide.none : side,
          left: isLeft ? side : BorderSide.none,
          right: isLeft ? BorderSide.none : side,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? radius : Radius.zero,
          topRight: isTop && !isLeft ? radius : Radius.zero,
          bottomLeft: !isTop && isLeft ? radius : Radius.zero,
          bottomRight: !isTop && !isLeft ? radius : Radius.zero,
        ),
      ),
    );
  }
}

extension on List<Barcode> {
  Barcode? get firstOrNull => isEmpty ? null : first;
}
