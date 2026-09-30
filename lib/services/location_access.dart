import 'package:geolocator/geolocator.dart';

/// Isola as operações do dispositivo para testar o fluxo inicial.
abstract class LocationAccess {
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> isServiceEnabled();
  Future<Position> getCurrentPosition();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class DeviceLocationAccess implements LocationAccess {
  const DeviceLocationAccess();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 10),
    ),
  );

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
