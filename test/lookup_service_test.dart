import 'dart:convert';
import 'dart:typed_data';

import 'package:boutique_catalog/core/database/app_database.dart';
import 'package:boutique_catalog/features/lookup/lookup_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptateur Dio de test : route selon l'hôte pour simuler Open Beauty
/// Facts, Open Products Facts, Icecat et UpcItemDb sans réseau réel, avec un
/// compteur d'appels par source (le nouveau comportement interroge les 4
/// sources sauf arrêt anticipé, donc les tests doivent pouvoir distinguer
/// précisément qui a été appelé et combien de fois).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({
    this.openBeautyFactsResponse,
    this.openProductsFactsResponse,
    this.icecatResponse,
    this.icecatStatusCode = 200,
  });

  final Map<String, dynamic>? openBeautyFactsResponse;
  final Map<String, dynamic>? openProductsFactsResponse;
  final Map<String, dynamic>? icecatResponse;
  final int icecatStatusCode;

  RequestOptions? lastIcecatRequest;
  int openBeautyFactsCalls = 0;
  int openProductsFactsCalls = 0;
  int icecatCalls = 0;
  int upcItemDbCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final host = options.uri.host;
    var statusCode = 200;
    Map<String, dynamic> body;
    if (host.contains('openbeautyfacts')) {
      openBeautyFactsCalls++;
      body = openBeautyFactsResponse ?? {'status': 0};
    } else if (host.contains('openproductsfacts')) {
      openProductsFactsCalls++;
      body = openProductsFactsResponse ?? {'status': 0};
    } else if (host.contains('icecat')) {
      icecatCalls++;
      lastIcecatRequest = options;
      statusCode = icecatStatusCode;
      body = icecatResponse ?? {'data': null};
    } else if (host.contains('upcitemdb')) {
      upcItemDbCalls++;
      body = {'items': []};
    } else {
      body = {};
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Simule le téléchargement d'une image : retourne [bytes] tel quel.
class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes);

  final List<int> bytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

