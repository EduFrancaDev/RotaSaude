import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

/// Rótulo da métrica nas listas — distingue do percurso de carro (OSRM).
const straightLineDistanceMetricLabel = 'dist. aprox. (linha reta)';

/// Valor exibido quando não há posição do usuário ou coordenadas da unidade.
const straightLineDistanceUnavailable = 'Distância indisponível';

bool isValidGeographicPosition(LatLng position) {
  final lat = position.latitude;
  final lon = position.longitude;
  return lat.isFinite &&
      lon.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lon >= -180 &&
      lon <= 180;
}

/// Distância geográfica em quilômetros, ou `null` se não puder ser calculada.
double? computeStraightLineDistanceKm({
  required LatLng? userPosition,
  required LatLng unitPosition,
}) {
  if (userPosition == null) return null;
  if (!isValidGeographicPosition(userPosition) ||
      !isValidGeographicPosition(unitPosition)) {
    return null;
  }
  final meters = Geolocator.distanceBetween(
    userPosition.latitude,
    userPosition.longitude,
    unitPosition.latitude,
    unitPosition.longitude,
  );
  if (!meters.isFinite || meters < 0) return null;
  return meters / 1000;
}

String formatStraightLineDistanceValue(double? distanceKm) => distanceKm == null
    ? straightLineDistanceUnavailable
    : formatDistanceKilometers(distanceKm);

/// Ordena por proximidade: menor distância primeiro; sem distância ao final.
int compareUnitsByStraightLineDistance(
  HealthUnit a,
  double? distanceA,
  HealthUnit b,
  double? distanceB,
) {
  if (distanceA == null && distanceB == null) {
    return a.name.compareTo(b.name);
  }
  if (distanceA == null) return 1;
  if (distanceB == null) return -1;
  final byDistance = distanceA.compareTo(distanceB);
  if (byDistance != 0) return byDistance;
  return a.name.compareTo(b.name);
}

/// Mapa `unitId → km` reutilizado enquanto origem e unidades não mudam.
Map<String, double?> buildStraightLineDistanceLookup({
  required LatLng? userPosition,
  required List<HealthUnit> units,
}) {
  return {
    for (final unit in units)
      unit.id: computeStraightLineDistanceKm(
        userPosition: userPosition,
        unitPosition: unit.position,
      ),
  };
}
