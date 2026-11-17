import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/screens/manual_location_picker_screen.dart';
import 'package:rotasaude/screens/map_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/user_location_session_store.dart';
import 'package:rotasaude/theme/app_colors.dart';

class DiscoveryLocationScreen extends StatefulWidget {
  const DiscoveryLocationScreen({
    required this.locationAccess,
    required this.sessionStore,
    required this.sessionRevision,
    this.unitRepository,
    super.key,
  });

  final LocationAccess locationAccess;
  final UserLocationSessionStore sessionStore;

  /// Muda quando outra parte do app grava uma nova origem na sessão.
  final int sessionRevision;
  final HealthUnitRepository? unitRepository;

  @override
  State<DiscoveryLocationScreen> createState() =>
      _DiscoveryLocationScreenState();
}

class _DiscoveryLocationScreenState extends State<DiscoveryLocationScreen>
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
  void didUpdateWidget(DiscoveryLocationScreen oldWidget) {
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
