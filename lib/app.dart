import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/screens/home_screen.dart';
import 'package:rotasaude/screens/location_required_screen.dart';
import 'package:rotasaude/screens/manual_location_picker_screen.dart';
import 'package:rotasaude/screens/map_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/location_onboarding_store.dart';
import 'package:rotasaude/services/user_location_session_store.dart';
import 'package:rotasaude/theme/app_colors.dart';
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

  /// Incrementa quando a sessão de localização muda fora de [_ReturningMap]
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
          ? _ReturningMap(
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

class _ReturningMap extends StatefulWidget {
  const _ReturningMap({
    required this.locationAccess,
    required this.sessionStore,
    required this.sessionRevision,
    this.unitRepository,
  });

  final LocationAccess locationAccess;
  final UserLocationSessionStore sessionStore;

  /// Muda quando outra parte do app grava uma nova origem na sessão.
  final int sessionRevision;
  final HealthUnitRepository? unitRepository;

  @override
  State<_ReturningMap> createState() => _ReturningMapState();
}

class _ReturningMapState extends State<_ReturningMap>
    with WidgetsBindingObserver {
  UserLocationOrigin? _origin;
  bool _initializing = true;
  bool _refreshInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialOrigin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  @override
  void didUpdateWidget(_ReturningMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionRevision != widget.sessionRevision) {
      _adoptManualSession();
    }
  }

  /// Adota a origem manual salva na sessão, sem consultar o GPS.
  /// Retorna `false` quando a sessão não está em modo manual.
  Future<bool> _adoptManualSession() async {
    final session = await widget.sessionStore.load();
    if (!mounted) return false;
    if (session == null || !session.isManual) return false;
    final current = _origin;
    if (current == null ||
        !current.isManual ||
        current.coordinate != session.coordinate) {
      setState(() {
        _origin = session;
        _initializing = false;
      });
    }
    return true;
  }

  Future<void> _loadInitialOrigin() async {
    if (await _adoptManualSession() || !mounted) return;
    await _fetchGpsOrigin(updateInitializing: true);
  }

  Future<void> _onResumed() async {
    if (await _adoptManualSession() || !mounted) return;
    await _refreshGpsSilently();
  }

  Future<void> _refreshGpsSilently() async {
    if (_origin == null) {
      await _fetchGpsOrigin(updateInitializing: false);
      return;
    }
    if (_origin!.isManual) return;
    await _fetchGpsOrigin(updateInitializing: false);
  }

  /// [explicit] indica pedido da pessoa para voltar ao GPS; leituras
  /// automáticas nunca sobrescrevem uma origem manual escolhida enquanto
  /// aguardavam o GPS.
  Future<void> _fetchGpsOrigin({
    required bool updateInitializing,
    bool explicit = false,
  }) async {
    if (_refreshInFlight && !explicit) return;
    _refreshInFlight = true;
    try {
      final position = await widget.locationAccess.getCurrentPosition();
      if (!mounted) return;
      if (!explicit && (_origin?.isManual ?? false)) return;
      final origin = UserLocationOrigin.fromGps(position);
      await widget.sessionStore.save(origin);
      setState(() {
        _origin = origin;
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (updateInitializing) {
          _initializing = false;
        }
        if (_origin != null && _origin!.isDeviceGps) {
          _origin = _origin!.copyWithGpsStale(true);
        }
      });
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _onOriginChanged(UserLocationOrigin origin) async {
    await widget.sessionStore.save(origin);
    if (!mounted) return;
    setState(() => _origin = origin);
  }

  Future<void> _retryInitialGps() async {
    setState(() {
      _initializing = true;
      _origin = null;
    });
    await _fetchGpsOrigin(updateInitializing: true);
  }

  Future<LatLng?> _openManualPicker() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute<LatLng>(
        builder: (_) => const ManualLocationPickerScreen(),
      ),
    );
    if (!mounted || picked == null) return null;
    await _onOriginChanged(UserLocationOrigin.manual(picked));
    return picked;
  }

  Future<void> _switchToGps() async {
    setState(() {
      _initializing = true;
    });
    await _fetchGpsOrigin(updateInitializing: true, explicit: true);
  }

  @override
  Widget build(BuildContext context) {
    final origin = _origin;
    if (_initializing && origin == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Obtendo localização…'),
              ],
            ),
          ),
        ),
      );
    }

    if (origin == null) {
      return Scaffold(
        body: SafeArea(
          minimum: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.location_searching_rounded,
                    color: AppColors.blue,
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Não conseguimos obter sua localização agora.',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confira o sinal e tente novamente, ou escolha um ponto '
                    'manualmente no mapa.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _retryInitialGps,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _openManualPicker,
                    child: const Text('Escolher localização manualmente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MapScreen(
      key: const PageStorageKey<String>('discovery-map'),
      userOrigin: origin,
      repository: widget.unitRepository,
      locationAccess: widget.locationAccess,
      sessionStore: widget.sessionStore,
      onUserOriginChanged: _onOriginChanged,
      onSwitchToGps: _switchToGps,
      onChooseManualOnMap: _openManualPicker,
    );
  }
}
