import 'dart:convert' show JsonEncoder;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/database/app_database.dart';

/// Résultat d'une recherche de code-barres, quelle que soit la ou les
/// sources qui l'ont fourni (cache local inclus).
class LookupResult {
  const LookupResult({
    required this.source,
    this.name,
    this.category,
    this.description,
    this.sku,
    this.optionCapacite,
    this.imageUrl,
  });

  final String source;
  final String? name;
  final String? category;
  final String? description;
  final String? sku;
  final String? optionCapacite;
  final String? imageUrl;

  bool get isExploitable =>
      (name != null && name!.trim().isNotEmpty) ||
      (category != null && category!.trim().isNotEmpty);

  @override
  String toString() =>
      'LookupResult('
      'source: $source, '
      'name: ${_quote(name)}, '
      'category: ${_quote(category)}, '
      'description: ${_quote(description)}, '
      'sku: ${_quote(sku)}, '
      'optionCapacite: ${_quote(optionCapacite)}, '
      'imageUrl: ${_quote(imageUrl)})';

  /// Distingue visuellement `null` d'une chaîne vide ou d'espaces dans les
  /// logs, ce qui est précisément ce qu'on cherche à diagnostiquer.
  static String _quote(String? value) => value == null ? 'null' : '"$value"';
}

/// Recherche automatique d'informations produit (nom, catégorie, description,
/// SKU, contenance, photo) à partir d'un code-barres.
///
/// Contrairement à une simple cascade qui s'arrêterait à la première source
/// exploitable, les 4 sources sont interrogées dans l'ordre et leurs champs
/// sont fusionnés : pour chaque champ, la première valeur non vide trouvée
/// en parcourant les sources est conservée. On n'arrête la boucle plus tôt
/// que si toutes les sources ont déjà été interrogées, ou si tous les
/// champs sont déjà remplis (inutile de continuer dans ce cas).
///
/// Un cache local ([AppDatabase.getCachedLookup]) évite de refaire ces
/// appels réseau pour un code-barres déjà résolu.
class LookupService {
  LookupService({required this.database, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: _timeout,
              sendTimeout: _timeout,
              receiveTimeout: _timeout,
            ),
          );

  final AppDatabase database;
  final Dio _dio;

  static const _timeout = Duration(seconds: 5);

  Future<LookupResult?> lookupBarcode(String barcode) async {
    final cached = await database.getCachedLookup(barcode);
    if (cached != null) {
      final fromCache = LookupResult(
        source: cached.source,
        name: cached.name,
        category: cached.category,
        description: cached.description,
        sku: cached.sku,
        optionCapacite: cached.optionCapacite,
        imageUrl: cached.imageUrl,
      );
      if (fromCache.isExploitable) {
        if (kDebugMode) {
          debugPrint('[LookupService] $barcode · servi depuis le cache local');
          debugPrint('[LookupService] $barcode · résultat final : $fromCache');
        }
        return fromCache;
      }
      // Une ligne de cache sans nom ni catégorie (héritée d'une ancienne
      // version) masquerait définitivement les sources externes : on
      // l'ignore et on réinterroge comme si le cache était vide.
      if (kDebugMode) {
        debugPrint(
          '[LookupService] $barcode · cache local ignoré (non exploitable) : '
          '$fromCache',
        );
      }
    }

    final sourceLookups = <(String, Future<(LookupResult?, String)> Function())>[
      (
        'open_beauty_facts',
        () => _lookupOpenFactsApi(
          source: 'open_beauty_facts',
          uri: Uri.https(
            'world.openbeautyfacts.org',
            '/api/v2/product/$barcode.json',
          ),
        ),
      ),
      (
        'open_products_facts',
        () => _lookupOpenFactsApi(
          source: 'open_products_facts',
          uri: Uri.https(
            'world.openproductsfacts.org',
            '/api/v2/product/$barcode.json',
          ),
        ),
      ),
      ('icecat', () => _lookupIcecat(barcode)),
      ('upcitemdb', () => _lookupUpcItemDb(barcode)),
    ];

    String? name;
    String? category;
    String? description;
    String? sku;
    String? optionCapacite;
    String? imageUrl;
    final contributingSources = <String>[];

    for (final (sourceName, lookup) in sourceLookups) {
      final (result, status) = await lookup();
      _logDiagnostic(
        barcode: barcode,
        sourceName: sourceName,
        status: status,
        result: result,
      );

      if (result != null) {
        var contributed = false;
        if (!_isFilled(name) && _isFilled(result.name)) {
          name = result.name;
          contributed = true;
        }
        if (!_isFilled(category) && _isFilled(result.category)) {
          category = result.category;
          contributed = true;
        }
        if (!_isFilled(description) && _isFilled(result.description)) {
          description = result.description;
          contributed = true;
        }
        if (!_isFilled(sku) && _isFilled(result.sku)) {
          sku = result.sku;
          contributed = true;
        }
        if (!_isFilled(optionCapacite) && _isFilled(result.optionCapacite)) {
          optionCapacite = result.optionCapacite;
          contributed = true;
        }
        if (!_isFilled(imageUrl) && _isFilled(result.imageUrl)) {
          imageUrl = result.imageUrl;
          contributed = true;
        }
        if (contributed) contributingSources.add(sourceName);
      }

      final allFieldsFilled =
          _isFilled(name) &&
          _isFilled(category) &&
          _isFilled(description) &&
          _isFilled(sku) &&
          _isFilled(optionCapacite) &&
          _isFilled(imageUrl);
      if (allFieldsFilled) break;
    }

    final merged = LookupResult(
      source: contributingSources.join('+'),
      name: name,
      category: category,
      description: description,
      sku: sku,
      optionCapacite: optionCapacite,
      imageUrl: imageUrl,
    );
    if (kDebugMode) {
      debugPrint(
        '[LookupService] $barcode · fusion des sources terminée · '
        'exploitable : ${merged.isExploitable}',
      );
      debugPrint('[LookupService] $barcode · résultat final : $merged');
    }
    if (!merged.isExploitable) return null;

    await database.cacheLookupResult(
      barcode: barcode,
      source: merged.source,
      name: merged.name,
      category: merged.category,
      description: merged.description,
      sku: merged.sku,
      optionCapacite: merged.optionCapacite,
      imageUrl: merged.imageUrl,
    );
    return merged;
  }

