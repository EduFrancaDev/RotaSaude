import 'package:latlong2/latlong.dart';

/// Resposta normalizada de `GET /api/v1/routes/` para modo `driving`.
class DrivingRoute {
  const DrivingRoute({
    required this.provider,
    required this.mode,
    required this.unitId,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
  });

  final String provider;
  final String mode;
  final String unitId;
  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> polyline;

  double get distanceKm => distanceMeters / 1000;

  int get durationMinutes => (durationSeconds / 60).round().clamp(1, 999999);
}
