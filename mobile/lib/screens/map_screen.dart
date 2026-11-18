import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/repositories/route_repository.dart';
import 'package:rotasaude/screens/availability_screen.dart';
import 'package:rotasaude/screens/discovery/discovery_comparison_tab.dart';
import 'package:rotasaude/screens/discovery/discovery_empty_results.dart';
import 'package:rotasaude/screens/discovery/discovery_list_tab.dart';
import 'package:rotasaude/screens/discovery/discovery_map_tab.dart';
import 'package:rotasaude/screens/location_selection_screen.dart';
import 'package:rotasaude/screens/origin_selection_screen.dart';
import 'package:rotasaude/screens/route_preview_screen.dart';
import 'package:rotasaude/screens/unit_details_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/search_text.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:rotasaude/theme/app_colors.dart';

enum _DiscoveryTab { map, list, compare }

enum _SortOrder {
  name('Nome (A–Z)'),
  wait('Menor espera'),
  distance('Proximidade');

  const _SortOrder(this.label);
  final String label;
}

enum _LoadStatus { loading, loaded, failed }

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.userOrigin,
    this.initialArea,
    this.startInList = false,
    this.userLocationAvailable = true,
    this.now,
    this.operationalRefreshInterval = const Duration(minutes: 1),
    this.repository,
    this.routeRepository,
    this.locationAccess,
    this.onUserOriginChanged,
    this.onAreaChanged,
    super.key,
  });

  final UserLocationOrigin? userOrigin;
  final SearchArea? initialArea;
  final bool startInList;
  final bool userLocationAvailable;
  final LocationAccess? locationAccess;
  final Future<void> Function(UserLocationOrigin origin)? onUserOriginChanged;
  final ValueChanged<SearchArea>? onAreaChanged;
  final DateTime Function()? now;
  final Duration operationalRefreshInterval;
  final HealthUnitRepository? repository;
  final RouteRepository? routeRepository;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late UserLocationOrigin? _origin = widget.userOrigin;
  late SearchArea? _area = widget.initialArea ?? _suggestedArea;
  late _DiscoveryTab _tab = widget.startInList
      ? _DiscoveryTab.list
      : _DiscoveryTab.map;
  late final _repository = widget.repository ?? ApiHealthUnitRepository();
  RouteRepository? _ownedRoutes;
  RouteRepository get _routes =>
      widget.routeRepository ?? (_ownedRoutes ??= ApiRouteRepository());

  List<HealthUnit> _units = const [];
  final _comparedIds = <String>[];
  final _carMinutes = <String, int>{};
  bool _calculatingTimes = false;
  bool _comparisonRequestFailed = false;
  int _comparisonRevision = 0;
  late _LoadStatus _loadStatus = _area == null
      ? _LoadStatus.loaded
      : _LoadStatus.loading;
  HealthApiException? _failure;
  int _loadGeneration = 0;
  TravelMode _travelMode = TravelMode.car;
  String? _serviceFilter;
  _SortOrder _sortOrder = _SortOrder.name;
  String? _selectedUnitId;
  bool _summaryDismissed = false;
  final _searchController = TextEditingController();
  MapCamera? _mapCamera;
  PageStorageBucket _tabStorage = PageStorageBucket();
  Timer? _operationalTimer;
  List<HealthUnit>? _distanceUnits;
  LatLng? _distanceOrigin;
  Map<String, double?> _distances = const {};

  Map<String, double?> get _distanceLookup {
    final origin = _position;
    if (!identical(_units, _distanceUnits) || origin != _distanceOrigin) {
      _distanceUnits = _units;
      _distanceOrigin = origin;
      _distances = buildStraightLineDistanceLookup(
        userPosition: origin,
        units: _units,
      );
    }
    return _distances;
  }

  LatLng? get _position =>
      widget.userLocationAvailable ? _origin?.coordinate : null;
  SearchArea? get _suggestedArea =>
      _origin == null ? null : SearchArea.fromCoordinate(_origin!.coordinate);
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _startClock();
  }

  void _startClock() {
    _operationalTimer?.cancel();
    final interval = widget.operationalRefreshInterval;
    if (interval > Duration.zero) {
      _operationalTimer = Timer.periodic(interval, (_) => setState(() {}));
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operationalRefreshInterval !=
        widget.operationalRefreshInterval) {
      _startClock();
    }
    final oldPosition = oldWidget.userLocationAvailable
        ? _origin?.coordinate
        : null;
    if (oldWidget.userOrigin != widget.userOrigin) _origin = widget.userOrigin;
    if (oldPosition != _position) _resetTravelTimes();
    final suggested = _suggestedArea;
    if (_area == null && suggested != null) {
      _area = suggested;
      _loadStatus = _LoadStatus.loading;
      _loadUnits();
    }
  }

  @override
  void dispose() {
    _operationalTimer?.cancel();
    _searchController.dispose();
    if (widget.repository == null) _repository.close();
    _ownedRoutes?.close();
    super.dispose();
  }

  void _resetTravelTimes() {
    _comparisonRevision++;
    _calculatingTimes = false;
    _comparisonRequestFailed = false;
    _carMinutes.clear();
  }

  Future<void> _loadUnits() async {
    final generation = ++_loadGeneration;
    final city = _area?.city;
    if (city == null) return;
    try {
      final units = await _repository.fetchUnits(city: city);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _units = units;
        _comparedIds.removeWhere((id) => !units.any((unit) => unit.id == id));
        _loadStatus = _LoadStatus.loaded;
        _failure = null;
      });
    } on Exception catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _failure = error is HealthApiException
            ? error
            : const HealthApiException(
                HealthApiFailureKind.invalidResponse,
                'Resposta inválida.',
              );
        _loadStatus = _LoadStatus.failed;
      });
    }
  }

  void _retryLoad() {
    setState(() => _loadStatus = _LoadStatus.loading);
    _loadUnits();
  }

  Future<void> _chooseArea() async {
    final area = await Navigator.of(context).push<SearchArea>(
      MaterialPageRoute(
        builder: (_) => LocationSelectionScreen(currentArea: _area),
      ),
    );
    if (!mounted || area == null || area.id == _area?.id) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _area = area;
      _tab = _DiscoveryTab.list;
      _units = const [];
      _comparedIds.clear();
      _selectedUnitId = null;
      _summaryDismissed = false;
      _mapCamera = null;
      _tabStorage = PageStorageBucket();
      _resetTravelTimes();
      _loadStatus = _LoadStatus.loading;
    });
    widget.onAreaChanged?.call(area);
    _loadUnits();
  }

  Future<UserLocationOrigin?> _chooseOrigin() async {
    final origin = await Navigator.of(context).push<UserLocationOrigin>(
      MaterialPageRoute(
        builder: (_) => OriginSelectionScreen(
          locationAccess: widget.locationAccess ?? const DeviceLocationAccess(),
          mapCenter: _origin?.coordinate ?? _area?.center,
        ),
      ),
    );
    if (!mounted || origin == null) return null;
    setState(() {
      if (_origin?.coordinate != origin.coordinate) _resetTravelTimes();
      _origin = origin;
    });
    await widget.onUserOriginChanged?.call(origin);
    return origin;
  }

  Future<void> _changeSort(_SortOrder order) async {
    if (order == _SortOrder.distance && _position == null) {
      if (await _chooseOrigin() == null || !mounted) return;
    }
    setState(() => _sortOrder = order);
  }

  void _searchUpdated() => setState(() => _summaryDismissed = false);

  void _setService(String? value) => setState(() {
    _serviceFilter = value;
    _summaryDismissed = false;
  });

  Future<void> _toggleComparison(HealthUnit unit) async {
    if (_comparedIds.contains(unit.id)) {
      setState(() => _comparedIds.remove(unit.id));
      return;
    }
    if (_comparedIds.length < 2) {
      setState(() => _comparedIds.add(unit.id));
      return;
    }
    final selected = _selectedForComparison;
    final replaced = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Substituir unidade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Qual unidade você quer substituir por ${unit.name}?'),
            const SizedBox(height: 10),
            for (final old in selected)
              OutlinedButton(
                onPressed: () => Navigator.pop(context, old.id),
                child: Text(old.name),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (!mounted || replaced == null) return;
    final index = _comparedIds.indexOf(replaced);
    if (index != -1) setState(() => _comparedIds[index] = unit.id);
  }

  List<HealthUnit> get _selectedForComparison => [
    for (final id in _comparedIds) _units.firstWhere((unit) => unit.id == id),
  ];

  Future<void> _calculateComparisonTimes() async {
    if (_calculatingTimes) return;
    final origin = _position ?? (await _chooseOrigin())?.coordinate;
    if (!mounted || origin == null || _calculatingTimes) return;
    final missing = _selectedForComparison
        .where(
          (unit) =>
              !_carMinutes.containsKey(unit.id) &&
              isValidGeographicPosition(unit.position),
        )
        .toList();
    if (missing.isEmpty) return;
    final revision = ++_comparisonRevision;
    setState(() {
      _calculatingTimes = true;
      _comparisonRequestFailed = false;
    });
    for (final (index, unit) in missing.indexed) {
      // O provedor público impõe um intervalo entre chamadas sem cache.
      if (index > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
      if (!mounted || revision != _comparisonRevision) return;
      if (!_comparedIds.contains(unit.id)) continue;
      try {
        final route = await _routes.fetchDrivingRoute(
          origin: origin,
          unitId: unit.id,
        );
        if (!mounted || revision != _comparisonRevision) return;
        setState(() => _carMinutes[unit.id] = route.durationMinutes);
      } on Exception {
        if (!mounted || revision != _comparisonRevision) return;
        setState(() => _comparisonRequestFailed = true);
      }
    }
    if (mounted && revision == _comparisonRevision) {
      setState(() => _calculatingTimes = false);
    }
  }

  void _showDetails(HealthUnit unit, double? distance) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UnitDetailsScreen(
          unit: unit,
          straightLineKm: distance,
          now: widget.now,
          onRoute: () => _showRoute(unit),
        ),
      ),
    );
  }

  void _showRoute(HealthUnit unit) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RoutePreviewScreen(
          unit: unit,
          initialOrigin: _position == null ? null : _origin,
          routeRepository: _routes,
          onChooseOrigin: _chooseOrigin,
          onCalculated: (origin, route) {
            if (mounted && _position == origin) {
              setState(() => _carMinutes[unit.id] = route.durationMinutes);
            }
          },
          now: widget.now,
        ),
      ),
    );
  }

  void _selectTab(_DiscoveryTab tab) {
    if (_tab == tab) return;
    FocusScope.of(context).unfocus();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final query = normalizedSearchText(_searchController.text);
    final matchingQuery = _units.where(
      (unit) =>
          query.isEmpty ||
          normalizedSearchText(unit.name).contains(query) ||
          unit.services.any(
            (service) => normalizedSearchText(service).contains(query),
          ),
    );
    final visible = matchingQuery
        .where(
          (unit) =>
              _serviceFilter == null || unit.services.contains(_serviceFilter),
        )
        .toList();
    final distances = _distanceLookup;
    int byName(HealthUnit a, HealthUnit b) =>
        normalizedSearchText(a.name).compareTo(normalizedSearchText(b.name));
    visible.sort(
      (a, b) => switch (_sortOrder) {
        _SortOrder.wait =>
          (a.currentOperationalDataAt(now)?.waitMinutes ?? double.infinity)
              .compareTo(
                b.currentOperationalDataAt(now)?.waitMinutes ?? double.infinity,
              )
              .thenBy(() => byName(a, b)),
        _SortOrder.distance => compareUnitsByStraightLineDistance(
          a,
          distances[a.id],
          b,
          distances[b.id],
        ),
        _SortOrder.name => byName(a, b),
      },
    );
    final unitsState = _unitsState(matchingQuery.isEmpty, visible.isEmpty);
    final compared = _selectedForComparison;
    final selectedUnit =
        visible.where((unit) => unit.id == _selectedUnitId).firstOrNull ??
        visible.firstOrNull;
    final services = {
      ..._units.expand((unit) => unit.services),
      ?_serviceFilter,
    }.toList()..sort();
    final searchedServices = query.isEmpty
        ? const <String>[]
        : services
              .where((service) => normalizedSearchText(service).contains(query))
              .toList();
    final comparedService =
        _serviceFilter ??
        (searchedServices.length == 1 ? searchedServices.single : null);
    final header = _DiscoveryControls(
      area: _area,
      origin: _position == null ? null : _origin,
      showOrigin: _tab == _DiscoveryTab.map || _tab == _DiscoveryTab.compare,
      onCity: _chooseArea,
      onOrigin: _chooseOrigin,
      onLegend: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const AvailabilityScreen()),
      ),
      searchController: _searchController,
      onQuery: _searchUpdated,
      selectedService: _serviceFilter,
      services: services,
      onService: _setService,
      sort: _tab == _DiscoveryTab.list ? _sortOrder : null,
      onSort: _changeSort,
    );
    final emptyWithNoCity = _area == null ? unitsState : null;
    final body = switch (_tab) {
      _DiscoveryTab.map => LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * .54,
              ),
              child: SingleChildScrollView(child: header),
            ),
            Expanded(
              child: DiscoveryMapTab(
                area: _area,
                userOrigin: _position == null ? null : _origin,
                initialCamera: _mapCamera,
                onMapEvent: (event) => _mapCamera = event.camera,
                units: visible,
                state: unitsState,
                selectedUnitId: selectedUnit?.id,
                summaryUnit: _summaryDismissed ? null : selectedUnit,
                straightLineKmByUnitId: distances,
                carMinutes: _carMinutes,
                now: now,
                onSelectUnit: (id) => setState(() {
                  _selectedUnitId = id;
                  _summaryDismissed = false;
                }),
                onDismissSummary: () =>
                    setState(() => _summaryDismissed = true),
                onDetails: (unit) => _showDetails(unit, distances[unit.id]),
              ),
            ),
          ],
        ),
      ),
      _DiscoveryTab.list => DiscoveryListTab(
        header: header,
        units: visible,
        state: unitsState,
        now: now,
        distances: distances,
        carMinutes: _carMinutes,
        compared: compared,
        serviceFilter: _serviceFilter,
        onComparison: _toggleComparison,
        onDetails: (unit) => _showDetails(unit, distances[unit.id]),
      ),
      _DiscoveryTab.compare => DiscoveryComparisonTab(
        header: header,
        units: compared,
        visibleIds: visible.map((unit) => unit.id).toSet(),
        state:
            emptyWithNoCity ??
            (_loadStatus != _LoadStatus.loaded ? unitsState : null),
        now: now,
        distances: distances,
        carMinutes: _carMinutes,
        serviceFilter: comparedService,
        travelMode: _travelMode,
        hasOrigin: _position != null,
        calculating: _calculatingTimes,
        calculationFailed: _comparisonRequestFailed,
        onCalculate: _calculateComparisonTimes,
        onChooseOrigin: _chooseOrigin,
        onMode: (mode) => setState(() => _travelMode = mode),
        onSelectUnits: () => _selectTab(_DiscoveryTab.list),
        onRemove: _toggleComparison,
        onDetails: (unit) => _showDetails(unit, distances[unit.id]),
      ),
    };
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageStorage(
          key: ValueKey(_area?.id),
          bucket: _tabStorage,
          child: body,
        ),
      ),
      bottomNavigationBar: keyboard
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_tab == _DiscoveryTab.list && compared.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () => _selectTab(_DiscoveryTab.compare),
                        child: Text('Comparar (${compared.length}/2)'),
                      ),
                    ),
                  ),
                NavigationBar(
                  selectedIndex: _tab.index,
                  onDestinationSelected: (index) =>
                      _selectTab(_DiscoveryTab.values[index]),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.map_outlined),
                      selectedIcon: Icon(Icons.map),
                      label: 'Mapa',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.format_list_bulleted),
                      label: 'Lista',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.compare_arrows),
                      label: 'Comparar',
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget? _unitsState(bool noQueryMatches, bool noVisibleUnits) {
    if (_area == null) {
      return DiscoveryEmptyResults(
        title: 'Escolha uma cidade para consultar unidades',
        message: 'Veja as cidades atendidas pelo RotaSaúde.',
        actionLabel: 'Escolher cidade',
        onAction: _chooseArea,
      );
    }
    if (_loadStatus == _LoadStatus.loading) return const _LoadingUnits();
    if (_loadStatus == _LoadStatus.failed) {
      return _LoadFailure(
        kind: _failure?.kind ?? HealthApiFailureKind.connection,
        onRetry: _retryLoad,
      );
    }
    if (_units.isEmpty) {
      return DiscoveryEmptyResults(
        title: 'Nenhuma unidade cadastrada nesta cidade',
        message: 'Busque em outra cidade atendida pelo RotaSaúde.',
        actionLabel: 'Trocar cidade',
        onAction: _chooseArea,
      );
    }
    if (noVisibleUnits && noQueryMatches) {
      return DiscoveryEmptyResults(
        title: 'Nenhuma unidade encontrada',
        message: 'Tente outro nome de unidade ou serviço.',
        icon: Icons.search_off,
        actionLabel: 'Limpar busca',
        onAction: () {
          _searchController.clear();
          _searchUpdated();
        },
      );
    }
    final filter = _serviceFilter;
    if (noVisibleUnits && filter != null) {
      return DiscoveryEmptyResults(
        title: 'Nenhuma unidade para este filtro',
        message: 'Os resultados da consulta não incluem $filter.',
        icon: Icons.filter_list_off,
        actionLabel: 'Remover filtro de $filter',
        onAction: () => _setService(null),
      );
    }
    return null;
  }
}

