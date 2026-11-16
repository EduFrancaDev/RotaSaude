import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/repositories/health_unit_parser.dart';
import 'package:rotasaude/services/api_config.dart';

enum HealthApiFailureKind {
  /// Sem rede, servidor inalcançável ou falha de conexão.
  connection,

  /// A requisição excedeu o tempo limite.
  timeout,

  /// HTTP 4xx (ou outro status inesperado fora de 2xx e 5xx).
  client,

  /// HTTP 5xx.
  server,

  /// Resposta 2xx fora do contrato (JSON inválido ou campos ausentes).
  invalidResponse,
}

class HealthApiException implements Exception {
  const HealthApiException(this.kind, this.message, {this.statusCode});

  final HealthApiFailureKind kind;

  /// Detalhe técnico para diagnóstico; não é texto de interface.
  final String message;
  final int? statusCode;

  @override
  String toString() => 'HealthApiException(${kind.name}): $message';
}

/// Fonte de dados das unidades consumida pelas telas.
abstract interface class HealthUnitRepository {
  /// Unidades ativas; `city` aplica o filtro `?city=` da API.
  Future<List<HealthUnit>> fetchUnits({String? city});

  Future<HealthUnit> fetchUnit(String id);

  /// Nomes dos serviços cadastrados.
  Future<List<String>> fetchServices();

  void close();
}

/// Consulta somente os endpoints públicos de leitura da API v1. A API de
/// ingestão é exclusiva dos estabelecimentos e não é usada pelo app.
class ApiHealthUnitRepository implements HealthUnitRepository {
  ApiHealthUnitRepository({
    http.Client? client,
    Uri? baseUri,
    this.timeout = ApiConfig.requestTimeout,
    this.pageSize = 100,
    this.maxPages = 50,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _baseUri = baseUri ?? ApiConfig.baseUri;

  final Duration timeout;

  /// Itens por página pedidos à API (o máximo aceito pelo backend é 100).
  final int pageSize;

  /// Limite de páginas seguidas, para não percorrer `next` indefinidamente.
  final int maxPages;

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;

  @override
  Future<List<HealthUnit>> fetchUnits({String? city}) async {
    final results = await _fetchAllPages(
      _endpoint('units/', {
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        'page_size': '$pageSize',
      }),
    );
    return _parseAll(results, parseHealthUnit);
  }

  @override
  Future<HealthUnit> fetchUnit(String id) async {
    final body = await _getJson(_endpoint('units/${Uri.encodeComponent(id)}/'));
    return _parse(body, parseHealthUnit);
  }

  @override
  Future<List<String>> fetchServices() async {
    final results = await _fetchAllPages(
      _endpoint('services/', {'page_size': '$pageSize'}),
    );
    return _parseAll(results, parseServiceName);
  }

  @override
  void close() {
    if (_ownsClient) _client.close();
  }

  Uri _endpoint(String path, [Map<String, String>? query]) {
    final base = _baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    return _baseUri.replace(path: '$base/api/v1/$path', queryParameters: query);
  }

  /// Segue `next` até o fim. Cada URL `next` é reaplicada ao host configurado
  /// no app, pois o backend a monta com o `Host` da requisição (que pode ser
  /// um proxy ou túnel) e o app só deve falar com a URL base configurada.
  Future<List<Object?>> _fetchAllPages(Uri first) async {
    final results = <Object?>[];
    final visited = <String>{};
    Uri? url = first;
    while (url != null) {
      if (!visited.add(url.toString()) || visited.length > maxPages) {
        throw const HealthApiException(
          HealthApiFailureKind.invalidResponse,
          'Paginação excedeu o limite ou entrou em ciclo.',
        );
      }
      final body = await _getJson(url);
      if (body is! Map<String, dynamic> || body['results'] is! List<dynamic>) {
        throw const HealthApiException(
          HealthApiFailureKind.invalidResponse,
          'Resposta paginada sem "results".',
        );
      }
      results.addAll(body['results'] as List<dynamic>);
      url = _rebase(body['next']);
    }
    return results;
  }

  Uri? _rebase(Object? next) {
    if (next is! String || next.isEmpty) return null;
    final parsed = Uri.tryParse(next);
    if (parsed == null) {
      throw const HealthApiException(
        HealthApiFailureKind.invalidResponse,
        'URL "next" inválida.',
      );
    }
    return _baseUri.replace(path: parsed.path, query: parsed.query);
  }

  Future<Object?> _getJson(Uri url) async {
    final http.Response response;
    try {
      response = await _client
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const HealthApiException(
        HealthApiFailureKind.timeout,
        'A requisição excedeu o tempo limite.',
      );
    } on IOException catch (error) {
      throw HealthApiException(
        HealthApiFailureKind.connection,
        'Falha de conexão: ${error.runtimeType}.',
      );
    } on http.ClientException catch (error) {
      throw HealthApiException(
        HealthApiFailureKind.connection,
        'Falha de conexão: ${error.message}',
      );
    }

    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      throw HealthApiException(
        status >= 500
            ? HealthApiFailureKind.server
            : HealthApiFailureKind.client,
        'HTTP $status em ${url.path}.',
        statusCode: status,
      );
    }

    try {
      // O DRF não declara charset; decodificar sempre como UTF-8.
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw HealthApiException(
        HealthApiFailureKind.invalidResponse,
        'Corpo da resposta não é JSON válido.',
        statusCode: status,
      );
    }
  }

  List<T> _parseAll<T>(List<Object?> items, T Function(Object?) parse) => [
    for (final item in items) _parse(item, parse),
  ];

  T _parse<T>(Object? json, T Function(Object?) parse) {
    try {
      return parse(json);
    } on FormatException catch (error) {
      throw HealthApiException(
        HealthApiFailureKind.invalidResponse,
        'Resposta fora do contrato: ${error.message}',
      );
    }
  }
}
