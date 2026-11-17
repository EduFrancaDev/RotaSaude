import 'package:flutter/material.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/screens/discovery/discovery_empty_results.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

class DiscoveryListTab extends StatelessWidget {
  const DiscoveryListTab({
    required this.units,
    required this.loadState,
    required this.straightLineKmByUnitId,
    required this.now,
    required this.selectedUnitId,
    required this.searchAction,
    required this.onChooseArea,
    required this.onSelectUnit,
    required this.onDetails,
    required this.area,
    required this.hasUnits,
    required this.services,
    required this.serviceFilter,
    required this.sortOrder,
    required this.onClearFilters,
    required this.onServiceFilterChanged,
    required this.onSortOrderChanged,
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
  final SearchArea? area;
  final bool hasUnits;
  final List<String> services;
  final String? serviceFilter;
  final String sortOrder;
  final VoidCallback onClearFilters;
  final ValueChanged<String?> onServiceFilterChanged;
  final ValueChanged<String> onSortOrderChanged;

  @override
  Widget build(BuildContext context) {
    final loadingOrFailure = loadState;
    final Widget body;
    if (loadingOrFailure != null) {
      body = loadingOrFailure;
    } else if (!hasUnits) {
      body = DiscoveryEmptyResults(
        title: 'Nenhuma unidade cadastrada nesta área',
        message: 'Você pode alterar a cidade a qualquer momento.',
        actionLabel: 'Escolher localização',
        onAction: onChooseArea,
      );
    } else if (units.isEmpty) {
      body = DiscoveryEmptyResults(
        title: 'Nenhuma unidade encontrada',
        message: 'Tente outra busca ou limpe os filtros aplicados.',
        actionLabel: 'Limpar filtros',
        onAction: onClearFilters,
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
            operational: unit.currentOperationalDataAt(now),
            straightLineKm: straightLineKmByUnitId[unit.id],
            now: now,
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
                    onPressed: onChooseArea,
                    icon: const Icon(Icons.place_outlined),
                  ),
                  ?searchAction,
                ],
              ),
              if (loadState == null) ...[
                Text(
                  '${units.length} ${units.length == 1 ? 'unidade' : 'unidades'} · ${area?.name ?? 'Área não definida'}',
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
                  value: serviceFilter,
                  items: [null, ...services],
                  itemLabel: (value) => value ?? 'Todos',
                  onChanged: onServiceFilterChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown<String>(
                  label: 'Ordenar',
                  value: sortOrder,
                  items: const ['Destaque', 'Menor espera', 'Proximidade'],
                  itemLabel: (value) => value,
                  onChanged: onSortOrderChanged,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
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
