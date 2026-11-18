import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/driving_route.dart';
import 'package:rotasaude/models/transit_route.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/repositories/route_parser.dart';
import 'package:rotasaude/services/api_config.dart';

/// Consulta rotas de deslocamento expostas pela API Django.
abstract interface class RouteRepository {
  Future<DrivingRoute> fetchDrivingRoute({
    required LatLng origin,
    required String unitId,
  });

  /// Rota de ônibus **simulada** (demonstração). Falha com
  /// [HealthApiException] quando o servidor não oferece transporte público.
  Future<TransitRoute> fetchBusRoute({
    required LatLng origin,
    required String unitId,
  });

  void close();
}

class ApiRouteRepository implements RouteRepository {
  ApiRouteRepository({
    http.Client? client,
    Uri? baseUri,
    this.timeout = ApiConfig.requestTimeout,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _baseUri = baseUri ?? ApiConfig.baseUri;

  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;

  @override
  Future<DrivingRoute> fetchDrivingRoute({
    required LatLng origin,
    required String unitId,
  }) async {
    final body = await _getJson(_routeUri(origin, unitId, 'driving'));
    return _parse(body, parseDrivingRoute);
  }

  @override
  Future<TransitRoute> fetchBusRoute({
    required LatLng origin,
    required String unitId,
  }) async {
    final body = await _getJson(_routeUri(origin, unitId, 'bus'));
    return _parse(body, parseTransitRoute);
  }

  Uri _routeUri(LatLng origin, String unitId, String mode) =>
      _endpoint('routes/', {
        'origin_lat': '${origin.latitude}',
        'origin_lon': '${origin.longitude}',
        'unit_id': unitId,
        'mode': mode,
      });

  @override
  void close() {
    if (_ownsClient) _client.close();
  }

  Uri _endpoint(String path, [Map<String, String>? query]) {
    final base = _baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    return _baseUri.replace(path: '$base/api/v1/$path', queryParameters: query);
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
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw HealthApiException(
        HealthApiFailureKind.invalidResponse,
        'Corpo da resposta não é JSON válido.',
        statusCode: status,
      );
    }
  }

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
