import 'package:flutter/material.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

class DiscoveryListTab extends StatelessWidget {
  const DiscoveryListTab({
    required this.header,
    required this.units,
    required this.state,
    required this.now,
    required this.distances,
    required this.carMinutes,
    required this.compared,
    required this.serviceFilter,
    required this.onComparison,
    required this.onDetails,
    super.key,
  });

  final Widget header;
  final List<HealthUnit> units;
  final Widget? state;
  final DateTime now;
  final Map<String, double?> distances;
  final Map<String, int> carMinutes;
  final List<HealthUnit> compared;
  final String? serviceFilter;
  final ValueChanged<HealthUnit> onComparison;
  final ValueChanged<HealthUnit> onDetails;

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const PageStorageKey('discovery-list-scroll'),
    padding: const EdgeInsets.only(bottom: 12),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    itemCount: 2 + (state == null ? units.length : 0),
    itemBuilder: (context, index) {
      if (index == 0) return header;
      if (index == 1) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unidades de saúde',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (state == null)
                Text(
                  '${units.length} ${units.length == 1 ? 'unidade' : 'unidades'}',
                ),
              if (compared.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Selecionadas para comparar (${compared.length}/2)'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final unit in compared)
                      InputChip(
                        label: Text(unit.name),
                        onDeleted: () => onComparison(unit),
                        deleteButtonTooltipMessage:
                            'Remover ${unit.name} da comparação',
                      ),
                  ],
                ),
              ],
              if (state case final current?) ...[
                const SizedBox(height: 12),
                current,
              ],
            ],
          ),
        );
      }
      final unit = units[index - 2];
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: _UnitCard(
          unit: unit,
          now: now,
          distance: distances[unit.id],
          minutes: carMinutes[unit.id],
          selected: compared.any((selected) => selected.id == unit.id),
          serviceFilter: serviceFilter,
          onToggle: () => onComparison(unit),
          onDetails: () => onDetails(unit),
        ),
      );
    },
  );
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.now,
    required this.distance,
    required this.minutes,
    required this.selected,
    required this.serviceFilter,
    required this.onToggle,
    required this.onDetails,
  });

  final HealthUnit unit;
  final DateTime now;
  final double? distance;
  final int? minutes;
  final bool selected;
  final String? serviceFilter;
  final VoidCallback onToggle;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final services = serviceFilter ?? unit.services.join(' · ');
    final theme = Theme.of(context).textTheme;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onDetails,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      unit.name,
                      style: theme.titleMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ver detalhes de ${unit.name}',
                    icon: const Icon(
                      Icons.arrow_forward,
                      color: AppColors.blue,
                    ),
                    onPressed: onDetails,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (services.isNotEmpty)
                  Text(
                    services,
                    style: theme.bodyMedium?.copyWith(color: AppColors.navy),
                  ),
                const SizedBox(height: 8),
                UnitWaitEstimate(unit: unit, now: now),
                if (distance case final km?)
                  Text(
                    '${formatDistanceKilometers(km)} em linha reta',
                    style: theme.bodySmall,
                  )
                else if (distance == null)
                  const Text(straightLineDistanceUnavailable),
                if (minutes case final minutes?) Text('$minutes min de carro'),
                if (unit.isDemo) ...[
                  const SizedBox(height: 8),
                  const IllustrativeNotice(compact: true, short: true),
                ],
              ],
            ),
          ),
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            value: selected,
            onChanged: (_) => onToggle(),
            title: Semantics(
              label: 'Comparar ${unit.name}',
              excludeSemantics: true,
              child: Text(
                selected
                    ? 'Selecionada para comparar'
                    : 'Selecionar para comparar',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
