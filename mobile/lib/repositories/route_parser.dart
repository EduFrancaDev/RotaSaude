import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/driving_route.dart';
import 'package:rotasaude/models/transit_route.dart';

/// Converte pares GeoJSON `[longitude, latitude]` para [LatLng] do mapa.
List<LatLng> geoJsonLineStringToLatLng(List<dynamic> coordinates) {
  final points = <LatLng>[];
  for (final entry in coordinates) {
    if (entry is! List || entry.length < 2) {
      throw const FormatException('coordenada GeoJSON inválida');
    }
    final lon = entry[0];
    final lat = entry[1];
    if (lon is! num || lat is! num) {
      throw const FormatException('coordenada GeoJSON inválida');
    }
    points.add(LatLng(lat.toDouble(), lon.toDouble()));
  }
  if (points.isEmpty) {
    throw const FormatException('geometry sem coordenadas');
  }
  return points;
}

DrivingRoute parseDrivingRoute(Object? json) {
  if (json is! Map<String, dynamic>) {
    throw const FormatException('rota deve ser um objeto JSON');
  }

  final provider = json['provider'];
  final mode = json['mode'];
  final unitId = json['unit_id'];
  final distance = json['distance_meters'];
  final duration = json['duration_seconds'];
  final geometry = json['geometry'];

  if (provider is! String || provider.isEmpty) {
    throw const FormatException('provider ausente');
  }
  if (mode is! String || mode.isEmpty) {
    throw const FormatException('mode ausente');
  }
  if (unitId is! String || unitId.isEmpty) {
    throw const FormatException('unit_id ausente');
  }
  if (distance is! num) {
    throw const FormatException('distance_meters ausente');
  }
  if (duration is! num) {
    throw const FormatException('duration_seconds ausente');
  }
  if (geometry is! Map<String, dynamic>) {
    throw const FormatException('geometry ausente');
  }
  if (geometry['type'] != 'LineString') {
    throw const FormatException('geometry.type deve ser LineString');
  }
  final rawCoords = geometry['coordinates'];
  if (rawCoords is! List<dynamic>) {
    throw const FormatException('geometry.coordinates ausente');
  }

  return DrivingRoute(
    provider: provider,
    mode: mode,
    unitId: unitId,
    distanceMeters: distance.toDouble(),
    durationSeconds: duration.toDouble(),
    polyline: geoJsonLineStringToLatLng(rawCoords),
  );
}

/// Converte `GET /api/v1/routes/?mode=bus`. Só aceita rotas declaradas como
/// simuladas (`is_simulated: true`); campos ausentes são violação de contrato.
TransitRoute parseTransitRoute(Object? json) {
  if (json is! Map<String, dynamic>) {
    throw const FormatException('rota deve ser um objeto JSON');
  }
  if (json['is_simulated'] != true) {
    throw const FormatException('rota de ônibus sem marca de simulação');
  }
  if (json['mode'] != 'bus') {
    throw const FormatException('mode deve ser bus');
  }
  final geometry = json['geometry'];
  if (geometry is! Map<String, dynamic> ||
      geometry['type'] != 'LineString' ||
      geometry['coordinates'] is! List<dynamic>) {
    throw const FormatException('geometry ausente ou inválida');
  }
  final line = json['line'];
  if (line is! Map<String, dynamic>) {
    throw const FormatException('line ausente');
  }

  return TransitRoute(
    provider: _string(json, 'provider'),
    unitId: _string(json, 'unit_id'),
    routeId: _string(json, 'route_id'),
    lineCode: _string(line, 'code'),
    lineName: _string(line, 'name'),
    boardingStop: _stop(json['boarding_stop'], 'boarding_stop'),
    alightingStop: _stop(json['alighting_stop'], 'alighting_stop'),
    walkToStopMeters: _number(json, 'walk_to_stop_meters'),
    walkToStopSeconds: _number(json, 'walk_to_stop_seconds'),
    waitSeconds: _number(json, 'wait_seconds'),
    inVehicleSeconds: _number(json, 'in_vehicle_seconds'),
    walkFromStopMeters: _number(json, 'walk_from_stop_meters'),
    walkFromStopSeconds: _number(json, 'walk_from_stop_seconds'),
    departureAt: _instant(json, 'departure_at'),
    busDepartureAt: _instant(json, 'bus_departure_at'),
    busArrivalAt: _instant(json, 'bus_arrival_at'),
    arrivalAt: _instant(json, 'arrival_at'),
    distanceMeters: _number(json, 'distance_meters'),
    durationSeconds: _number(json, 'duration_seconds'),
    polyline: geoJsonLineStringToLatLng(geometry['coordinates'] as List),
    notice: switch (json['simulation_notice']) {
      final String text when text.trim().isNotEmpty => text.trim(),
      _ => null,
    },
  );
}

String _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$key ausente');
}

double _number(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is num && value.isFinite && value >= 0) return value.toDouble();
  throw FormatException('$key ausente ou inválido');
}

DateTime _instant(Map<String, dynamic> map, String key) {
  final value = map[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw FormatException('$key ausente ou inválido');
  return parsed;
}

TransitStop _stop(Object? json, String key) {
  if (json is! Map<String, dynamic>) throw FormatException('$key ausente');
  final lat = json['latitude'];
  final lon = json['longitude'];
  if (lat is! num || lon is! num || lat.abs() > 90 || lon.abs() > 180) {
    throw FormatException('$key com coordenadas inválidas');
  }
  return TransitStop(
    name: _string(json, 'name'),
    position: LatLng(lat.toDouble(), lon.toDouble()),
  );
}