extension on int {
  int thenBy(int Function() other) => this == 0 ? other() : this;
}

class _DiscoveryControls extends StatelessWidget {
  const _DiscoveryControls({
    required this.area,
    required this.origin,
    required this.showOrigin,
    required this.onCity,
    required this.onOrigin,
    required this.onLegend,
    required this.searchController,
    required this.onQuery,
    required this.selectedService,
    required this.services,
    required this.onService,
    required this.sort,
    required this.onSort,
  });

  final SearchArea? area;
  final UserLocationOrigin? origin;
  final bool showOrigin;
  final VoidCallback onCity;
  final VoidCallback onOrigin;
  final VoidCallback onLegend;
  final TextEditingController searchController;
  final VoidCallback onQuery;
  final String? selectedService;
  final List<String> services;
  final ValueChanged<String?> onService;
  final _SortOrder? sort;
  final ValueChanged<_SortOrder> onSort;

  @override
  Widget build(BuildContext context) {
    final name = area?.city;
    final city = name == null ? 'Escolher cidade' : 'Buscando em $name';
    final source = origin;
    final originArea = source == null
        ? null
        : SearchArea.fromCoordinate(source.coordinate)?.city;
    final originLabel = source == null
        ? 'Definir ponto de partida'
        : source.isManual
        ? 'Saindo de ${originArea ?? 'um ponto no mapa'} · ponto manual'
        : 'Saindo de ${originArea ?? 'minha localização'} · GPS';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onCity,
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.place_outlined),
                  label: Text(city),
                ),
              ),
              IconButton(
                tooltip: 'Entenda os indicadores de disponibilidade',
                onPressed: onLegend,
                icon: const Icon(Icons.info_outline, color: AppColors.blue),
              ),
            ],
          ),
          if (showOrigin || source != null)
            Wrap(
              children: [
                TextButton.icon(
                  onPressed: onOrigin,
                  icon: const Icon(Icons.trip_origin, size: 18),
                  label: Text(originLabel),
                ),
              ],
            ),
          if (source?.gpsMayBeStale ?? false)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Usando a última posição conhecida.'),
            ),
          TextField(
            controller: searchController,
            onChanged: (_) => onQuery(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Buscar unidade ou serviço',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () {
                        searchController.clear();
                        onQuery();
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              PopupMenuButton<String>(
                tooltip: 'Filtrar por serviço',
                onSelected: (value) => onService(value.isEmpty ? null : value),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: '',
                    child: Text('Todos os serviços'),
                  ),
                  for (final service in services)
                    PopupMenuItem(value: service, child: Text(service)),
                ],
                child: _ControlChip(
                  icon: Icons.tune,
                  label: selectedService ?? 'Serviços',
                  active: selectedService != null,
                ),
              ),
              if (sort case final order?)
                PopupMenuButton<_SortOrder>(
                  tooltip: 'Ordenar unidades',
                  initialValue: order,
                  onSelected: onSort,
                  itemBuilder: (_) => [
                    for (final option in _SortOrder.values)
                      PopupMenuItem(value: option, child: Text(option.label)),
                  ],
                  child: _ControlChip(icon: Icons.sort, label: order.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  const _ControlChip({
    required this.icon,
    required this.label,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active ? true : null,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: active ? const Color(0xFFEAF4FA) : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: active ? AppColors.blue : AppColors.border),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.blue),
          const SizedBox(width: 6),
          Flexible(child: Text(label)),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    ),
  );
}

