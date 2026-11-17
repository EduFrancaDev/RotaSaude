import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/driving_route.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/repositories/route_repository.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/theme/app_theme.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

enum _RouteLoadStatus { loading, loaded, failed }

enum _LocationIssue { denied, blocked, serviceOff, positionFailed }

class RoutePreviewScreen extends StatefulWidget {
  const RoutePreviewScreen({
    required this.unit,
    required this.initialMode,
    required this.initialOrigin,
    this.originKind = LocationOriginKind.deviceGps,
    this.routeRepository,
    this.locationAccess,
    this.onChooseManualOrigin,
    this.onSwitchToGps,
    super.key,
  });

  final HealthUnit unit;
  final TravelMode initialMode;
  final LatLng initialOrigin;
  final LocationOriginKind originKind;

  final RouteRepository? routeRepository;
  final LocationAccess? locationAccess;
  final Future<LatLng?> Function()? onChooseManualOrigin;
  final Future<void> Function()? onSwitchToGps;

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  late TravelMode _mode = widget.initialMode;
  late LatLng _origin = widget.initialOrigin;
  late final RouteRepository _repository =
      widget.routeRepository ?? ApiRouteRepository();
  late final LocationAccess _locationAccess =
      widget.locationAccess ?? const DeviceLocationAccess();

  final MapController _mapController = MapController();

  DrivingRoute? _route;
  _RouteLoadStatus _status = _RouteLoadStatus.loading;
  HealthApiException? _failure;
  _LocationIssue? _locationIssue;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (_mode == TravelMode.car) {
      _loadDrivingRoute();
    } else {
      _status = _RouteLoadStatus.loaded;
    }
  }

  @override
  void dispose() {
    if (widget.routeRepository == null) _repository.close();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivingRoute() async {
    final generation = ++_loadGeneration;
    setState(() {
      _status = _RouteLoadStatus.loading;
      _failure = null;
      _locationIssue = null;
      _route = null;
    });

    DrivingRoute? route;
    HealthApiException? failure;
    try {
      route = await _repository.fetchDrivingRoute(
        origin: _origin,
        unitId: widget.unit.id,
      );
    } on HealthApiException catch (error) {
      failure = error;
    } on Exception catch (error) {
      failure = HealthApiException(
        HealthApiFailureKind.invalidResponse,
        'Falha inesperada: $error',
      );
    }

    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _route = route;
      _failure = failure;
      _status = failure == null
          ? _RouteLoadStatus.loaded
          : _RouteLoadStatus.failed;
    });
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _fitRouteOnMap(route!),
      );
    }
  }

  void _fitRouteOnMap(DrivingRoute route) {
    final points = <LatLng>[_origin, widget.unit.position, ...route.polyline];
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
    );
  }

  Future<void> _refreshOrigin() async {
    if (widget.originKind == LocationOriginKind.manualMap) {
      final picked = await widget.onChooseManualOrigin?.call();
      if (!mounted || picked == null) return;
      setState(() => _origin = picked);
      await _loadDrivingRoute();
      return;
    }
    _LocationIssue? issue;
    LatLng? origin;
    try {
      final serviceOn = await _locationAccess.isServiceEnabled();
      if (!serviceOn) {
        issue = _LocationIssue.serviceOff;
      } else {
        var permission = await _locationAccess.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await _locationAccess.requestPermission();
        }
        if (permission == LocationPermission.denied) {
          issue = _LocationIssue.denied;
        } else if (permission == LocationPermission.deniedForever) {
          issue = _LocationIssue.blocked;
        } else {
          final position = await _locationAccess.getCurrentPosition();
          origin = LatLng(position.latitude, position.longitude);
        }
      }
    } on Exception {
      issue = _LocationIssue.positionFailed;
    }

    if (!mounted) return;
    if (issue != null || origin == null) {
      setState(() => _locationIssue = issue ?? _LocationIssue.positionFailed);
      return;
    }
    setState(() {
      _origin = origin!;
      _locationIssue = null;
    });
    await _loadDrivingRoute();
  }

  void _onModeChanged(TravelMode mode) {
    setState(() => _mode = mode);
    if (mode == TravelMode.car) {
      _loadDrivingRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rota até a unidade'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: SegmentedButton<TravelMode>(
                style: AppTheme.primarySegmentedButtonStyle,
                segments: const [
                  ButtonSegment(value: TravelMode.car, label: Text('Carro')),
                  ButtonSegment(
                    value: TravelMode.bus,
                    label: Text('Ônibus'),
                    enabled: false,
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) =>
                    _onModeChanged(selection.first),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() => switch (_mode) {
    TravelMode.bus => _PublicTransitUnavailable(unit: widget.unit),
    TravelMode.car => switch (_locationIssue) {
      final issue? => _LocationBlocked(
        issue: issue,
        onRetry: _refreshOrigin,
        onOpenSettings: () async {
          final opened = issue == _LocationIssue.serviceOff
              ? await _locationAccess.openLocationSettings()
              : await _locationAccess.openAppSettings();
          if (!opened && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não foi possível abrir as configurações.'),
              ),
            );
          }
        },
      ),
      null => switch (_status) {
        _RouteLoadStatus.loading => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Calculando rota de carro…'),
            ],
          ),
        ),
        _RouteLoadStatus.failed => _RouteLoadFailure(
          kind: _failure?.kind ?? HealthApiFailureKind.connection,
          onRetry: _loadDrivingRoute,
        ),
        _RouteLoadStatus.loaded =>
          _route == null
              ? const SizedBox.shrink()
              : _DrivingRouteContent(
                  unit: widget.unit,
                  origin: _origin,
                  originKind: widget.originKind,
                  route: _route!,
                  mapController: _mapController,
                  onRefreshOrigin: _refreshOrigin,
                ),
      },
    },
  };
}

