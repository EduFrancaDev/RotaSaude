import 'dart:async';

import 'package:rotasaude/widgets/screen_back_button.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/driving_route.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/repositories/route_repository.dart';
import 'package:rotasaude/services/external_maps.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

class RoutePreviewScreen extends StatefulWidget {
  const RoutePreviewScreen({
    required this.unit,
    required this.initialOrigin,
    required this.routeRepository,
    required this.onChooseOrigin,
    this.onCalculated,
    this.openMaps = openUnitInMaps,
    this.now,
    super.key,
  });

  final HealthUnit unit;
  final UserLocationOrigin? initialOrigin;
  final RouteRepository routeRepository;
  final Future<UserLocationOrigin?> Function() onChooseOrigin;
  final void Function(LatLng, DrivingRoute)? onCalculated;
  final Future<bool> Function(HealthUnit) openMaps;
  final DateTime Function()? now;

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  late UserLocationOrigin? _origin = widget.initialOrigin;
  late final Timer _clock;
  DrivingRoute? _route;
  HealthApiFailureKind? _failure;
  bool _loading = false;
  bool _openingMaps = false;
  int _loadGeneration = 0;

  bool get _canCalculate => isValidGeographicPosition(widget.unit.position);

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    _calculate();
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _calculate() async {
    final origin = _origin;
    if (origin == null || !_canCalculate) return;
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _failure = null;
      _route = null;
    });
    try {
      final route = await widget.routeRepository.fetchDrivingRoute(
        origin: origin.coordinate,
        unitId: widget.unit.id,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _route = route;
        _loading = false;
      });
      widget.onCalculated?.call(origin.coordinate, route);
    } on Exception catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _failure = error is HealthApiException
            ? error.kind
            : HealthApiFailureKind.invalidResponse;
        _loading = false;
      });
    }
  }

  Future<void> _changeOrigin() async {
    final origin = await widget.onChooseOrigin();
    if (!mounted || origin == null) return;
    setState(() => _origin = origin);
    await _calculate();
  }

  Future<void> _openExternal() async {
    if (_openingMaps) return;
    setState(() => _openingMaps = true);
    bool opened = false;
    try {
      opened = await widget.openMaps(widget.unit);
    } on Exception {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _openingMaps = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir um app de mapas. Use o endereço da unidade.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final now = widget.now?.call() ?? DateTime.now();
    final route = _route;
    final origin = _origin;
    final canOpenExternal = mapDestination(unit) != null;
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rota até a unidade'),
        leading: const ScreenBackButton(),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Text(
              unit.name,
              style: theme.headlineSmall?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (unit.address.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(
                unit.address,
                style: theme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 12),
            Text('Rota de carro', style: theme.titleMedium),
            if (!_canCalculate)
              const Text(
                'A unidade não tem um ponto no mapa para calcular a rota aqui.',
              )
            else if (origin == null)
              const Text(
                'Defina de onde você vai sair para calcular o trajeto.',
              )
            else if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Semantics(
                  liveRegion: true,
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Expanded(child: Text('Calculando rota de carro…')),
                    ],
                  ),
                ),
              )
            else if (_failure case final failure?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_failureMessage(failure), style: theme.bodyLarge),
                ),
              )
            else if (route != null) ...[
              const SizedBox(height: 6),
              Text(
                '${route.durationMinutes} min de carro · ${formatDistanceKilometers(route.distanceKm)} de trajeto',
                style: theme.titleLarge?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Rota calculada por ${route.provider}',
                style: theme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              _RouteMap(
                route: route,
                origin: origin,
                destination: unit.position,
              ),
            ],
            const SizedBox(height: 12),
            if (_canCalculate && origin != null)
              OutlinedButton.icon(
                onPressed: _changeOrigin,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Alterar ponto de partida'),
              ),
            if (unit.isDemo) ...[
              const SizedBox(height: 8),
              const IllustrativeNotice(compact: true),
            ],
            const SizedBox(height: 8),
            UnitWaitEstimate(unit: unit, now: now, showUpdate: true),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 6, 18, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_failure != null)
              FilledButton(
                onPressed: _calculate,
                child: const Text('Tentar novamente'),
              )
            else if (_canCalculate && origin == null)
              FilledButton(
                onPressed: _changeOrigin,
                child: const Text('Definir ponto de partida'),
              ),
            if (canOpenExternal)
              if (route != null || !_canCalculate)
                FilledButton.icon(
                  onPressed: _openingMaps ? null : _openExternal,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir no app de mapas'),
                )
              else
                TextButton.icon(
                  onPressed: _openingMaps ? null : _openExternal,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir no app de mapas'),
                ),
          ],
        ),
      ),
    );
  }

  String _failureMessage(HealthApiFailureKind kind) => switch (kind) {
    HealthApiFailureKind.connection =>
      'Sem conexão com o servidor. Verifique a conexão e tente novamente.',
    HealthApiFailureKind.timeout =>
      'O cálculo da rota demorou demais. Tente novamente.',
    HealthApiFailureKind.server =>
      'Roteamento indisponível. Tente novamente em instantes.',
    HealthApiFailureKind.client ||
    HealthApiFailureKind.invalidResponse => 'Não foi possível calcular a rota.',
  };
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.route,
    required this.origin,
    required this.destination,
  });

  final DrivingRoute route;
  final UserLocationOrigin origin;
  final LatLng destination;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 240,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: destination,
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints([
                  origin.coordinate,
                  destination,
                  ...route.polyline,
                ]),
                padding: const EdgeInsets.all(36),
                maxZoom: 16,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                    point: origin.coordinate,
                    width: 40,
                    height: 40,
                    child: Icon(
                      origin.isManual ? Icons.place : Icons.my_location,
                      color: AppColors.blue,
                      semanticLabel: 'Ponto de partida',
                    ),
                  ),
                  Marker(
                    point: destination,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.local_hospital,
                      color: AppColors.navy,
                      semanticLabel: 'Unidade de destino',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Align(
            alignment: Alignment.bottomLeft,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