  /// Télécharge l'image trouvée par une recherche externe (ex. `imageUrl`
  /// Icecat). Retourne `null` en cas d'échec (réseau, URL invalide...) sans
  /// jamais lever d'exception.
  Future<Uint8List?> downloadImage(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }

  /// Open Beauty Facts et Open Products Facts partagent le même format de
  /// réponse (API Open Food Facts v2).
  ///
  /// Retourne toujours les champs trouvés, même si le produit n'a ni nom ni
  /// catégorie exploitables : c'est à l'appelant ([lookupBarcode]) de juger
  /// de l'exploitabilité du résultat fusionné entre toutes les sources.
  Future<(LookupResult?, String)> _lookupOpenFactsApi({
    required String source,
    required Uri uri,
  }) async {
    try {
      final response = await _dio.getUri(uri);
      final status = _statusLabel(response.statusCode);
      final data = response.data;
      if (data is! Map || data['status'] != 1) return (null, status);

      final product = data['product'];
      if (product is! Map) return (null, status);

      return (
        LookupResult(
          source: source,
          name: _asTrimmedString(product['product_name']),
          category: _cleanCategory(_asTrimmedString(product['categories'])),
          description: _asTrimmedString(product['generic_name']),
          // Rarement rempli côté producteurs : à ne jamais traiter comme
          // une source de SKU fiable, seulement comme un complément
          // d'opportunité.
          sku: _asTrimmedString(product['producer_product_id']),
          optionCapacite: _asTrimmedString(product['quantity']),
        ),
        status,
      );
    } on DioException catch (e) {
      return (null, _dioErrorLabel(e));
    } catch (e) {
      return (null, 'erreur: $e');
    }
  }

