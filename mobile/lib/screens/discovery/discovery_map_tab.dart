import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/screens/discovery/discovery_empty_results.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

class DiscoveryMapTab extends StatelessWidget {
  const DiscoveryMapTab({
    required this.area,
    required this.userOrigin,
    required this.mapController,
    required this.units,
    required this.hasUnits,
    required this.selectedUnitId,
    required this.summaryUnit,
    required this.straightLineKmByUnitId,
    required this.now,
    required this.onSelectUnit,
    required this.onDismissSummary,
    required this.onDetails,
    required this.onChooseArea,
    required this.onClearFilters,
    super.key,
  });

  final SearchArea? area;
  final UserLocationOrigin userOrigin;
  final MapController mapController;
  final List<HealthUnit> units;
  final bool hasUnits;
  final String? selectedUnitId;
  final HealthUnit? summaryUnit;
  final Map<String, double?> straightLineKmByUnitId;
  final DateTime now;
  final ValueChanged<String> onSelectUnit;
  final VoidCallback onDismissSummary;
  final ValueChanged<HealthUnit> onDetails;
  final VoidCallback onChooseArea;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final coord = userOrigin.coordinate;
    final summary = summaryUnit;
    final center = area?.center ?? coord;
    final withinDemoArea =
        area?.id == SearchArea.goiania.id &&
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
          mapController: mapController,
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
                      label: userOrigin.mapMarkerSemanticsLabel,
                      child: Icon(
                        userOrigin.isManual
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
                            '${unit.name}, ${unit.operationalSummaryAt(now)}',
                        selected: selectedUnitId == unit.id,
                        onTap: () => onSelectUnit(unit.id),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelectUnit(unit.id),
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
        if (area == null || units.isEmpty)
          Center(
            child: DiscoveryEmptyResults(
              title: area == null
                  ? 'Escolha uma cidade para consultar unidades'
                  : !hasUnits
                  ? 'Nenhuma unidade cadastrada nesta área'
                  : 'Nenhuma unidade encontrada',
              message: area == null
                  ? 'O ponto escolhido está fora das áreas com unidades '
                        'cadastradas.'
                  : !hasUnits
                  ? 'Você pode alterar a cidade a qualquer momento.'
                  : 'Tente outra busca ou limpe os filtros aplicados.',
              actionLabel: !hasUnits || area == null
                  ? 'Escolher localização'
                  : 'Limpar filtros',
              onAction: !hasUnits || area == null
                  ? onChooseArea
                  : onClearFilters,
            ),
          )
        else if (summary != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.38,
              ),
              child: SingleChildScrollView(
                child: _DismissibleMapUnitSummary(
                  key: const ValueKey('map-unit-summary-card'),
                  onDismissed: onDismissSummary,
                  child: _MapUnitSummary(
                    unit: summary,
                    operational: summary.currentOperationalDataAt(now),
                    straightLineKm: straightLineKmByUnitId[summary.id],
                    now: now,
                    onDetails: () => onDetails(summary),
                  ),
                ),
              ),
            ),
          ),
      ],
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
