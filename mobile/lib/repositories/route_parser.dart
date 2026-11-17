import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/driving_route.dart';

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