  /// Interroge l'API live d'Icecat. Seul le token API (jamais le mot de
  /// passe du compte) est utilisé pour s'authentifier ; le content_token
  /// donne accès au contenu enrichi (description longue, images).
  ///
  /// Contrat de l'API live (https://live.icecat.biz/api) :
  /// - `shopname` (le nom d'utilisateur Icecat) et `lang` sont obligatoires
  ///   dans l'URL ;
  /// - le code-barres se passe via `GTIN` (casse exacte), pas `UPC`/`EAN` ;
  /// - `api_token` et `content_token` sont des en-têtes HTTP, jamais des
  ///   paramètres d'URL.
  /// Toute autre forme est rejetée avec un 400.
  ///
  /// Le schéma exact de la réponse Icecat peut varier selon le produit et le
  /// niveau de contenu disponible ; toute divergence est traitée comme une
  /// absence de résultat plutôt que comme une erreur.
  Future<(LookupResult?, String)> _lookupIcecat(String barcode) async {
    final username = dotenv.env['ICECAT_USERNAME'];
    final apiToken = dotenv.env['ICECAT_API_TOKEN'];
    final contentToken = dotenv.env['ICECAT_CONTENT_TOKEN'];
    if (username == null ||
        username.isEmpty ||
        apiToken == null ||
        apiToken.isEmpty) {
      return (null, 'non configuré');
    }

    final queryParameters = <String, String>{
      'shopname': username,
      'lang': 'en',
      'GTIN': barcode,
    };
    final headers = <String, String>{
      'api_token': apiToken,
      if (contentToken != null && contentToken.isNotEmpty)
        'content_token': contentToken,
    };
    _logIcecatRequest(
      uri: Uri.https(_icecatHost, _icecatPath, queryParameters),
      headers: headers,
    );

    try {
      final response = await _dio.get(
        'https://$_icecatHost$_icecatPath',
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      final status = _statusLabel(response.statusCode);
      if (response.statusCode != 200) {
        _logIcecatErrorBody(response.statusCode, response.data);
      }
      final data = response.data;
      if (data is! Map) return (null, status);

      final productData = data['data'];
      if (productData is! Map) return (null, status);

      final generalInfo = productData['GeneralInfo'];
      if (generalInfo is! Map) return (null, status);

      final name = _asTrimmedString(
        generalInfo['Title'] ?? generalInfo['ProductName'],
      );

      String? category;
      final categoryField = generalInfo['Category'];
      if (categoryField is Map) {
        final nameField = categoryField['Name'];
        if (nameField is Map) {
          category = _asTrimmedString(nameField['Value']);
        }
      }

      // Description[@LongDesc] — pas ProductDescription, qui n'existe pas
      // dans le schéma réel de l'API live. Repli sur le résumé court si la
      // description longue est absente.
      String? description;
      final descriptionField = generalInfo['Description'];
      if (descriptionField is Map) {
        description = _asTrimmedString(descriptionField['LongDesc']);
      }
      if (description == null) {
        final summaryField = generalInfo['SummaryDescription'];
        if (summaryField is Map) {
          description = _asTrimmedString(summaryField['ShortDesc']);
        }
      }

      // BrandPartCode est un champ direct de GeneralInfo, pas un sous-objet.
      final sku = _asTrimmedString(generalInfo['BrandPartCode']);

      var imageUrl = _asTrimmedString(_pictureUrlFrom(productData['Image']));
      if (imageUrl == null) {
        final gallery = productData['Gallery'];
        if (gallery is List && gallery.isNotEmpty) {
          imageUrl = _asTrimmedString(_pictureUrlFrom(gallery.first));
        }
      }

      return (
        LookupResult(
          source: 'icecat',
          name: name,
          category: category,
          description: description,
          sku: sku,
          imageUrl: imageUrl,
        ),
        status,
      );
    } on DioException catch (e) {
      // Dio lève une exception pour tout statut hors 2xx : c'est ici
      // qu'atterrit le 400 d'Icecat, avec le corps de la réponse dedans.
      final errorResponse = e.response;
      if (errorResponse != null) {
        _logIcecatErrorBody(errorResponse.statusCode, errorResponse.data);
      } else if (kDebugMode) {
        debugPrint(
          '[LookupService][icecat] aucune réponse HTTP (${e.type.name}) : '
          '${e.message}',
        );
      }
      return (null, _dioErrorLabel(e));
    } catch (e) {
      return (null, 'erreur: $e');
    }
  }

  static const _icecatHost = 'live.icecat.biz';
  static const _icecatPath = '/api';

  /// Trace la requête Icecat telle qu'elle va partir : URL complète et noms
  /// des en-têtes. La valeur de `api_token` n'est jamais affichée, seule sa
  /// présence (et sa longueur, pour repérer une variable d'env tronquée).
  void _logIcecatRequest({
    required Uri uri,
    required Map<String, String> headers,
  }) {
    if (!kDebugMode) return;

    final apiToken = headers['api_token'];
    final query = uri.queryParameters;
    debugPrint('[LookupService][icecat] GET $uri');
    debugPrint(
      '[LookupService][icecat] en-têtes envoyés : ${headers.keys.join(", ")} · '
      'api_token présent : ${apiToken != null && apiToken.isNotEmpty}'
      '${apiToken == null ? "" : " (${apiToken.length} caractères)"}',
    );
    debugPrint(
      '[LookupService][icecat] vérifications · '
      'lang : ${query.containsKey("lang")} · '
      'shopname : ${query.containsKey("shopname")} · '
      'GTIN : ${query.containsKey("GTIN")} · '
      'api_token dans l\'URL (ne doit PAS l\'être) : '
      '${query.containsKey("api_token")}',
    );
  }

  /// Affiche le corps complet renvoyé par Icecat quand le statut n'est pas
  /// 200 : c'est là que se trouve le message d'erreur explicite
  /// ("shopname is required", "GTIN not found", token invalide...).
  void _logIcecatErrorBody(int? statusCode, Object? body) {
    if (!kDebugMode) return;

    String text;
    if (body == null) {
      text = '(corps vide)';
    } else if (body is Map || body is List) {
      try {
        text = const JsonEncoder.withIndent('  ').convert(body);
      } catch (_) {
        text = body.toString();
      }
    } else {
      text = body.toString();
    }
    debugPrint(
      '[LookupService][icecat] HTTP ${statusCode ?? "?"} · corps complet de '
      'la réponse :\n$text',
    );
  }

  /// L'URL d'image se trouve sous des clés différentes selon qu'il s'agit du
  /// champ `Image` (objet unique) ou d'un élément de `Gallery` (liste) ;
  /// on prend la plus grande résolution disponible.
  Object? _pictureUrlFrom(Object? imageField) {
    if (imageField is String) return imageField;
    if (imageField is Map) {
      return imageField['HighPic'] ??
          imageField['Pic'] ??
          imageField['Pic500x500'] ??
          imageField['URL'];
    }
    return null;
  }

  Future<(LookupResult?, String)> _lookupUpcItemDb(String barcode) async {
    try {
      final response = await _dio.get(
        'https://api.upcitemdb.com/prod/trial/lookup',
        queryParameters: {'upc': barcode},
      );
      final status = _statusLabel(response.statusCode);
      final data = response.data;
      if (data is! Map) return (null, status);

      final items = data['items'];
      if (items is! List || items.isEmpty) return (null, status);

      final first = items.first;
      if (first is! Map) return (null, status);

      return (
        LookupResult(
          source: 'upcitemdb',
          name: _asTrimmedString(first['title']),
          category: _asTrimmedString(first['category']),
        ),
        status,
      );
    } on DioException catch (e) {
      return (null, _dioErrorLabel(e));
    } catch (e) {
      return (null, 'erreur: $e');
    }
  }

  bool _isFilled(String? value) => value != null && value.trim().isNotEmpty;

  String? _asTrimmedString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Les catégories Open (Beauty|Products) Facts arrivent sous forme d'une
  /// liste séparée par des virgules, avec un préfixe de langue optionnel
  /// (ex. "en:cosmetics, en:skin-care"). On ne garde que la première,
  /// débarrassée de son préfixe.
  String? _cleanCategory(String? raw) {
    if (raw == null) return null;
    final first = raw.split(',').first.trim();
    if (first.isEmpty) return null;

    final colonIndex = first.indexOf(':');
    if (colonIndex > 0 && colonIndex < 4) {
      return first.substring(colonIndex + 1).trim();
    }
    return first;
  }

  String _statusLabel(int? statusCode) =>
      statusCode == null ? 'réponse sans code' : '$statusCode';

  String _dioErrorLabel(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode != null) return '$statusCode';
    return 'erreur réseau (${e.type.name})';
  }

  /// Log de diagnostic temporaire (mode debug uniquement) : pour un
  /// code-barres donné, indique par source si elle a répondu et quels
  /// champs elle a effectivement réussi à extraire.
  void _logDiagnostic({
    required String barcode,
    required String sourceName,
    required String status,
    required LookupResult? result,
  }) {
    if (!kDebugMode) return;

    final fields = <String>[
      if (_isFilled(result?.name)) 'name',
      if (_isFilled(result?.category)) 'category',
      if (_isFilled(result?.description)) 'description',
      if (_isFilled(result?.sku)) 'sku',
      if (_isFilled(result?.optionCapacite)) 'optionCapacite',
      if (_isFilled(result?.imageUrl)) 'imageUrl',
    ];

    debugPrint(
      '[LookupService] $barcode · $sourceName · $status · '
      'champs extraits : ${fields.isEmpty ? "aucun" : fields.join(", ")}',
    );
  }
}