class _DrivingRouteContent extends StatelessWidget {
  const _DrivingRouteContent({
    required this.unit,
    required this.origin,
    required this.originKind,
    required this.route,
    required this.mapController,
    required this.onRefreshOrigin,
  });

  final HealthUnit unit;
  final LatLng origin;
  final LocationOriginKind originKind;
  final DrivingRoute route;
  final MapController mapController;
  final VoidCallback onRefreshOrigin;

  @override
  Widget build(BuildContext context) {
    final operational = unit.currentOperationalData;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      children: [
        SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: unit.position,
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.edufrancadev.rotasaude',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route.polyline,
                          strokeWidth: 5,
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: origin,
                          width: 40,
                          height: 40,
                          child: Icon(
                            originKind == LocationOriginKind.manualMap
                                ? Icons.place_rounded
                                : Icons.my_location_rounded,
                            color: AppColors.blue,
                            size: 28,
                          ),
                        ),
                        Marker(
                          point: unit.position,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.local_hospital_rounded,
                            color: AppColors.navy,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 9, color: AppColors.navy),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          unit.name,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        UnitAvailabilityStatus(unit: unit),
        if (unit.isDemo) ...[
          const SizedBox(height: 8),
          const IllustrativeNotice(compact: true),
        ],
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                '${route.durationMinutes} min',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              formatDistanceKilometers(route.distanceKm),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Rota calculada por ${route.provider} · modo ${route.mode}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.muted),
        ),
        if (operational != null) ...[
          const Divider(height: 28),
          Text(
            'Na unidade agora',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              MetricColumn(
                value: '${operational.waitMinutes ?? '—'} min',
                label: 'espera estimada',
              ),
              MetricColumn(
                value: '${operational.peopleWaiting ?? '—'}',
                label: 'aguardando',
                alignment: CrossAxisAlignment.center,
              ),
              MetricColumn(
                value: operational.updatedAt == null
                    ? '—'
                    : formatUpdateTime(operational.updatedAt!),
                label: 'atualização',
                alignment: CrossAxisAlignment.end,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRefreshOrigin,
          icon: Icon(
            originKind == LocationOriginKind.manualMap
                ? Icons.edit_location_alt_outlined
                : Icons.my_location_outlined,
            size: 18,
          ),
          label: Text(
            originKind == LocationOriginKind.manualMap
                ? 'Alterar ponto manual'
                : 'Atualizar minha posição',
          ),
        ),
      ],
    );
  }
}

class _PublicTransitUnavailable extends StatelessWidget {
  const _PublicTransitUnavailable({required this.unit});

  final HealthUnit unit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_bus_outlined,
              size: 44,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              'Transporte público indisponível',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'O cálculo de rotas de ônibus até ${unit.name} ainda não está '
              'disponível nesta versão. Use a rota de carro para ver o '
              'deslocamento real até a unidade.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteLoadFailure extends StatelessWidget {
  const _RouteLoadFailure({required this.kind, required this.onRetry});

  final HealthApiFailureKind kind;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (kind) {
      HealthApiFailureKind.connection => (
        'Sem conexão com o servidor',
        'Não conseguimos calcular a rota. Verifique sua conexão e tente '
            'novamente.',
      ),
      HealthApiFailureKind.timeout => (
        'O servidor demorou a responder',
        'O cálculo da rota excedeu o tempo limite. Tente novamente.',
      ),
      HealthApiFailureKind.server => (
        'Roteamento indisponível',
        'O servidor ou o provedor de rotas não respondeu. Tente novamente '
            'em instantes.',
      ),
      HealthApiFailureKind.client || HealthApiFailureKind.invalidResponse => (
        'Não foi possível calcular a rota',
        'A resposta do servidor não pôde ser usada. Tente novamente.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, size: 44, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationBlocked extends StatelessWidget {
  const _LocationBlocked({
    required this.issue,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final _LocationIssue issue;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final (title, message, settingsLabel) = switch (issue) {
      _LocationIssue.denied => (
        'Localização necessária',
        'Para calcular a rota a partir de onde você está, permita o acesso '
            'à localização enquanto usa o app.',
        null,
      ),
      _LocationIssue.blocked => (
        'Permissão de localização bloqueada',
        'Abra as configurações do app e permita o acesso à localização para '
            'calcular a rota.',
        'Abrir configurações',
      ),
      _LocationIssue.serviceOff => (
        'Localização desligada',
        'Ative a localização do aparelho para usar sua posição como origem '
            'da rota.',
        'Abrir configurações',
      ),
      _LocationIssue.positionFailed => (
        'Não foi possível obter sua posição',
        'Confira o sinal de GPS e tente novamente.',
        null,
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 44,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
            if (settingsLabel != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onOpenSettings,
                child: Text(settingsLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
