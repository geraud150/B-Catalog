import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'desktop_barcode_scan_dialog.dart';
import 'mobile_barcode_scan_screen.dart';

/// Service de scan de code-barres qui adapte son comportement à la
/// plateforme : caméra plein écran sur Android, saisie clavier/douchette
/// dans une boîte de dialogue sur Windows Desktop.
class BarcodeScannerService {
  const BarcodeScannerService();

  Future<String?> scan(BuildContext context) {
    if (Platform.isAndroid) {
      return Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const MobileBarcodeScanScreen()),
      );
    }
    return showDialog<String>(
      context: context,
      builder: (_) => const DesktopBarcodeScanDialog(),
    );
  }
}
