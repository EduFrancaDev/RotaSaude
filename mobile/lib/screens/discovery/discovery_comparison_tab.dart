import 'package:flutter/material.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/theme/app_theme.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

class DiscoveryComparisonTab extends StatelessWidget {
  const DiscoveryComparisonTab({
    required this.header,
    required this.units,
    required this.visibleIds,
    required this.state,
    required this.now,
    required this.distances,
    required this.carMinutes,
    required this.busMinutes,
    required this.serviceFilter,
    required this.travelMode,
    required this.hasOrigin,
    required this.calculating,
    required this.calculationFailed,
    required this.onCalculate,
    required this.onChooseOrigin,
    required this.onMode,
    required this.onSelectUnits,
    required this.onRemove,
    required this.onDetails,
    super.key,
  });

  final Widget header;
  final List<HealthUnit> units;
  final Set<String> visibleIds;
  final Widget? state;
  final DateTime now;
  final Map<String, double?> distances;
  final Map<String, int> carMinutes;
  final Map<String, int> busMinutes;
  final String? serviceFilter;
  final TravelMode travelMode;
  final bool hasOrigin;
  final bool calculating;
  final bool calculationFailed;
  final VoidCallback onCalculate;
  final VoidCallback onChooseOrigin;
  final ValueChanged<TravelMode> onMode;
  final VoidCallback onSelectUnits;
  final ValueChanged<HealthUnit> onRemove;
  final ValueChanged<HealthUnit> onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final byBus = travelMode == TravelMode.bus;
    final routable = units.where(
      (unit) => isValidGeographicPosition(unit.position),
    );
    final travelMinutes = byBus ? busMinutes : carMinutes;
    final needsTravelTimes = routable.any(
      (unit) => !travelMinutes.containsKey(unit.id),
    );
    return ListView(
      key: const PageStorageKey('discovery-comparison-scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        header,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Comparar unidades', style: theme.titleLarge),
              const SizedBox(height: 12),
              if (state case final current?)
                current
              else if (units.length < 2) ...[
                Text('Selecione duas unidades na Lista para comparar.'),
                if (units.firstOrNull case final unit?)
                  InputChip(
                    label: Text(unit.name),
                    onDeleted: () => onRemove(unit),
                    deleteButtonTooltipMessage:
                        'Remover ${unit.name} da comparação',
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: onSelectUnits,
                  child: const Text('Selecionar unidades'),
                ),
              ] else ...[
                if (units.any((unit) => !visibleIds.contains(unit.id))) ...[
                  Text(
                    'Uma ou mais unidades selecionadas estão fora dos filtros atuais.',
                    style: theme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
                _ComparisonRow(
                  units: units,
                  cell: (unit) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.name,
                        style: theme.titleSmall?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () => onRemove(unit),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        child: Semantics(
                          label: 'Remover ${unit.name} da comparação',
                          excludeSemantics: true,
                          child: const Text('Remover'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<TravelMode>(
                    style: AppTheme.primarySegmentedButtonStyle,
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: TravelMode.car,
                        label: Text('Carro'),
                      ),
                      ButtonSegment(
                        value: TravelMode.bus,
                        label: Text('Ônibus'),
                      ),
                    ],
                    selected: {travelMode},
                    onSelectionChanged: (value) => onMode(value.single),
                  ),
                ),
                const SizedBox(height: 8),
                _ComparisonRow(
                  label: serviceFilter == null
                      ? 'Serviços cadastrados'
                      : 'Serviço procurado',
                  units: units,
                  cell: (unit) => Text(switch (serviceFilter) {
                    final service? =>
                      unit.services.contains(service)
                          ? service
                          : '$service não cadastrado',
                    null =>
                      unit.services.isEmpty
                          ? 'Sem serviços cadastrados'
                          : unit.services.join(' · '),
                  }),
                ),
                _ComparisonRow(
                  label: 'Espera estimada',
                  units: units,
                  cell: (unit) => UnitWaitEstimate(
                    unit: unit,
                    now: now,
                    showUpdate: true,
                    showLabel: false,
                  ),
                ),
                _ComparisonRow(
                  label: 'Distância em linha reta',
                  units: units,
                  cell: (unit) => Text(
                    hasOrigin
                        ? formatStraightLineDistanceValue(distances[unit.id])
                        : 'Sem ponto de partida',
                  ),
                ),
                _ComparisonRow(
                  label: byBus ? 'Tempo de ônibus' : 'Tempo de carro',
                  units: units,
                  cell: (unit) {
                    final minutes = travelMinutes[unit.id];
                    return Text(
                      minutes != null ? '$minutes min' : 'Sem estimativa',
                    );
                  },
                ),
                if (needsTravelTimes || !hasOrigin)
                  OutlinedButton.icon(
                    onPressed: calculating ? null : onCalculate,
                    icon: Icon(
                      byBus
                          ? Icons.directions_bus_outlined
                          : Icons.directions_car_outlined,
                    ),
                    label: Text(
                      calculating
                          ? 'Calculando tempos…'
                          : calculationFailed
                          ? 'Tentar calcular novamente'
                          : hasOrigin
                          ? 'Calcular tempos de ${byBus ? 'ônibus' : 'carro'}'
                          : 'Definir ponto de partida',
                    ),
                  ),
                if (calculationFailed)
                  Text(
                    byBus
                        ? 'Tempo de ônibus indisponível para estas unidades.'
                        : 'Alguns tempos de carro não puderam ser calculados.',
                  ),
                const SizedBox(height: 8),
                _ComparisonRow(
                  units: units,
                  cell: (unit) => TextButton(
                    onPressed: () => onDetails(unit),
                    child: Semantics(
                      label: 'Ver detalhes de ${unit.name}',
                      excludeSemantics: true,
                      child: const Text('Ver detalhes'),
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: onSelectUnits,
                  child: const Text('Alterar seleção na Lista'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.units, required this.cell, this.label});

  final List<HealthUnit> units;
  final Widget Function(HealthUnit unit) cell;
  final String? label;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: const EdgeInsets.only(bottom: 6),
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label case final title?) ...[
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, unit) in units.indexed) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    container: true,
                    label: label == null ? null : '$label, ${unit.name}',
                    child: cell(unit),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
