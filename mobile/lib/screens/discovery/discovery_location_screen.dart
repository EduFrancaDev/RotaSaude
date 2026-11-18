import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/screens/map_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/user_location_session_store.dart';

/// Restaura e atualiza a origem sem interromper a consulta em andamento.
class DiscoveryLocationScreen extends StatefulWidget {
  const DiscoveryLocationScreen({
    required this.locationAccess,
    required this.sessionStore,
    this.initialArea,
    this.initialOrigin,
    this.onAreaChanged,
    this.unitRepository,
    super.key,
  });

  final LocationAccess locationAccess;
  final UserLocationSessionStore sessionStore;
  final SearchArea? initialArea;
  final UserLocationOrigin? initialOrigin;
  final ValueChanged<SearchArea>? onAreaChanged;
  final HealthUnitRepository? unitRepository;

  @override
  State<DiscoveryLocationScreen> createState() =>
      _DiscoveryLocationScreenState();
}

class _DiscoveryLocationScreenState extends State<DiscoveryLocationScreen>
    with WidgetsBindingObserver {
  late UserLocationOrigin? _origin = widget.initialOrigin;
  bool _refreshInFlight = false;
  bool _useGps = false;
  int _originRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreOrigin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _restoreOrigin() async {
    final revision = _originRevision;
    final saved = widget.initialOrigin ?? await widget.sessionStore.load();
    final useGps =
        saved?.isDeviceGps ??
        (widget.initialArea == null || await widget.sessionStore.usesGps());
    if (!mounted || revision != _originRevision) return;
    _useGps = useGps;
    if (saved != null) {
      setState(() => _origin = saved);
    } else if (useGps) {
      await _refreshGps();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _useGps) _refreshGps();
  }

  Future<void> _refreshGps() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    final revision = _originRevision;
    try {
      final permission = await widget.locationAccess.checkPermission();
      if (!mounted || revision != _originRevision) return;
      if (permission != LocationPermission.always &&
              permission != LocationPermission.whileInUse ||
          !await widget.locationAccess.isServiceEnabled()) {
        if (mounted && revision == _originRevision) {
          setState(() => _origin = null);
        }
        return;
      }
      final position = await widget.locationAccess.getCurrentPosition();
      if (!mounted || revision != _originRevision) return;
      setState(() => _origin = UserLocationOrigin.fromGps(position));
    } on Exception {
      if (mounted && revision == _originRevision && _origin != null) {
        setState(() => _origin = _origin!.copyWithGpsStale(true));
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _setOrigin(UserLocationOrigin origin) async {
    _originRevision++;
    _useGps = origin.isDeviceGps;
    setState(() => _origin = origin);
    await widget.sessionStore.save(origin);
  }

  @override
  Widget build(BuildContext context) => MapScreen(
    userOrigin: _origin,
    initialArea: widget.initialArea,
    startInList: widget.initialArea != null,
    repository: widget.unitRepository,
    locationAccess: widget.locationAccess,
    onAreaChanged: widget.onAreaChanged,
    onUserOriginChanged: _setOrigin,
  );
}
