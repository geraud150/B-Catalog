import 'package:flutter/material.dart';

import 'barcode_scanner_service.dart';

/// Bouton réutilisable qui déclenche le scan de code-barres adapté à la
/// plateforme et transmet le résultat via [onScanned].
class BarcodeScanButton extends StatelessWidget {
  const BarcodeScanButton({
    super.key,
    required this.onScanned,
    this.scannerService = const BarcodeScannerService(),
    this.style,
  });

  final ValueChanged<String> onScanned;
  final BarcodeScannerService scannerService;

  /// Style optionnel (couleurs, forme) pour intégrer le bouton dans un champ
  /// de saisie ; à défaut, apparence tonale par défaut du thème.
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Scanner un code-barres',
      icon: const Icon(Icons.qr_code_scanner),
      style: style,
      onPressed: () async {
        final result = await scannerService.scan(context);
        if (result != null && result.isNotEmpty) {
          onScanned(result);
        }
      },
    );
  }
}