class _LoadingUnits extends StatelessWidget {
  const _LoadingUnits();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Carregando unidades…',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.kind, required this.onRetry});

  final HealthApiFailureKind kind;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon) = switch (kind) {
      HealthApiFailureKind.connection => (
        'Sem conexão com o servidor',
        'Não conseguimos carregar as unidades. Verifique sua conexão e tente novamente.',
        Icons.cloud_off_outlined,
      ),
      HealthApiFailureKind.timeout => (
        'O servidor demorou a responder',
        'Não conseguimos carregar as unidades a tempo. Tente novamente.',
        Icons.schedule_outlined,
      ),
      HealthApiFailureKind.server => (
        'Serviço indisponível no momento',
        'O servidor encontrou um problema ao buscar as unidades. Tente novamente em instantes.',
        Icons.error_outline,
      ),
      HealthApiFailureKind.client || HealthApiFailureKind.invalidResponse => (
        'Não foi possível carregar as unidades',
        'A resposta do servidor não pôde ser usada. Tente novamente em instantes.',
        Icons.error_outline,
      ),
    };
    return ColoredBox(
      color: AppColors.background,
      child: DiscoveryEmptyResults(
        title: title,
        message: message,
        icon: icon,
        actionLabel: 'Tentar novamente',
        onAction: onRetry,
      ),
    );
  }
}
