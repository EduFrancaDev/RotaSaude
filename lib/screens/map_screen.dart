import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/demo_health_unit.dart';
import 'package:rotasaude/screens/availability_screen.dart';
import 'package:rotasaude/screens/location_selection_screen.dart';
import 'package:rotasaude/screens/route_preview_screen.dart';
import 'package:rotasaude/screens/unit_details_screen.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/theme/app_theme.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

enum _DiscoveryTab { map, list, compare }

class MapScreen extends StatefulWidget {
  const MapScreen({required this.position, super.key});

  final Position position;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late SearchArea? _area = SearchArea.fromPosition(widget.position);
  _DiscoveryTab _tab = _DiscoveryTab.map;
  TravelMode _travelMode = TravelMode.car;
  String _query = '';
  String? _serviceFilter;
  String _sortOrder = 'Destaque';
  bool _searchExpanded = false;
  String? _selectedUnitId = 'upa-centro';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DemoHealthUnit> get _visibleUnits {
    final query = _query.trim().toLowerCase();
    final units = DemoHealthUnits.forArea(_area).where((unit) {
      final matchesQuery =
          query.isEmpty ||
          unit.name.toLowerCase().contains(query) ||
          unit.services.any((service) => service.toLowerCase().contains(query));
      final matchesService =
          _serviceFilter == null || unit.services.contains(_serviceFilter);
      return matchesQuery && matchesService;
    }).toList();
    if (_sortOrder == 'Menor espera') {
      units.sort((a, b) {
        final aWait = a.operationalData?.waitMinutes;
        final bWait = b.operationalData?.waitMinutes;
        if (aWait == null && bWait == null) return a.name.compareTo(b.name);
        if (aWait == null) return 1;
        if (bWait == null) return -1;
        return aWait.compareTo(bWait);
      });
    }
    return units;
  }

  DemoHealthUnit? get _selectedUnit {
    final selectedId = _selectedUnitId;
    if (selectedId == null) return null;
    return _visibleUnits.where((unit) => unit.id == selectedId).firstOrNull;
  }

  List<String> get _services =>
      DemoHealthUnits.forArea(_area)
          .expand((unit) => unit.services)
          .toSet()
          .toList()
        ..sort();

  Future<void> _chooseArea() async {
    final area = await Navigator.of(context).push<SearchArea>(
      MaterialPageRoute<SearchArea>(
        builder: (_) => LocationSelectionScreen(currentArea: _area),
      ),
    );
    if (!mounted || area == null) return;
    setState(() {
      _area = area;
      _selectedUnitId = DemoHealthUnits.forArea(area).firstOrNull?.id;
      _query = '';
      _serviceFilter = null;
      _searchController.clear();
    });
  }

