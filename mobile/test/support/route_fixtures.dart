import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/transit_route.dart';
import 'package:rotasaude/repositories/route_parser.dart';

/// JSON no formato real de `GET /api/v1/routes/?mode=bus` (rota SIMULADA).
Map<String, dynamic> busRouteJson({
  String unitId = 'upa-centro',
  bool isSimulated = true,
  double durationSeconds = 1546,
  double waitSeconds = 344,
}) => {
  'provider': 'demo-simulated',
  'mode': 'bus',
  'unit_id': unitId,
  'is_simulated': isSimulated,
  'simulation_notice':
      'Dados simulados — demonstração acadêmica. Linha, pontos e horários '
      'são fictícios, não são oficiais e não servem para navegação.',
  'route_id': 'demo-$unitId-demo-a1',
  'line': {
    'code': 'DEMO-A1',
    'name': 'Linha A1',
    'headway_minutes': 15,
  },
  'boarding_stop': {
    'name': 'Ponto de embarque',
    'latitude': -16.689672,
    'longitude': -49.264104,
  },
  'alighting_stop': {
    'name': 'Ponto de desembarque',
    'latitude': -16.707228,
    'longitude': -49.259696,
  },
  'walk_to_stop_meters': 412,
  'walk_to_stop_seconds': 330,
  'wait_seconds': waitSeconds,
  'in_vehicle_seconds': 542,
  'walk_from_stop_meters': 412,
  'walk_from_stop_seconds': 330,
  'departure_at': '2026-11-18T11:07:46-03:00',
  'bus_departure_at': '2026-11-18T11:19:00-03:00',
  'bus_arrival_at': '2026-11-18T11:28:02-03:00',
  'arrival_at': '2026-11-18T11:33:31-03:00',
  'distance_meters': 3535,
  'duration_seconds': durationSeconds,
  'geometry_kind': 'schematic',
  'geometry': {
    'type': 'LineString',
    'coordinates': [
      [-49.2648, -16.6869],
      [-49.264104, -16.689672],
      [-49.259696, -16.707228],
      [-49.259, -16.71],
    ],
  },
};

TransitRoute busRoute({String unitId = 'upa-centro'}) =>
    parseTransitRoute(busRouteJson(unitId: unitId));

const busOrigin = LatLng(-16.6869, -49.2648);
