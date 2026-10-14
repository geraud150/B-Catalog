import 'dart:convert';

import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/sync/catalog_auto_sync.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal, valid-looking (never verified client-side) JWT: enough for
/// [GoTrueClient.recoverSession] to accept it as a non-expired session
/// without any network round-trip, so tests can simulate "already signed
/// in" without faking the auth endpoints too.
String _fakeSessionJson() {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token =
      '${segment({'alg': 'none', 'typ': 'JWT'})}.'
      '${segment({'exp': 4102444800, 'sub': 'test-user', 'role': 'authenticated'})}.'
      'sig';
  return jsonEncode({
    'access_token': token,
    'token_type': 'bearer',
    'refresh_token': 'refresh-token',
    'user': {'id': 'test-user'},
  });
}

/// Backend just detailed enough for [CatalogAutoSync]'s purposes: the
/// catalog lookup either succeeds (an already-initialized, empty catalog —
/// nothing left for `synchronize` to do) or fails with [catalogsStatus],
/// and every other call the happy path needs answers trivially empty.
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient({this.catalogsStatus = 200});

  final int catalogsStatus;
  int catalogsRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    if (path == '/rest/v1/catalogs') {
      catalogsRequests++;
      if (catalogsStatus != 200) {
        return _json(request, {
          'message': 'simulated failure',
          'code': 'PGRST000',
        }, status: catalogsStatus);
      }
      return _json(request, {
        'id': '11111111-1111-4111-8111-111111111111',
        'initialized_at': '2026-01-01T00:00:00.000Z',
      });
    }
    if (path == '/rest/v1/rpc/claim_catalog_initialization') {
      return _json(request, [
        {'state': 'ready'},
      ]);
    }
    if (path == '/rest/v1/products') {
      return _json(request, const []);
    }
    throw UnsupportedError('Requête non simulée : ${request.method} $path');
  }

  http.StreamedResponse _json(
    http.BaseRequest request,
    Object? data, {
    int status = 200,
  }) {
    final bytes = utf8.encode(jsonEncode(data));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<SupabaseClient> _signedInClient(http.Client httpClient) async {
  final client = SupabaseClient(
    'https://fake.supabase.test',
    'sb_publishable_test',
    httpClient: httpClient,
  );
  await client.auth.recoverSession(_fakeSessionJson());
  return client;
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('ne fait rien quand aucun client Supabase n\'est configuré', () async {
    final autoSync = CatalogAutoSync(
      database: database,
      clientProvider: () => null,
    );

    await autoSync.trigger();

    expect(autoSync.lastError.value, isNull);
  });

  test(
    'mémorise un message clair en échec, et l\'efface dès que la '
    'synchronisation suivante réussit',
    () async {
      final failingBackend = _FakeHttpClient(catalogsStatus: 500);
      var client = await _signedInClient(failingBackend);
      final autoSync = CatalogAutoSync(
        database: database,
        clientProvider: () => client,
      );

      await autoSync.trigger();
      expect(autoSync.lastError.value, isNotNull);
      expect(autoSync.lastError.value, isNot(contains('PostgrestException')));

      final succeedingBackend = _FakeHttpClient();
      client = await _signedInClient(succeedingBackend);
      await autoSync.trigger();

      expect(autoSync.lastError.value, isNull);
    },
  );

  test(
    'deux déclenchements qui se chevauchent ne lancent qu\'une seule '
    'synchronisation',
    () async {
      final backend = _FakeHttpClient();
      final client = await _signedInClient(backend);
      final autoSync = CatalogAutoSync(
        database: database,
        clientProvider: () => client,
      );

      await Future.wait([autoSync.trigger(), autoSync.trigger()]);

      expect(backend.catalogsRequests, 1);
    },
  );

  test(
    'une écriture locale déclenche une synchronisation après le délai '
    'de regroupement',
    () async {
      final backend = _FakeHttpClient();
      final client = await _signedInClient(backend);
      final autoSync = CatalogAutoSync(
        database: database,
        clientProvider: () => client,
        debounceDuration: const Duration(milliseconds: 20),
      )..start();
      addTearDown(autoSync.dispose);

      await database.insertProduct(ProductsCompanion.insert(name: 'Produit'));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(backend.catalogsRequests, greaterThanOrEqualTo(1));
    },
  );
}
