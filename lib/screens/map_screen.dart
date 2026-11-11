import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/repositories/route_repository.dart';
import 'package:rotasaude/screens/availability_screen.dart';
import 'package:rotasaude/screens/location_selection_screen.dart';
import 'package:rotasaude/screens/route_preview_screen.dart';
import 'package:rotasaude/screens/unit_details_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:rotasaude/services/user_location_session_store.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/theme/app_theme.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

enum _DiscoveryTab { map, list, compare }

enum _LoadStatus { loading, loaded, failed }

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.userOrigin,
    this.userLocationAvailable = true,
    this.now,
    this.operationalRefreshInterval = const Duration(minutes: 1),
    this.repository,
    this.routeRepository,
    this.locationAccess,
    this.sessionStore,
    this.onUserOriginChanged,
    this.onSwitchToGps,
    this.onChooseManualOnMap,
    super.key,
  });

  final UserLocationOrigin userOrigin;

  /// Quando falso, distâncias em linha reta não são calculadas.
  final bool userLocationAvailable;

  final LocationAccess? locationAccess;
  final UserLocationSessionStore? sessionStore;
  final Future<void> Function(UserLocationOrigin origin)? onUserOriginChanged;
  final Future<void> Function()? onSwitchToGps;
  final Future<LatLng?> Function()? onChooseManualOnMap;

  /// Relógio de referência (testes). `null` usa [DateTime.now].
  final DateTime Function()? now;

  /// Periodicidade para reavaliar a janela operacional de 30 minutos.
  final Duration operationalRefreshInterval;

  /// Fonte das unidades. Sem ela, usa a API configurada em [ApiConfig].
  final HealthUnitRepository? repository;

  /// Fonte das rotas. Sem ela, usa a API configurada em [ApiConfig].
  final RouteRepository? routeRepository;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late SearchArea? _area = SearchArea.fromCoordinate(
    widget.userOrigin.coordinate,
  );
  late final HealthUnitRepository _repository =
      widget.repository ?? ApiHealthUnitRepository();
  List<HealthUnit> _units = const [];
  late _LoadStatus _loadStatus = _area?.city == null
      ? _LoadStatus.loaded
      : _LoadStatus.loading;
  HealthApiException? _failure;
  int _loadGeneration = 0;
  _DiscoveryTab _tab = _DiscoveryTab.map;
  TravelMode _travelMode = TravelMode.car;
  String _query = '';
  String? _serviceFilter;
  String _sortOrder = 'Destaque';
  bool _searchExpanded = false;
  String? _selectedUnitId;
  bool _mapUnitSummaryDismissed = false;
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  Timer? _operationalRefreshTimer;

  LatLng? _cachedDistanceUser;
  int _cachedDistanceUnitsGeneration = -1;
  Map<String, double?> _straightLineKmByUnitId = const {};

  LatLng? get _userPosition =>
      widget.userLocationAvailable ? widget.userOrigin.coordinate : null;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  UnitOperationalData? _operationalAt(HealthUnit unit) =>
      unit.currentOperationalDataAt(_now);

  @override
  void initState() {
    super.initState();
    _loadUnits();
    final interval = widget.operationalRefreshInterval;
    if (interval > Duration.zero) {
      _operationalRefreshTimer = Timer.periodic(interval, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userOrigin.coordinate != widget.userOrigin.coordinate ||
        oldWidget.userOrigin.kind != widget.userOrigin.kind ||
        oldWidget.userLocationAvailable != widget.userLocationAvailable ||
        oldWidget.userOrigin.gpsMayBeStale != widget.userOrigin.gpsMayBeStale) {
      _invalidateStraightLineCache();
    }
    if (oldWidget.userOrigin.coordinate != widget.userOrigin.coordinate) {
      _area = SearchArea.fromCoordinate(widget.userOrigin.coordinate);
    }
    if (oldWidget.operationalRefreshInterval !=
        widget.operationalRefreshInterval) {
      _operationalRefreshTimer?.cancel();
      final interval = widget.operationalRefreshInterval;
      if (interval > Duration.zero) {
        _operationalRefreshTimer = Timer.periodic(interval, (_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _invalidateStraightLineCache() {
    _cachedDistanceUser = null;
    _cachedDistanceUnitsGeneration = -1;
    _straightLineKmByUnitId = const {};
  }

  Map<String, double?> get _straightLineKmLookup {
    final user = _userPosition;
    if (_cachedDistanceUser == user &&
        _cachedDistanceUnitsGeneration == _loadGeneration) {
      return _straightLineKmByUnitId;
    }
    _cachedDistanceUser = user;
    _cachedDistanceUnitsGeneration = _loadGeneration;
    _straightLineKmByUnitId = buildStraightLineDistanceLookup(
      userPosition: user,
      units: _units,
    );
    return _straightLineKmByUnitId;
  }

  double? _straightLineKm(HealthUnit unit) => _straightLineKmLookup[unit.id];

  @override
  void dispose() {
    _operationalRefreshTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

  /// Consulta as unidades da área atual. O chamador marca o estado de
  /// carregamento antes; respostas de consultas substituídas são ignoradas.
  Future<void> _loadUnits() async {
    final generation = ++_loadGeneration;
    final city = _area?.city;
    if (city == null) return;
    HealthApiException? failure;
    List<HealthUnit> units = const [];
    try {
      units = await _repository.fetchUnits(city: city);
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
      _failure = failure;
      _units = units;
      _invalidateStraightLineCache();
      _loadStatus = failure == null ? _LoadStatus.loaded : _LoadStatus.failed;
      if (!units.any((unit) => unit.id == _selectedUnitId)) {
        _selectedUnitId = units.firstOrNull?.id;
        _mapUnitSummaryDismissed = false;
      }
    });
  }

  void _retryLoad() {
    setState(() {
      _loadStatus = _LoadStatus.loading;
      _failure = null;
    });
    _loadUnits();
  }

  List<HealthUnit> get _visibleUnits {
    final query = _query.trim().toLowerCase();
    final units = _units.where((unit) {
      final matchesQuery =
          query.isEmpty ||
          unit.name.toLowerCase().contains(query) ||
          unit.services.any((service) => service.toLowerCase().contains(query));
      final matchesService =
          _serviceFilter == null || unit.services.contains(_serviceFilter);
      return matchesQuery && matchesService;
    }).toList();
    final distances = _straightLineKmLookup;
    if (_sortOrder == 'Menor espera') {
      units.sort((a, b) {
        final aWait = _operationalAt(a)?.waitMinutes;
        final bWait = _operationalAt(b)?.waitMinutes;
        if (aWait == null && bWait == null) return a.name.compareTo(b.name);
        if (aWait == null) return 1;
        if (bWait == null) return -1;
        return aWait.compareTo(bWait);
      });
    } else if (_sortOrder == 'Proximidade') {
      units.sort(
        (a, b) => compareUnitsByStraightLineDistance(
          a,
          distances[a.id],
          b,
          distances[b.id],
        ),
      );
    }
    return units;
  }

  HealthUnit? get _selectedUnit {
    final selectedId = _selectedUnitId;
    if (selectedId == null) return null;
    return _visibleUnits.where((unit) => unit.id == selectedId).firstOrNull;
  }

  List<String> get _services =>
      _units.expand((unit) => unit.services).toSet().toList()..sort();

  Future<void> _chooseArea() async {
    final area = await Navigator.of(context).push<SearchArea>(
      MaterialPageRoute<SearchArea>(
        builder: (_) => LocationSelectionScreen(currentArea: _area),
      ),
    );
    if (!mounted || area == null) return;
    setState(() {
      _area = area;
      _units = const [];
      _invalidateStraightLineCache();
      _failure = null;
      _loadStatus = area.city == null
          ? _LoadStatus.loaded
          : _LoadStatus.loading;
      _selectedUnitId = null;
      _query = '';
      _serviceFilter = null;
      _searchController.clear();
    });
    _loadUnits();
  }

  Future<void> _showDetails(HealthUnit unit) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UnitDetailsScreen(
          unit: unit,
          straightLineKm: _straightLineKm(unit),
          operationalNow: _now,
          onRoute: _operationalAt(unit) == null
              ? null
              : (mode) => _showRoute(unit, mode),
        ),
      ),
    );
  }

  Future<void> _showRoute(HealthUnit unit, TravelMode mode) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoutePreviewScreen(
          unit: unit,
          initialMode: mode,
          initialOrigin: widget.userOrigin.coordinate,
          originKind: widget.userOrigin.kind,
          routeRepository: widget.routeRepository,
          locationAccess: widget.locationAccess,
          onChooseManualOrigin: widget.onChooseManualOnMap,
          onSwitchToGps: widget.onSwitchToGps,
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _tab = _DiscoveryTab.values[index]);
  }

  void _collapseSearch() {
    FocusScope.of(context).unfocus();
    setState(() => _searchExpanded = false);
  }

  void _updateServiceFilter(String? service) {
    setState(() {
      _serviceFilter = service;
      if (!_visibleUnits.any((unit) => unit.id == _selectedUnitId)) {
        _selectedUnitId = _visibleUnits.firstOrNull?.id;
        _mapUnitSummaryDismissed = false;
      }
    });
  }

  void _selectMapUnit(String unitId) {
    setState(() {
      if (_selectedUnitId != unitId) {
        _selectedUnitId = unitId;
        _mapUnitSummaryDismissed = false;
      }
    });
  }

  void _dismissMapUnitSummary() {
    setState(() => _mapUnitSummaryDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.userOrigin.isDeviceGps &&
                widget.userOrigin.gpsMayBeStale)
              const _StalePositionNotice(),
            if (_tab == _DiscoveryTab.map)
              _DiscoveryHeader(
                area: _area,
                userOrigin: widget.userOrigin,
                onChooseArea: _chooseArea,
                onShowAvailability: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const AvailabilityScreen(),
                  ),
                ),
                onSwitchToGps: widget.onSwitchToGps,
                onChooseManualOnMap: widget.onChooseManualOnMap,
              ),
            if (_tab == _DiscoveryTab.map ||
                _searchExpanded ||
                _query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {
                    _query = value;
                    if (_selectedUnit == null) {
                      _selectedUnitId = _visibleUnits.firstOrNull?.id;
                      _mapUnitSummaryDismissed = false;
                    }
                  }),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Busque unidade ou atendimento',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _query = '';
                              if (_tab != _DiscoveryTab.map) {
                                _searchExpanded = false;
                              }
                            }),
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            Expanded(child: _buildTab()),
            NavigationBar(
              selectedIndex: _tab.index,
              onDestinationSelected: _selectTab,
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
      ),
    );
  }

  Widget _buildTab() => switch (_tab) {
    _DiscoveryTab.map => _buildMap(),
    _DiscoveryTab.list => _buildList(),
    _DiscoveryTab.compare => _buildComparison(),
  };

  /// Carregamento ou falha da consulta; `null` quando há resultado a mostrar.
  Widget? _buildLoadState() => switch (_loadStatus) {
    _LoadStatus.loading => const _LoadingUnits(),
    _LoadStatus.failed => _LoadFailure(
      kind: _failure?.kind ?? HealthApiFailureKind.connection,
      onRetry: _retryLoad,
    ),
    _LoadStatus.loaded => null,
  };

  Widget _buildMap() {
    final loadState = _buildLoadState();
    if (loadState != null) return loadState;
    final units = _visibleUnits;
    final coord = widget.userOrigin.coordinate;
    final center = _area?.center ?? coord;
    final withinDemoArea =
        _area?.id == SearchArea.goiania.id &&
        Geolocator.distanceBetween(
              coord.latitude,
              coord.longitude,
              SearchArea.goiania.center.latitude,
              SearchArea.goiania.center.longitude,
            ) <=
            35000;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: center, initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.edufrancadev.rotasaude',
              errorTileCallback: (tile, error, stackTrace) {},
            ),
            MarkerLayer(
              markers: [
                if (withinDemoArea)
                  Marker(
                    point: coord,
                    width: 52,
                    height: 52,
                    child: Semantics(
                      label: widget.userOrigin.mapMarkerSemanticsLabel,
                      child: Icon(
                        widget.userOrigin.isManual
                            ? Icons.place_rounded
                            : Icons.my_location_rounded,
                        size: 34,
                        color: AppColors.blue,
                        shadows: [Shadow(color: Colors.white, blurRadius: 8)],
                      ),
                    ),
                  ),
                for (final unit in units)
                  if (isValidGeographicPosition(unit.position))
                    Marker(
                      point: unit.position,
                      width: 120,
                      height: 66,
                      alignment: const Alignment(0, 0.36),
                      child: Semantics(
                        excludeSemantics: true,
                        button: true,
                        label:
                            '${unit.name}, ${unit.operationalSummaryAt(_now)}',
                        selected: _selectedUnitId == unit.id,
                        onTap: () => _selectMapUnit(unit.id),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _selectMapUnit(unit.id),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        unit.currentAvailability?.color ??
                                        AppColors.muted,
                                    width: 3,
                                  ),
                                ),
                                child: SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Icon(
                                    Icons.local_hospital_outlined,
                                    color:
                                        unit.currentAvailability?.color ??
                                        AppColors.muted,
                                    size: 24,
                                  ),
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  child: Text(
                                    unit.name.replaceFirst(
                                      'UPA Exemplo ',
                                      'UPA ',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),
        const Align(
          alignment: Alignment.topLeft,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10, color: AppColors.navy),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_area == null || units.isEmpty)
          Center(
            child: _EmptyResults(
              title: _area == null
                  ? 'Escolha uma cidade para consultar unidades'
                  : _units.isEmpty
                  ? 'Nenhuma unidade cadastrada nesta área'
                  : 'Nenhuma unidade encontrada',
              message: _area == null
                  ? 'O ponto escolhido está fora das áreas com unidades '
                        'cadastradas.'
                  : _units.isEmpty
                  ? 'Você pode alterar a cidade a qualquer momento.'
                  : 'Tente outra busca ou limpe os filtros aplicados.',
              actionLabel: _units.isEmpty || _area == null
                  ? 'Escolher localização'
                  : 'Limpar filtros',
              onAction: _units.isEmpty || _area == null
                  ? _chooseArea
                  : () => setState(() {
                      _query = '';
                      _searchController.clear();
                      _serviceFilter = null;
                    }),
            ),
          )
        else if (_selectedUnit != null && !_mapUnitSummaryDismissed)
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.38,
              ),
              child: SingleChildScrollView(
                child: _DismissibleMapUnitSummary(
                  key: const ValueKey('map-unit-summary-card'),
                  onDismissed: _dismissMapUnitSummary,
                  child: _MapUnitSummary(
                    unit: _selectedUnit!,
                    operational: _operationalAt(_selectedUnit!),
                    straightLineKm: _straightLineKm(_selectedUnit!),
                    now: _now,
                    onDetails: () => _showDetails(_selectedUnit!),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildList() {
    final loadState = _buildLoadState();
    final units = _visibleUnits;
    final Widget body;
    if (loadState != null) {
      body = loadState;
    } else if (_units.isEmpty) {
      body = _EmptyResults(
        title: 'Nenhuma unidade cadastrada nesta área',
        message: 'Você pode alterar a cidade a qualquer momento.',
        actionLabel: 'Escolher localização',
        onAction: _chooseArea,
      );
    } else if (units.isEmpty) {
      body = _EmptyResults(
        title: 'Nenhuma unidade encontrada',
        message: 'Tente outra busca ou limpe os filtros aplicados.',
        actionLabel: 'Limpar filtros',
        onAction: () => setState(() {
          _query = '';
          _searchController.clear();
          _serviceFilter = null;
        }),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
        itemCount: units.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final unit = units[index];
          return _UnitListCard(
            unit: unit,
            operational: _operationalAt(unit),
            straightLineKm: _straightLineKm(unit),
            now: _now,
            selected: _selectedUnitId == unit.id,
            onSelect: () => setState(() => _selectedUnitId = unit.id),
            onDetails: () => _showDetails(unit),
          );
        },
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Unidades próximas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Alterar localização consultada',
                    onPressed: _chooseArea,
                    icon: const Icon(Icons.place_outlined),
                  ),
                  if (_query.isEmpty)
                    IconButton(
                      tooltip: _searchExpanded
                          ? 'Fechar busca'
                          : 'Buscar unidade',
                      onPressed: _searchExpanded
                          ? _collapseSearch
                          : () => setState(() => _searchExpanded = true),
                      icon: Icon(_searchExpanded ? Icons.close : Icons.search),
                    ),
                ],
              ),
              if (loadState == null) ...[
                Text(
                  '${units.length} ${units.length == 1 ? 'unidade' : 'unidades'} · ${_area?.name ?? 'Área não definida'}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                if (units.any((unit) => unit.isDemo)) ...[
                  const SizedBox(height: 6),
                  const IllustrativeNotice(compact: true, short: true),
                ],
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _FilterDropdown<String?>(
                  label: 'Atendimento',
                  value: _serviceFilter,
                  items: [null, ..._services],
                  itemLabel: (value) => value ?? 'Todos',
                  onChanged: _updateServiceFilter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown<String>(
                  label: 'Ordenar',
                  value: _sortOrder,
                  items: const ['Destaque', 'Menor espera', 'Proximidade'],
                  itemLabel: (value) => value,
                  onChanged: (value) => setState(() => _sortOrder = value),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildComparison() {
    final loadState = _buildLoadState();
    final units = _visibleUnits;
    final Widget body;
    if (loadState != null) {
      body = loadState;
    } else if (units.isEmpty) {
      body = const _EmptyResults(
        title: 'Nenhuma unidade para comparar',
        message: 'Altere a cidade ou os filtros da lista.',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
        itemCount: units.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final unit = units[index];
          return _ComparisonCard(
            unit: unit,
            operational: _operationalAt(unit),
            straightLineKm: _straightLineKm(unit),
            now: _now,
            mode: _travelMode,
            selected: _selectedUnitId == unit.id,
            onSelect: () => setState(() => _selectedUnitId = unit.id),
            onDetails: () => _showDetails(unit),
          );
        },
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comparar unidades',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Alterar localização consultada',
                    onPressed: _chooseArea,
                    icon: const Icon(Icons.place_outlined),
                  ),
                  if (_query.isEmpty)
                    IconButton(
                      tooltip: _searchExpanded
                          ? 'Fechar busca'
                          : 'Buscar unidade',
                      onPressed: _searchExpanded
                          ? _collapseSearch
                          : () => setState(() => _searchExpanded = true),
                      icon: Icon(_searchExpanded ? Icons.close : Icons.search),
                    ),
                ],
              ),
              Text(
                'Compare espera, deslocamento e atendimento',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
              if (units.any((unit) => unit.isDemo)) ...[
                const SizedBox(height: 4),
                const IllustrativeNotice(compact: true, short: true),
              ],
              const SizedBox(height: 4),
              SegmentedButton<TravelMode>(
                style: AppTheme.primarySegmentedButtonStyle,
                segments: const [
                  ButtonSegment(value: TravelMode.car, label: Text('Carro')),
                  ButtonSegment(value: TravelMode.bus, label: Text('Ônibus')),
                ],
                selected: {_travelMode},
                onSelectionChanged: (selection) =>
                    setState(() => _travelMode = selection.first),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({
    required this.area,
    required this.userOrigin,
    required this.onChooseArea,
    required this.onShowAvailability,
    this.onSwitchToGps,
    this.onChooseManualOnMap,
  });

  final SearchArea? area;
  final UserLocationOrigin userOrigin;
  final VoidCallback onChooseArea;
  final VoidCallback onShowAvailability;
  final Future<void> Function()? onSwitchToGps;
  final Future<LatLng?> Function()? onChooseManualOnMap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RotaSaúde',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton.icon(
                  onPressed: onChooseArea,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 42),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: const Icon(Icons.place_outlined, size: 18),
                  label: Text(area?.name ?? 'Escolher cidade'),
                ),
                if (onSwitchToGps != null || onChooseManualOnMap != null)
                  TextButton.icon(
                    onPressed: userOrigin.isManual
                        ? onSwitchToGps
                        : onChooseManualOnMap,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 40),
                      alignment: Alignment.centerLeft,
                    ),
                    icon: Icon(
                      userOrigin.isManual
                          ? Icons.my_location_outlined
                          : Icons.edit_location_alt_outlined,
                      size: 18,
                    ),
                    label: Text(
                      userOrigin.isManual
                          ? 'Usar GPS do aparelho'
                          : 'Escolher ponto no mapa',
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Entenda os indicadores de disponibilidade',
            onPressed: onShowAvailability,
            icon: const Icon(Icons.info_outline),
            color: AppColors.blue,
          ),
        ],
      ),
    );
  }
}

