import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/screens/discovery/discovery_location_screen.dart';
import 'package:rotasaude/screens/home_screen.dart';
import 'package:rotasaude/screens/location_required_screen.dart';
import 'package:rotasaude/screens/manual_location_picker_screen.dart';
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

  /// Fonte das unidades; sem ela, o mapa consulta a API configurada.
  final HealthUnitRepository? unitRepository;

  @override
  State<RotaSaudeApp> createState() => _RotaSaudeAppState();
}

class _RotaSaudeAppState extends State<RotaSaudeApp>
    with WidgetsBindingObserver {
  late final LocationAccess _locationAccess =
      widget.locationAccess ?? const DeviceLocationAccess();
  late final LocationOnboardingStore _onboardingStore =
      widget.onboardingStore ?? const SharedLocationOnboardingStore();
  late final UserLocationSessionStore _sessionStore =
      widget.sessionStore ?? const SharedUserLocationSessionStore();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  bool _loaded = false;
  bool _accepted = false;
  LocationBlock? _block;

  /// Enquanto o seletor manual está aberto, o bloqueio não pode cobrir o
  /// [Navigator], senão a rota empilhada ficaria invisível.
  bool _suppressLocationBlockOverlay = false;

  /// Incrementa quando a sessão de localização muda fora de [DiscoveryLocationScreen]
  /// (escolha manual feita no bloqueio), para ele reler a origem salva.
  int _sessionRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBlock();
    }
  }

  Future<void> _load() async {
    final accepted = await _onboardingStore.hasAccepted();
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _loaded = true;
    });
    if (accepted) await _refreshBlock();
  }

  Future<void> _markAccepted() async {
    await _onboardingStore.markAccepted();
    if (!mounted) return;
    setState(() => _accepted = true);
    await _refreshBlock();
  }

  Future<bool> _isManualSessionActive() async {
    final session = await _sessionStore.load();
    return session?.isManual ?? false;
  }

  Future<void> _refreshBlock() async {
    if (!_accepted) return;
    if (await _isManualSessionActive()) {
      if (!mounted) return;
      setState(() => _block = null);
      return;
    }

    final permission = await _locationAccess.checkPermission();
    if (!mounted) return;

    final LocationBlock? block;
    if (permission == LocationPermission.deniedForever) {
      block = LocationBlock.permissionBlocked;
    } else if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      block = LocationBlock.permissionDenied;
    } else if (!await _locationAccess.isServiceEnabled()) {
      block = LocationBlock.serviceOff;
    } else {
      block = null;
    }

    if (!mounted) return;
    setState(() => _block = block);
  }

  Future<void> _openSettings() async {
    final block = _block;
    if (block == null) return;
    if (block == LocationBlock.serviceOff) {
      await _locationAccess.openLocationSettings();
    } else if (block == LocationBlock.permissionDenied) {
      await _locationAccess.requestPermission();
      await _refreshBlock();
    } else {
      await _locationAccess.openAppSettings();
    }
  }

  Future<void> _chooseManualFromBlock() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    // setState e push entram no mesmo frame: o overlay sai já com o seletor.
    setState(() => _suppressLocationBlockOverlay = true);
    final picked = await navigator.push<LatLng>(
      MaterialPageRoute<LatLng>(
        fullscreenDialog: true,
        builder: (_) => const ManualLocationPickerScreen(),
      ),
    );
    if (picked != null) {
      await _sessionStore.save(UserLocationOrigin.manual(picked));
    }
    if (!mounted) return;
    setState(() {
      _suppressLocationBlockOverlay = false;
      if (picked != null) {
        // Libera o bloqueio e avisa o mapa para adotar a origem salva.
        _block = null;
        _sessionRevision++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'RotaSaúde',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) {
        final block = _block;
        final showBlock =
            _accepted && block != null && !_suppressLocationBlockOverlay;
        // Estrutura fixa: o Navigator não é remontado ao alternar o bloqueio.
        return Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            if (showBlock)
              Positioned.fill(
                child: BlockSemantics(
                  child: LocationRequiredScreen(
                    block: block,
                    onOpenSettings: _openSettings,
                    onChooseManual: _chooseManualFromBlock,
                  ),
                ),
              ),
          ],
        );
      },
      home: !_loaded
          ? const Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: CircularProgressIndicator()),
            )
          : _accepted
          ? DiscoveryLocationScreen(
              locationAccess: _locationAccess,
              sessionStore: _sessionStore,
              sessionRevision: _sessionRevision,
              unitRepository: widget.unitRepository,
            )
          : HomeScreen(
              locationAccess: _locationAccess,
              sessionStore: _sessionStore,
              unitRepository: widget.unitRepository,
              onLocationAccepted: _markAccepted,
            ),
    );
  }
}
