import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/repositories/route_parser.dart';

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
}