class _StalePositionNotice extends StatelessWidget {
  const _StalePositionNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Material(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sua localização pode estar desatualizada.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.navy, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DismissibleMapUnitSummary extends StatefulWidget {
  const _DismissibleMapUnitSummary({
    required this.onDismissed,
    required this.child,
    super.key,
  });

  final VoidCallback onDismissed;
  final Widget child;

  @override
  State<_DismissibleMapUnitSummary> createState() =>
      _DismissibleMapUnitSummaryState();
}

class _DismissibleMapUnitSummaryState
    extends State<_DismissibleMapUnitSummary> {
  static const _dismissDragThreshold = 72.0;

  double _dragExtent = 0;

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldDismiss =
        _dragExtent >= _dismissDragThreshold || velocity > 700;
    if (shouldDismiss) {
      widget.onDismissed();
      return;
    }
    setState(() => _dragExtent = 0);
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (1 - (_dragExtent / 180)).clamp(0.35, 1.0).toDouble();
    return Semantics(
      label: 'Resumo da unidade. Arraste para baixo para ocultar.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragExtent = (_dragExtent + details.delta.dy).clamp(0.0, 220.0);
          });
        },
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragExtent),
          child: Opacity(opacity: opacity, child: widget.child),
        ),
      ),
    );
  }
}