  Future<void> _showDetails(DemoHealthUnit unit) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UnitDetailsScreen(
          unit: unit,
          onRoute: unit.operationalData == null
              ? null
              : (mode) => _showRoute(unit, mode),
        ),
      ),
    );
  }

  Future<void> _showRoute(DemoHealthUnit unit, TravelMode mode) async {
    // Deferred import-free route screen navigation is defined in its own file.
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoutePreviewScreen(unit: unit, initialMode: mode),
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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_tab == _DiscoveryTab.map)
              _DiscoveryHeader(
                area: _area,
                onChooseArea: _chooseArea,
                onShowAvailability: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const AvailabilityScreen(),
                  ),
                ),
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

  Widget _buildMap() {
    final units = _visibleUnits;
    final center =
        _area?.center ??
        LatLng(widget.position.latitude, widget.position.longitude);
    final withinDemoArea =
        _area?.id == SearchArea.goiania.id &&
        Geolocator.distanceBetween(
              widget.position.latitude,
              widget.position.longitude,
              SearchArea.goiania.center.latitude,
              SearchArea.goiania.center.longitude,
            ) <=
            35000;

    return Stack(
      children: [
        FlutterMap(
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
                    point: LatLng(
                      widget.position.latitude,
                      widget.position.longitude,
                    ),
                    width: 52,
                    height: 52,
                    child: Semantics(
                      label: 'Sua localização no aparelho',
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 34,
                        color: AppColors.blue,
                        shadows: [Shadow(color: Colors.white, blurRadius: 8)],
                      ),
                    ),
                  ),
                for (final unit in units)
                  Marker(
                    point: unit.position,
                    width: 120,
                    height: 66,
                    alignment: const Alignment(0, 0.36),
                    child: Semantics(
                      excludeSemantics: true,
                      button: true,
                      label:
                          '${unit.name}, ${unit.operationalData?.availability.label ?? 'Dados operacionais indisponíveis'}',
                      selected: _selectedUnitId == unit.id,
                      onTap: () => setState(() => _selectedUnitId = unit.id),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selectedUnitId = unit.id),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      unit
                                          .operationalData
                                          ?.availability
                                          .color ??
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
                                      unit
                                          .operationalData
                                          ?.availability
                                          .color ??
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
                  : 'Nenhuma unidade nesta área do protótipo',
              message: _area == null
                  ? 'Os dados demonstrativos disponíveis são de Goiânia.'
                  : 'Você pode alterar a cidade a qualquer momento.',
              actionLabel: 'Escolher localização',
              onAction: _chooseArea,
            ),
          )
        else if (_selectedUnit != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: _MapUnitSummary(
              unit: _selectedUnit!,
              onDetails: () => _showDetails(_selectedUnit!),
            ),
          ),
      ],
    );
  }

  Widget _buildList() {
    final units = _visibleUnits;
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
              Text(
                '${units.length} ${units.length == 1 ? 'unidade' : 'unidades'} · ${_area?.name ?? 'Área não definida'}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              const IllustrativeNotice(compact: true, short: true),
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
                  items: const ['Destaque', 'Menor espera'],
                  itemLabel: (value) => value,
                  onChanged: (value) => setState(() => _sortOrder = value),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: units.isEmpty
              ? _EmptyResults(
                  title: 'Nenhuma unidade encontrada',
                  message: 'Tente outra busca ou limpe os filtros aplicados.',
                  actionLabel: 'Limpar filtros',
                  onAction: () => setState(() {
                    _query = '';
                    _searchController.clear();
                    _serviceFilter = null;
                  }),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                  itemCount: units.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final unit = units[index];
                    return _UnitListCard(
                      unit: unit,
                      selected: _selectedUnitId == unit.id,
                      onSelect: () => setState(() => _selectedUnitId = unit.id),
                      onDetails: () => _showDetails(unit),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildComparison() {
    final units = _visibleUnits;
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
              const SizedBox(height: 4),
              const IllustrativeNotice(compact: true, short: true),
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
        Expanded(
          child: units.isEmpty
              ? _EmptyResults(
                  title: 'Nenhuma unidade para comparar',
                  message: 'Altere a cidade ou os filtros da lista.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                  itemCount: units.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final unit = units[index];
                    return _ComparisonCard(
                      unit: unit,
                      mode: _travelMode,
                      selected: _selectedUnitId == unit.id,
                      onSelect: () => setState(() => _selectedUnitId = unit.id),
                      onDetails: () => _showDetails(unit),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({
    required this.area,
    required this.onChooseArea,
    required this.onShowAvailability,
  });

  final SearchArea? area;
  final VoidCallback onChooseArea;
  final VoidCallback onShowAvailability;

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

class _MapUnitSummary extends StatelessWidget {
  const _MapUnitSummary({required this.unit, required this.onDetails});

  final DemoHealthUnit unit;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final operational = unit.operationalData;
    return Card(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            if (operational != null)
              AvailabilityPill(level: operational.availability)
            else
              const Text('Dados operacionais indisponíveis'),
            if (operational != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  MetricColumn(
                    value: '${operational.waitMinutes ?? '—'} min',
                    label: 'espera',
                  ),
                  MetricColumn(
                    value: unit.distanceKm == null
                        ? '— km'
                        : formatDistanceKilometers(unit.distanceKm!),
                    label: 'distância',
                  ),
                  MetricColumn(
                    value: '${unit.carRoute?.durationMinutes ?? '—'} min',
                    label: 'de carro',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const IllustrativeNotice(compact: true),
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
    required this.selected,
    required this.onSelect,
    required this.onDetails,
  });

  final DemoHealthUnit unit;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final operational = unit.operationalData;
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
                if (operational != null)
                  AvailabilityPill(level: operational.availability)
                else
                  const Text('Dados operacionais indisponíveis'),
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
                      value: unit.distanceKm == null
                          ? '— km'
                          : formatDistanceKilometers(unit.distanceKm!),
                      label: 'distância',
                      alignment: CrossAxisAlignment.center,
                    ),
                    MetricColumn(
                      value: '${unit.carRoute?.durationMinutes ?? '—'} min',
                      label: 'carro',
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
    required this.mode,
    required this.selected,
    required this.onSelect,
    required this.onDetails,
  });

  final DemoHealthUnit unit;
  final TravelMode mode;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final operational = unit.operationalData;
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
                if (operational != null)
                  AvailabilityPill(level: operational.availability)
                else
                  const Text('Dados operacionais indisponíveis'),
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
                      value: unit.distanceKm == null
                          ? 'Indisponível'
                          : formatDistanceKilometers(unit.distanceKm!),
                      label: 'distância',
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
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
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
            const Icon(Icons.place_outlined, size: 42, color: AppColors.muted),
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
