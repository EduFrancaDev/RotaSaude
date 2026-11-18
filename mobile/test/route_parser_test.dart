import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/repositories/route_parser.dart';

import 'support/route_fixtures.dart';

void main() {
  group('geoJsonLineStringToLatLng', () {
    test('converte [longitude, latitude] para LatLng', () {
      final points = geoJsonLineStringToLatLng([
        [-49.2648, -16.6869],
        [-49.264, -16.6862],
      ]);

      expect(points, [
        const LatLng(-16.6869, -49.2648),
        const LatLng(-16.6862, -49.264),
      ]);
    });

    test('rejeita lista vazia', () {
      expect(
        () => geoJsonLineStringToLatLng([]),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejeita par inválido', () {
      expect(
        () => geoJsonLineStringToLatLng([
          ['x', -16.6869],
        ]),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('parseDrivingRoute', () {
    test('lê o contrato publicado pela API', () {
      final route = parseDrivingRoute({
        'provider': 'osrm',
        'mode': 'driving',
        'unit_id': 'upa-centro',
        'distance_meters': 582.4,
        'duration_seconds': 95.2,
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [-49.2648, -16.6869],
            [-49.264, -16.6862],
          ],
        },
      });

      expect(route.provider, 'osrm');
      expect(route.mode, 'driving');
      expect(route.unitId, 'upa-centro');
      expect(route.distanceMeters, 582.4);
      expect(route.durationSeconds, 95.2);
      expect(route.distanceKm, closeTo(0.5824, 0.0001));
      expect(route.durationMinutes, 2);
      expect(route.polyline.first.latitude, -16.6869);
      expect(route.polyline.last.longitude, -49.264);
    });

    test('exige LineString', () {
      expect(
        () => parseDrivingRoute({
          'provider': 'osrm',
          'mode': 'driving',
          'unit_id': 'u',
          'distance_meters': 1,
          'duration_seconds': 1,
          'geometry': {
            'type': 'Point',
            'coordinates': [0, 0],
          },
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('parseTransitRoute', () {
    test('interpreta a rota de ônibus simulada', () {
      final route = parseTransitRoute(busRouteJson());

      expect(route.provider, 'demo-simulated');
      expect(route.lineCode, 'DEMO-A1');
      expect(route.boardingStop.name, 'Ponto de embarque');
      expect(
        route.alightingStop.position,
        const LatLng(-16.707228, -49.259696),
      );
      expect(route.walkToStopMeters, 412);
      expect(route.waitMinutes, 6);
      expect(route.durationMinutes, 26);
      expect(route.distanceKm, closeTo(3.535, 1e-9));
      expect(route.polyline, hasLength(4));
      expect(route.polyline.first, const LatLng(-16.6869, -49.2648));
      expect(route.notice, contains('Dados simulados'));
      // Horários com fuso: o instante absoluto é preservado.
      expect(route.arrivalAt.toUtc(), DateTime.utc(2026, 11, 18, 14, 33, 31));
      expect(route.departureAt.isBefore(route.busDepartureAt), isTrue);
      expect(route.busArrivalAt.isBefore(route.arrivalAt), isTrue);
    });

    test('rejeita rota de ônibus sem marca de simulação', () {
      expect(
        () => parseTransitRoute(busRouteJson(isSimulated: false)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseTransitRoute({...busRouteJson()}..remove('is_simulated')),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejeita campos obrigatórios ausentes ou inválidos', () {
      for (final key in [
        'line',
        'boarding_stop',
        'alighting_stop',
        'wait_seconds',
        'arrival_at',
        'geometry',
        'route_id',
      ]) {
        expect(
          () => parseTransitRoute({...busRouteJson()}..remove(key)),
          throwsA(isA<FormatException>()),
          reason: key,
        );
      }
      expect(
        () => parseTransitRoute({...busRouteJson(), 'arrival_at': 'ontem'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseTransitRoute({...busRouteJson(), 'wait_seconds': -1}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseTransitRoute({...busRouteJson(), 'mode': 'driving'}),
        throwsA(isA<FormatException>()),
      );
      expect(() => parseTransitRoute('texto'), throwsA(isA<FormatException>()));
    });
  });
}
