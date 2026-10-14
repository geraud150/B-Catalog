import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate, TableUpdateQuery;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:supabase_flutter/supabase_flutter.dart' hide TableUpdate;

import '../../core/database/app_database.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import 'catalog_sync_service.dart';

/// Returns the client to synchronize with, or null when Supabase was never
/// configured on this installation. Injectable so tests do not depend on
/// [SupabaseBootstrap]'s real, process-wide client.
typedef SupabaseClientProvider = SupabaseClient? Function();

/// Runs [CatalogSyncService.synchronize] in the background, without a
/// button: once shortly after the app starts, again whenever it returns to
/// the foreground, and a while after a local write settles down. Does
/// nothing when nobody has signed in to the shared catalog on this device.
///
/// The manual "Synchroniser maintenant" screen stays independent of this
/// controller: it is not replaced, only complemented.
class CatalogAutoSync {
  CatalogAutoSync({
    required this.database,
    SupabaseClientProvider? clientProvider,
    this.debounceDuration = const Duration(seconds: 8),
  }) : _clientProvider = clientProvider ?? (() => SupabaseBootstrap.client);

  final AppDatabase database;
  final SupabaseClientProvider _clientProvider;

  /// How long to wait, after the last local write, before syncing.
  final Duration debounceDuration;

  /// Message of the last automatic sync that failed, for a non-intrusive
  /// indicator to show. Cleared on the next successful sync; null before the
  /// first run, or once it stops failing.
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  bool _running = false;
  Timer? _debounce;
  StreamSubscription<Set<TableUpdate>>? _subscription;

  /// Starts watching local product writes to schedule a debounced sync after
  /// each one settles. Call once, typically when the app's root widget is
  /// built; [dispose] stops it.
  void start() {
    _subscription ??= database
        .tableUpdates(TableUpdateQuery.onTable(database.products))
        .listen((_) {
          _debounce?.cancel();
          _debounce = Timer(debounceDuration, trigger);
        });
  }

  /// Runs a sync now, unless one is already running or nobody has signed in
  /// to the shared catalog on this device. Safe to call as often as wanted:
  /// an overlapping call is ignored rather than queued, since the next
  /// natural trigger (resume, the next local write) picks up anything left
  /// pending.
  Future<void> trigger() async {
    final client = _clientProvider();
    if (client == null || client.auth.currentSession == null) return;
    if (_running) return;

    _running = true;
    try {
      await CatalogSyncService(
        database: database,
        client: client,
      ).synchronize();
      lastError.value = null;
    } catch (error) {
      lastError.value = describeCatalogSyncError(error);
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _debounce?.cancel();
    unawaited(_subscription?.cancel());
    lastError.dispose();
  }
}