class _MapUnitSummary extends StatelessWidget {
  const _MapUnitSummary({
    required this.unit,
    required this.operational,
    required this.straightLineKm,
    required this.now,
    required this.onDetails,
  });

  final HealthUnit unit;
  final UnitOperationalData? operational;
  final double? straightLineKm;
  final DateTime now;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Arraste para baixo para ocultar o resumo',
              container: true,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Text(
              unit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            UnitAvailabilityStatus(unit: unit, now: now),
            if (operational != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  MetricColumn(
                    value: '${operational!.waitMinutes ?? '—'} min',
                    label: 'espera',
                  ),
                  MetricColumn(
                    value: formatStraightLineDistanceValue(straightLineKm),
                    label: straightLineDistanceMetricLabel,
                  ),
                  MetricColumn(
                    value: unit.carRoute?.durationMinutes == null
                        ? carRouteDurationUnavailable
                        : '${unit.carRoute!.durationMinutes} min',
                    label: carRouteDurationMetricLabel,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onDetails,
              child: const Text('Ver detalhes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitListCard extends StatelessWidget {
  const _UnitListCard({
    required this.unit,
    required this.operational,
    required this.straightLineKm,
    required this.now,
    required this.selected,
    required this.onSelect,
    required this.onDetails,
  });

  final HealthUnit unit;
  final UnitOperationalData? operational;
  final double? straightLineKm;
  final DateTime now;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      key: ValueKey('unit-card-${unit.id}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.blue : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        unit.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ver detalhes de ${unit.name}',
                      onPressed: onDetails,
                      icon: const Icon(Icons.arrow_forward, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                UnitAvailabilityStatus(unit: unit, now: now),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    MetricColumn(
                      value: '${operational?.waitMinutes ?? '—'} min',
                      label: 'espera',
                    ),
                    MetricColumn(
                      value: formatStraightLineDistanceValue(straightLineKm),
                      label: straightLineDistanceMetricLabel,
                      alignment: CrossAxisAlignment.center,
                    ),
                    MetricColumn(
                      value: unit.carRoute?.durationMinutes == null
                          ? carRouteDurationUnavailable
                          : '${unit.carRoute!.durationMinutes} min',
                      label: carRouteDurationMetricLabel,
                      alignment: CrossAxisAlignment.end,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.unit,
    required this.operational,
    required this.straightLineKm,
    required this.now,
    required this.mode,
    required this.selected,
    required this.onSelect,
    required this.onDetails,
  });

  final HealthUnit unit;
  final UnitOperationalData? operational;
  final double? straightLineKm;
  final DateTime now;
  final TravelMode mode;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final route = unit.routeFor(mode);
    return Card.outlined(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.blue : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        unit.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ver detalhes de ${unit.name}',
                      onPressed: onDetails,
                      icon: const Icon(Icons.arrow_forward, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                UnitAvailabilityStatus(unit: unit, now: now),
                const SizedBox(height: 6),
                Row(
                  children: [
                    MetricColumn(
                      value: operational?.waitMinutes == null
                          ? 'Indisponível'
                          : '${operational!.waitMinutes} min',
                      label: 'espera',
                      compact: true,
                    ),
                    MetricColumn(
                      value: route == null
                          ? 'Indisponível'
                          : '${route.durationMinutes} min',
                      label: mode.label,
                      alignment: CrossAxisAlignment.center,
                      compact: true,
                    ),
                    MetricColumn(
                      value: formatStraightLineDistanceValue(straightLineKm),
                      label: straightLineDistanceMetricLabel,
                      alignment: CrossAxisAlignment.end,
                      compact: true,
                    ),
                  ],
                ),
                if (unit.services.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    unit.services.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          onChanged: (item) {
            if (item != null) onChanged(item);
          },
          items: [
            for (final item in items)
              DropdownMenuItem(value: item, child: Text(itemLabel(item))),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({
    required this.title,
    required this.message,
    this.icon = Icons.place_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
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
      child: _EmptyResults(
        title: title,
        message: message,
        icon: icon,
        actionLabel: 'Tentar novamente',
        onAction: onRetry,
      ),
    );
  }
}
