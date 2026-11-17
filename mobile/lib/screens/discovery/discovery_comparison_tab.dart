import 'package:flutter/material.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/screens/discovery/discovery_empty_results.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/theme/app_theme.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

class DiscoveryComparisonTab extends StatelessWidget {
  const DiscoveryComparisonTab({
    required this.units,
    required this.loadState,
    required this.straightLineKmByUnitId,
    required this.now,
    required this.selectedUnitId,
    required this.searchAction,
    required this.onChooseArea,
    required this.onSelectUnit,
    required this.onDetails,
    required this.travelMode,
    required this.onTravelModeChanged,
    super.key,
  });

  final List<HealthUnit> units;
  final Widget? loadState;
  final Map<String, double?> straightLineKmByUnitId;
  final DateTime now;
  final String? selectedUnitId;
  final Widget? searchAction;
  final VoidCallback onChooseArea;
  final ValueChanged<String> onSelectUnit;
  final ValueChanged<HealthUnit> onDetails;
  final TravelMode travelMode;
  final ValueChanged<TravelMode> onTravelModeChanged;

  @override
  Widget build(BuildContext context) {
    final loadingOrFailure = loadState;
    final Widget body;
    if (loadingOrFailure != null) {
      body = loadingOrFailure;
    } else if (units.isEmpty) {
      body = const DiscoveryEmptyResults(
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
            operational: unit.currentOperationalDataAt(now),
            straightLineKm: straightLineKmByUnitId[unit.id],
            now: now,
            mode: travelMode,
            selected: selectedUnitId == unit.id,
            onSelect: () => onSelectUnit(unit.id),
            onDetails: () => onDetails(unit),
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
                    onPressed: onChooseArea,
                    icon: const Icon(Icons.place_outlined),
                  ),
                  ?searchAction,
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
                selected: {travelMode},
                onSelectionChanged: (selection) =>
                    onTravelModeChanged(selection.first),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
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
