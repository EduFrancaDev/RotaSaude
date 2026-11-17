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
import 'package:rotasaude/screens/route_preview_screen.dart';
import 'package:rotasaude/screens/unit_details_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:rotasaude/services/user_location_session_store.dart';
import 'package:rotasaude/theme/app_colors.dart';

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

  void _keepSelectionVisible() {
    final units = _visibleUnits;
    if (units.any((unit) => unit.id == _selectedUnitId)) return;
    _selectedUnitId = units.firstOrNull?.id;
    _mapUnitSummaryDismissed = false;
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

  void _toggleSearch() {
    if (_searchExpanded) FocusScope.of(context).unfocus();
    setState(() => _searchExpanded = !_searchExpanded);
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _serviceFilter = null;
    });
  }

  void _selectListUnit(String unitId) {
    setState(() => _selectedUnitId = unitId);
  }

  void _updateServiceFilter(String? service) {
    setState(() {
      _serviceFilter = service;
      _keepSelectionVisible();
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
                    _keepSelectionVisible();
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

  Widget _buildTab() {
    final loadState = _buildLoadState();
    final units = _visibleUnits;
    final now = _now;
    final distances = _straightLineKmLookup;
    final searchAction = _query.isEmpty && _tab != _DiscoveryTab.map
        ? IconButton(
            tooltip: _searchExpanded ? 'Fechar busca' : 'Buscar unidade',
            onPressed: _toggleSearch,
            icon: Icon(_searchExpanded ? Icons.close : Icons.search),
          )
        : null;
    return switch (_tab) {
      _DiscoveryTab.map =>
        loadState ??
            DiscoveryMapTab(
              area: _area,
              userOrigin: widget.userOrigin,
              mapController: _mapController,
              units: units,
              hasUnits: _units.isNotEmpty,
              selectedUnitId: _selectedUnitId,
              summaryUnit: _mapUnitSummaryDismissed
                  ? null
                  : units
                        .where((unit) => unit.id == _selectedUnitId)
                        .firstOrNull,
              straightLineKmByUnitId: distances,
              now: now,
              onSelectUnit: _selectMapUnit,
              onDismissSummary: _dismissMapUnitSummary,
              onDetails: _showDetails,
              onChooseArea: _chooseArea,
              onClearFilters: _clearFilters,
            ),
      _DiscoveryTab.list => DiscoveryListTab(
        area: _area,
        units: units,
        hasUnits: _units.isNotEmpty,
        loadState: loadState,
        straightLineKmByUnitId: distances,
        now: now,
        selectedUnitId: _selectedUnitId,
        searchAction: searchAction,
        services: _services,
        serviceFilter: _serviceFilter,
        sortOrder: _sortOrder,
        onChooseArea: _chooseArea,
        onSelectUnit: _selectListUnit,
        onDetails: _showDetails,
        onClearFilters: _clearFilters,
        onServiceFilterChanged: _updateServiceFilter,
        onSortOrderChanged: (order) => setState(() => _sortOrder = order),
      ),
      _DiscoveryTab.compare => DiscoveryComparisonTab(
        units: units,
        loadState: loadState,
        straightLineKmByUnitId: distances,
        now: now,
        selectedUnitId: _selectedUnitId,
        searchAction: searchAction,
        travelMode: _travelMode,
        onChooseArea: _chooseArea,
        onSelectUnit: _selectListUnit,
        onDetails: _showDetails,
        onTravelModeChanged: (mode) => setState(() => _travelMode = mode),
      ),
    };
  }

  /// Carregamento ou falha da consulta; `null` quando há resultado a mostrar.
  Widget? _buildLoadState() => switch (_loadStatus) {
    _LoadStatus.loading => const _LoadingUnits(),
    _LoadStatus.failed => _LoadFailure(
      kind: _failure?.kind ?? HealthApiFailureKind.connection,
      onRetry: _retryLoad,
    ),
    _LoadStatus.loaded => null,
  };
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
