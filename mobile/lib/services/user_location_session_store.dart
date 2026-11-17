import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mantém a origem escolhida entre navegação e retorno do segundo plano.
abstract class UserLocationSessionStore {
  Future<UserLocationOrigin?> load();
  Future<bool> usesGps();
  Future<void> save(UserLocationOrigin origin);
  Future<void> clear();
}

class SharedUserLocationSessionStore implements UserLocationSessionStore {
  const SharedUserLocationSessionStore();

  static const _kindKey = 'user_location_origin_kind';
  static const _latKey = 'user_location_lat';
  static const _lngKey = 'user_location_lng';

  static const _kindManual = 'manual';
  static const _kindGps = 'gps';

  @override
  Future<bool> usesGps() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_kindKey) == _kindGps;
  }

  @override
  Future<UserLocationOrigin?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final kind = preferences.getString(_kindKey);
    if (kind == _kindManual) {
      final lat = preferences.getDouble(_latKey);
      final lng = preferences.getDouble(_lngKey);
      if (lat == null || lng == null) return null;
      return UserLocationOrigin.manual(LatLng(lat, lng));
    }
    if (kind == _kindGps) {
      return null;
    }
    return null;
  }

  @override
  Future<void> save(UserLocationOrigin origin) async {
    final preferences = await SharedPreferences.getInstance();
    if (origin.isManual) {
      await preferences.setString(_kindKey, _kindManual);
      await preferences.setDouble(_latKey, origin.coordinate.latitude);
      await preferences.setDouble(_lngKey, origin.coordinate.longitude);
    } else {
      await preferences.setString(_kindKey, _kindGps);
      await preferences.remove(_latKey);
      await preferences.remove(_lngKey);
    }
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_kindKey);
    await preferences.remove(_latKey);
    await preferences.remove(_lngKey);
  }
}

class MemoryUserLocationSessionStore implements UserLocationSessionStore {
  MemoryUserLocationSessionStore({this._origin});

  UserLocationOrigin? _origin;

  @override
  Future<bool> usesGps() async => _origin?.isDeviceGps ?? false;

  @override
  Future<UserLocationOrigin?> load() async => _origin;

  @override
  Future<void> save(UserLocationOrigin origin) async {
    _origin = origin;
  }

  @override
  Future<void> clear() async {
    _origin = null;
  }
}
