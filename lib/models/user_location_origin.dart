import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Origem usada para distâncias em linha reta e rotas OSRM.
enum LocationOriginKind { deviceGps, manualMap }

class UserLocationOrigin {
  const UserLocationOrigin({
    required this.kind,
    required this.coordinate,
    this.gpsPosition,
    this.gpsMayBeStale = false,
  });

  final LocationOriginKind kind;
  final LatLng coordinate;

  /// Preenchido somente quando [kind] é [LocationOriginKind.deviceGps].
  final Position? gpsPosition;

  /// Falha recente ao atualizar o GPS; não se aplica ao modo manual.
  final bool gpsMayBeStale;

  bool get isManual => kind == LocationOriginKind.manualMap;
  bool get isDeviceGps => kind == LocationOriginKind.deviceGps;

  factory UserLocationOrigin.fromGps(
    Position position, {
    bool mayBeStale = false,
  }) {
    return UserLocationOrigin(
      kind: LocationOriginKind.deviceGps,
      coordinate: LatLng(position.latitude, position.longitude),
      gpsPosition: position,
      gpsMayBeStale: mayBeStale,
    );
  }

  factory UserLocationOrigin.manual(LatLng coordinate) {
    return UserLocationOrigin(
      kind: LocationOriginKind.manualMap,
      coordinate: coordinate,
    );
  }

  UserLocationOrigin copyWithGpsStale(bool stale) {
    if (!isDeviceGps) return this;
    return UserLocationOrigin.fromGps(gpsPosition!, mayBeStale: stale);
  }

  UserLocationOrigin copyWithCoordinate(LatLng coordinate) {
    if (isManual) {
      return UserLocationOrigin.manual(coordinate);
    }
    return UserLocationOrigin.fromGps(
      Position(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        timestamp: gpsPosition?.timestamp ?? DateTime.now(),
        accuracy: gpsPosition?.accuracy ?? 0,
        altitude: gpsPosition?.altitude ?? 0,
        altitudeAccuracy: gpsPosition?.altitudeAccuracy ?? 0,
        heading: gpsPosition?.heading ?? 0,
        headingAccuracy: gpsPosition?.headingAccuracy ?? 0,
        speed: gpsPosition?.speed ?? 0,
        speedAccuracy: gpsPosition?.speedAccuracy ?? 0,
      ),
      mayBeStale: gpsMayBeStale,
    );
  }

  String get mapMarkerSemanticsLabel => isManual
      ? 'Ponto escolhido manualmente no mapa'
      : 'Sua localização no aparelho';
}
