import 'package:flutter/material.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/screens/discovery/discovery_location_screen.dart';
import 'package:rotasaude/screens/home_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/location_onboarding_store.dart';
import 'package:rotasaude/services/user_location_session_store.dart';
import 'package:rotasaude/theme/app_theme.dart';

class RotaSaudeApp extends StatefulWidget {
  const RotaSaudeApp({
    super.key,
    this.locationAccess,
    this.onboardingStore,
    this.sessionStore,
    this.unitRepository,
  });

  final LocationAccess? locationAccess;
  final LocationOnboardingStore? onboardingStore;
  final UserLocationSessionStore? sessionStore;
  final HealthUnitRepository? unitRepository;

  @override
  State<RotaSaudeApp> createState() => _RotaSaudeAppState();
}

class _RotaSaudeAppState extends State<RotaSaudeApp> {
  late final _locationAccess =
      widget.locationAccess ?? const DeviceLocationAccess();
  late final _onboardingStore =
      widget.onboardingStore ?? const SharedLocationOnboardingStore();
  late final _sessionStore =
      widget.sessionStore ?? const SharedUserLocationSessionStore();

  bool _loaded = false;
  bool _accepted = false;
  SearchArea? _initialArea;
  UserLocationOrigin? _initialOrigin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accepted = await _onboardingStore.hasAccepted();
    final area = accepted ? await _onboardingStore.loadArea() : null;
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _initialArea = area;
      _loaded = true;
    });
  }

  Future<void> _enter(SearchArea? area, UserLocationOrigin? origin) async {
    if (area != null) await _onboardingStore.saveArea(area);
    await _onboardingStore.markAccepted();
    if (!mounted) return;
    setState(() {
      _initialArea = area;
      _initialOrigin = origin;
      _accepted = true;
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RotaSaúde',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: !_loaded
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : _accepted
        ? DiscoveryLocationScreen(
            locationAccess: _locationAccess,
            sessionStore: _sessionStore,
            initialArea: _initialArea,
            initialOrigin: _initialOrigin,
            onAreaChanged: _onboardingStore.saveArea,
            unitRepository: widget.unitRepository,
          )
        : HomeScreen(
            locationAccess: _locationAccess,
            sessionStore: _sessionStore,
            unitRepository: widget.unitRepository,
            onDiscover: _enter,
          ),
  );
}
