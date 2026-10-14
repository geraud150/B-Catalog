import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static SupabaseClient? get client =>
      _initialized ? Supabase.instance.client : null;

  static bool _initialized = false;

  static Future<bool> initialize() async {
    final url = dotenv.env['SUPABASE_URL']?.trim();
    final publishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim();
    final parsedUrl = url == null ? null : Uri.tryParse(url);

    if (parsedUrl == null ||
        parsedUrl.scheme != 'https' ||
        parsedUrl.host.isEmpty ||
        publishableKey == null ||
        !publishableKey.startsWith('sb_publishable_')) {
      debugPrint(
        '[BoutiqueCatalog] Supabase non configuré ; le catalogue local reste disponible.',
      );
      return false;
    }

    try {
      await Supabase.initialize(
        url: parsedUrl.toString(),
        publishableKey: publishableKey,
      );
      _initialized = true;
      return true;
    } catch (error) {
      debugPrint('[BoutiqueCatalog] Initialisation Supabase ignorée : $error');
      return false;
    }
  }
}
