import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/repositories/route_repository.dart';

http.Response jsonResponse(Object body, {int status = 200}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: const {'content-type': 'application/json'},
    );

ApiRouteRepository repositoryFor(
  Future<http.Response> Function(http.Request request) handler, {
  String base = 'http://api.test:8000',
}) => ApiRouteRepository(
  client: MockClient(handler),
  baseUri: Uri.parse(base),
  timeout: const Duration(seconds: 2),
);

Future<HealthApiException> failureOf(Future<Object?> Function() action) async {
  try {
    await action();
  } on HealthApiException catch (error) {
    return error;
  }
  fail('Esperava HealthApiException.');
}

void main() {
  const origin = LatLng(-16.6869, -49.2648);

  test('consulta GET /api/v1/routes/ com parâmetros corretos', () async {
    late http.Request seen;
    final repository = repositoryFor((request) async {
      seen = request;
      return jsonResponse({
        'provider': 'osrm',
        'mode': 'driving',
        'unit_id': 'upa-centro',
        'distance_meters': 1000,
        'duration_seconds': 120,
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [-49.2648, -16.6869],
            [-49.264, -16.6862],
          ],
        },
      });
    });

    final route = await repository.fetchDrivingRoute(
      origin: origin,
      unitId: 'upa-centro',
    );

    expect(seen.method, 'GET');
    expect(seen.url.path, '/api/v1/routes/');
    expect(seen.url.queryParameters, {
      'origin_lat': '-16.6869',
      'origin_lon': '-49.2648',
      'unit_id': 'upa-centro',
      'mode': 'driving',
    });
    expect(seen.headers['Accept'], 'application/json');
    expect(seen.headers.containsKey('Authorization'), isFalse);

    expect(route.provider, 'osrm');
    expect(route.unitId, 'upa-centro');
    expect(route.polyline, isNotEmpty);
  });

  test('mapeia HTTP 503 como falha de servidor', () async {
    final repository = repositoryFor(
      (_) async => jsonResponse({'detail': 'indisponível'}, status: 503),
    );

    final error = await failureOf(
      () => repository.fetchDrivingRoute(origin: origin, unitId: 'upa-centro'),
    );

    expect(error.kind, HealthApiFailureKind.server);
    expect(error.statusCode, 503);
  });

  test('mapeia JSON inválido como invalidResponse', () async {
    final repository = repositoryFor(
      (_) async => http.Response('not-json', 200),
    );

    final error = await failureOf(
      () => repository.fetchDrivingRoute(origin: origin, unitId: 'upa-centro'),
    );

    expect(error.kind, HealthApiFailureKind.invalidResponse);
  });

  test('mapeia contrato quebrado como invalidResponse', () async {
    final repository = repositoryFor(
      (_) async => jsonResponse({
        'provider': 'osrm',
        'mode': 'driving',
        'unit_id': 'upa-centro',
        'distance_meters': 10,
        'duration_seconds': 10,
        'geometry': {'type': 'LineString', 'coordinates': []},
      }),
    );

    final error = await failureOf(
      () => repository.fetchDrivingRoute(origin: origin, unitId: 'upa-centro'),
    );

    expect(error.kind, HealthApiFailureKind.invalidResponse);
    expect(error.message, contains('contrato'));
  });
}