/// Simule un échec réseau pour tester la gestion d'erreur silencieuse.
class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    // Chaque test Icecat charge ses propres variables ; les autres n'en ont
    // pas besoin mais ne doivent pas planter si dotenv n'a jamais été
    // chargé dans ce run de tests.
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  tearDown(() => database.close());

  test(
    'Open Beauty Facts : description, sku et contenance sont extraits',
    () async {
      final adapter = _FakeAdapter(
        openBeautyFactsResponse: {
          'status': 1,
          'product': {
            'product_name': 'Crème hydratante',
            'categories': 'en:cosmetics, en:skin-care',
            'generic_name': 'Crème pour le visage',
            'producer_product_id': 'PRD-123',
            'quantity': '50 ml',
          },
        },
      );
      final service = LookupService(
        database: database,
        dio: Dio()..httpClientAdapter = adapter,
      );

      final result = await service.lookupBarcode('1234567890123');

      expect(result, isNotNull);
      expect(result!.name, 'Crème hydratante');
      expect(result.category, 'cosmetics');
      expect(result.description, 'Crème pour le visage');
      expect(result.sku, 'PRD-123');
      expect(result.optionCapacite, '50 ml');
    },
  );

  group('Icecat', () {
    test('les en-têtes api_token et content_token sont envoyés', () async {
      dotenv.loadFromString(
        envString:
            'ICECAT_USERNAME=user\n'
            'ICECAT_API_TOKEN=api-token-x\n'
            'ICECAT_CONTENT_TOKEN=content-token-y\n',
      );
      final adapter = _FakeAdapter(
        icecatResponse: {
          'data': {
            'GeneralInfo': {'Title': 'Radio Bluetooth'},
          },
        },
      );
      final service = LookupService(
        database: database,
        dio: Dio()..httpClientAdapter = adapter,
      );

      await service.lookupBarcode('999');

      final headers = adapter.lastIcecatRequest!.headers;
      expect(headers['api_token'], 'api-token-x');
      expect(headers['content_token'], 'content-token-y');
    });

    test(
      'la requête respecte le contrat de l\'API live : shopname, lang et '
      'GTIN dans l\'URL, tokens uniquement en en-têtes',
      () async {
        dotenv.loadFromString(
          envString:
              'ICECAT_USERNAME=ma-boutique\n'
              'ICECAT_API_TOKEN=api-token-x\n'
              'ICECAT_CONTENT_TOKEN=content-token-y\n',
        );
        final adapter = _FakeAdapter(
          icecatResponse: {
            'data': {
              'GeneralInfo': {'Title': 'Radio Bluetooth'},
            },
          },
        );
        final service = LookupService(
          database: database,
          dio: Dio()..httpClientAdapter = adapter,
        );

        await service.lookupBarcode('8711600775251');

        final uri = adapter.lastIcecatRequest!.uri;
        expect(uri.host, 'live.icecat.biz');
        expect(uri.path, '/api');
        final query = uri.queryParameters;
        expect(query['shopname'], 'ma-boutique');
        expect(query['lang'], 'en');
        // Casse exacte exigée par Icecat : GTIN, pas UPC / ean / barcode.
        expect(query['GTIN'], '8711600775251');
        expect(query.keys, isNot(contains('UPC')));
        expect(query.keys, isNot(contains('barcode')));
        expect(query.keys, isNot(contains('ean')));
        // Les tokens ne doivent jamais transiter par l'URL.
        expect(query.keys, isNot(contains('api_token')));
        expect(query.keys, isNot(contains('content_token')));
      },
    );

    test(
      'un 400 Icecat est absorbé (source ignorée) sans bloquer les autres '
      'sources ni lever d\'exception',
      () async {
        dotenv.loadFromString(
          envString: 'ICECAT_USERNAME=user\nICECAT_API_TOKEN=tok\n',
        );
        final adapter = _FakeAdapter(
          icecatStatusCode: 400,
          icecatResponse: {
            'statusCode': 400,
            'message': 'Missing required parameter',
          },
        );
        final service = LookupService(
          database: database,
          dio: Dio()..httpClientAdapter = adapter,
        );

        final result = await service.lookupBarcode('999');

        expect(result, isNull);
        expect(adapter.icecatCalls, 1);
        // upcitemdb, source suivante, a bien été interrogée malgré le 400.
        expect(adapter.upcItemDbCalls, 1);
      },
    );

    test(
      'sans content_token configuré, l\'en-tête n\'est simplement pas envoyé',
      () async {
        dotenv.loadFromString(
          envString: 'ICECAT_USERNAME=user\nICECAT_API_TOKEN=tok\n',
        );
        final adapter = _FakeAdapter(
          icecatResponse: {
            'data': {
              'GeneralInfo': {'Title': 'Radio Bluetooth'},
            },
          },
        );
        final service = LookupService(
          database: database,
          dio: Dio()..httpClientAdapter = adapter,
        );

        await service.lookupBarcode('999');

        expect(
          adapter.lastIcecatRequest!.headers.containsKey('content_token'),
          isFalse,
        );
      },
    );

    test(
      'description (Description.LongDesc), sku (BrandPartCode direct) et '
      'image (Image) sont extraits',
      () async {
        dotenv.loadFromString(
          envString: 'ICECAT_USERNAME=user\nICECAT_API_TOKEN=tok\n',
        );
        final adapter = _FakeAdapter(
          icecatResponse: {
            'data': {
              'GeneralInfo': {
                'Title': 'Radio Bluetooth',
                'BrandPartCode': 'BR-42',
                'Description': {'LongDesc': 'Description longue'},
              },
              'Image': {'HighPic': 'https://example.com/high.jpg'},
            },
          },
        );
        final service = LookupService(
          database: database,
          dio: Dio()..httpClientAdapter = adapter,
        );

        final result = await service.lookupBarcode('999');

        expect(result!.description, 'Description longue');
        expect(result.sku, 'BR-42');
        expect(result.imageUrl, 'https://example.com/high.jpg');
      },
    );

    test(
      'repli sur SummaryDescription.ShortDesc si Description.LongDesc est '
      'absent',
      () async {
        dotenv.loadFromString(
          envString: 'ICECAT_USERNAME=user\nICECAT_API_TOKEN=tok\n',
        );
        final adapter = _FakeAdapter(
          icecatResponse: {
            'data': {
              'GeneralInfo': {
                'Title': 'Radio Bluetooth',
                'SummaryDescription': {'ShortDesc': 'Description courte'},
              },
            },
          },
        );
        final service = LookupService(
          database: database,
          dio: Dio()..httpClientAdapter = adapter,
        );

        final result = await service.lookupBarcode('999');

        expect(result!.description, 'Description courte');
      },
    );

    test(
      'l\'ancien chemin ProductDescription (incorrect) n\'est plus utilisé',
      () async {
        dotenv.loadFromString(
          envString: 'ICECAT_USERNAME=user\nICECAT_API_TOKEN=tok\n',
        );
        final adapter = _FakeAdapter(
          icecatResponse: {
            'data': {
              'GeneralInfo': {
                'Title': 'Radio Bluetooth',
                // Ancien chemin, incorrect : ne doit plus être lu.
                'ProductDescription': {'LongDesc': 'Ne doit pas apparaître'},
              },
            },
          },
        );
        final service = LookupService(
          database: database,
          dio: Dio()..httpClientAdapter = adapter,
        );

        final result = await service.lookupBarcode('999');

        expect(result!.description, isNull);
      },
    );

    test(
      'repli sur le premier élément de Gallery si Image est absent',
      () async {
        dotenv.loadFromString(
          envString: 'ICECAT_USERNAME=user\nICECAT_API_TOKEN=tok\n',
        );
        final adapter = _FakeAdapter(
          icecatResponse: {
            'data': {
              'GeneralInfo': {'Title': 'Radio Bluetooth'},
              'Gallery': [
                {'Pic': 'https://example.com/gallery1.jpg'},
              ],
            },
          },
        );
        final service = LookupService(
          database: database,
          dio: Dio()..httpClientAdapter = adapter,
        );

        final result = await service.lookupBarcode('999');

        expect(result!.imageUrl, 'https://example.com/gallery1.jpg');
      },
    );

    test('sans identifiants Icecat configurés, la source est ignorée', () async {
      // Ni ICECAT_USERNAME ni ICECAT_API_TOKEN ne sont définis (chargés
      // vides dans setUp).
      final adapter = _FakeAdapter(
        icecatResponse: {
          'data': {
            'GeneralInfo': {'Title': 'Ne doit jamais être utilisé'},
          },
        },
      );
      final service = LookupService(
        database: database,
        dio: Dio()..httpClientAdapter = adapter,
      );

      final result = await service.lookupBarcode('999');

      expect(result, isNull);
      expect(adapter.icecatCalls, 0);
    });
  });

  group('fusion entre sources', () {
    test(
      'les 4 sources sont interrogées et chaque champ garde la première '
      'valeur non vide trouvée dans l\'ordre',
      () async {
        dotenv.loadFromString(
          envString: 'ICECAT_USERNAME=user\nICECAT_API_TOKEN=tok\n',
        );
        final adapter = _FakeAdapter(
          // Ne fournit que le nom : la catégorie doit venir d'ailleurs.
          openBeautyFactsResponse: {
            'status': 1,
            'product': {'product_name': 'Radio Bluetooth'},
          },
          // Fournit une catégorie que open_beauty_facts n'a pas donnée.
          openProductsFactsResponse: {
            'status': 1,
            'product': {'categories': 'en:electronics'},
          },
          // Fournit sku, description et image, jamais fournis avant Icecat.
          icecatResponse: {
            'data': {
              'GeneralInfo': {
                'BrandPartCode': 'BR-42',
                'Description': {'LongDesc': 'Description Icecat'},
              },
              'Image': {'HighPic': 'https://example.com/high.jpg'},
            },
          },
        );
        final service = LookupService(
          database: database,
          dio: Dio()..httpClientAdapter = adapter,
        );

        final result = await service.lookupBarcode('999');

        expect(result!.name, 'Radio Bluetooth');
        expect(result.category, 'electronics');
        expect(result.description, 'Description Icecat');
        expect(result.sku, 'BR-42');
        expect(result.imageUrl, 'https://example.com/high.jpg');
        expect(adapter.openBeautyFactsCalls, 1);
        expect(adapter.openProductsFactsCalls, 1);
        expect(adapter.icecatCalls, 1);
        // Toutes les sources ont été consultées : upcitemdb aussi, en
        // dernier recours (rien ne manquait plus à ce stade que optionCapacite,
        // que même upcitemdb ne fournit pas — donc pas d'arrêt anticipé).
        expect(adapter.upcItemDbCalls, 1);
      },
    );

    test(
      'une valeur déjà trouvée sur une source antérieure n\'est jamais '
      'écrasée par une source suivante',
      () async {
        final adapter = _FakeAdapter(
          openBeautyFactsResponse: {
            'status': 1,
            'product': {
              'product_name': 'Nom Open Beauty Facts',
              'producer_product_id': 'SKU-BEAUTY',
            },
          },
          openProductsFactsResponse: {
            'status': 1,
            'product': {
              'product_name': 'Nom Open Products Facts (ignoré)',
              'producer_product_id': 'SKU-PRODUCTS (ignoré)',
            },
          },
        );
        final service = LookupService(
          database: database,
          dio: Dio()..httpClientAdapter = adapter,
        );

        final result = await service.lookupBarcode('999');

        expect(result!.name, 'Nom Open Beauty Facts');
        expect(result.sku, 'SKU-BEAUTY');
      },
    );

    test(
      'l\'arrêt anticipé n\'a lieu que lorsque tous les champs sont remplis',
      () async {
        dotenv.loadFromString(
          envString: 'ICECAT_USERNAME=user\nICECAT_API_TOKEN=tok\n',
        );
        final adapter = _FakeAdapter(
          openBeautyFactsResponse: {
            'status': 1,
            'product': {
              'product_name': 'Produit complet',
              'categories': 'en:complet',
              'generic_name': 'Description complète',
              'producer_product_id': 'SKU-COMPLET',
              'quantity': '1 L',
            },
          },
          // Seul Icecat fournit une image dans cette implémentation : sans
          // lui, le champ imageUrl ne serait jamais rempli et les 4 sources
          // seraient interrogées.
          icecatResponse: {
            'data': {
              'GeneralInfo': {},
              'Image': {'HighPic': 'https://example.com/high.jpg'},
            },
          },
        );
        final service = LookupService(
          database: database,
          dio: Dio()..httpClientAdapter = adapter,
        );

        final result = await service.lookupBarcode('999');

        expect(result!.name, 'Produit complet');
        expect(result.imageUrl, 'https://example.com/high.jpg');
        expect(adapter.openBeautyFactsCalls, 1);
        // open_products_facts est interrogé (2e source, dans l'ordre) car
        // imageUrl manque encore après open_beauty_facts.
        expect(adapter.openProductsFactsCalls, 1);
        expect(adapter.icecatCalls, 1);
        // Tous les champs sont remplis après Icecat (3e source) : upcitemdb
        // (4e) n'est jamais interrogé.
        expect(adapter.upcItemDbCalls, 0);
      },
    );
  });

  test(
    'un lookup mis en cache restitue tous les champs enrichis sans '
    'refaire d\'appel réseau',
    () async {
      final adapter = _FakeAdapter(
        openBeautyFactsResponse: {
          'status': 1,
          'product': {
            'product_name': 'Produit test',
            'generic_name': 'Description test',
            'quantity': '100 g',
          },
        },
      );
      final service = LookupService(
        database: database,
        dio: Dio()..httpClientAdapter = adapter,
      );

      final first = await service.lookupBarcode('1111');
      expect(first!.description, 'Description test');
      expect(adapter.openBeautyFactsCalls, 1);
      expect(adapter.openProductsFactsCalls, 1);
      expect(adapter.upcItemDbCalls, 1);

      final second = await service.lookupBarcode('1111');

      expect(second!.description, 'Description test');
      expect(second.optionCapacite, '100 g');
      // Aucun appel réseau supplémentaire : le second lookup est servi
      // entièrement depuis le cache local.
      expect(adapter.openBeautyFactsCalls, 1);
      expect(adapter.openProductsFactsCalls, 1);
      expect(adapter.upcItemDbCalls, 1);
    },
  );

  group('downloadImage', () {
    test('retourne les octets en cas de succès', () async {
      final bytes = [1, 2, 3, 4];
      final service = LookupService(
        database: database,
        dio: Dio()..httpClientAdapter = _BytesAdapter(bytes),
      );

      final result = await service.downloadImage(
        'https://example.com/image.jpg',
      );

      expect(result, bytes);
    });

    test('retourne null en cas d\'échec réseau, sans lever d\'exception', () async {
      final service = LookupService(
        database: database,
        dio: Dio()..httpClientAdapter = _FailingAdapter(),
      );

      final result = await service.downloadImage(
        'https://example.com/image.jpg',
      );

      expect(result, isNull);
    });
  });
}
