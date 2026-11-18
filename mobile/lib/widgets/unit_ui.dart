import 'package:flutter/material.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/theme/app_colors.dart';

String formatDistanceKilometers(double distanceKm) =>
    '${distanceKm.toStringAsFixed(1).replaceFirst('.', ',')} km';

String formatUpdateTime(DateTime instant) {
  final local = instant.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} às '
      '${two(local.hour)}:${two(local.minute)}';
}

String formatClockTime(DateTime instant) {
  final local = instant.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

extension HealthUnitStatusText on HealthUnit {
  /// Nível exibível: só existe quando a leitura é atual e traz o nível.
  AvailabilityLevel? get currentAvailability =>
      currentOperationalData?.availability;

  /// Texto curto do estado operacional, para marcadores e rótulos
  /// acessíveis. Nunca apresenta dado antigo como atual.
  String get operationalSummary => operationalSummaryAt(DateTime.now());

  String operationalSummaryAt(DateTime now) =>
      switch (operationalState(now: now)) {
        OperationalDataState.current =>
          currentOperationalDataAt(now)?.availability?.label ??
              'Disponibilidade não informada',
        OperationalDataState.stale => 'Dados desatualizados',
        OperationalDataState.missing => 'Dados operacionais indisponíveis',
      };
}

/// Indicador de disponibilidade da unidade, ou o motivo de não haver um.
class UnitAvailabilityStatus extends StatelessWidget {
  const UnitAvailabilityStatus({required this.unit, this.now, super.key});

  final HealthUnit unit;

  /// Instante de referência para a janela de 30 minutos; `null` usa o relógio do aparelho.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final instant = now ?? DateTime.now();
    final level = unit.currentOperationalDataAt(instant)?.availability;
    if (level != null) return AvailabilityPill(level: level);
    return Text(unit.operationalSummaryAt(instant));
  }
}

class AvailabilityPill extends StatelessWidget {
  const AvailabilityPill({required this.level, super.key});

  final AvailabilityLevel level;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: level.label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: level.surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.circle, size: 9, color: level.color),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                level.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceChips extends StatelessWidget {
  const ServiceChips({required this.services, super.key});

  final List<String> services;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final service in services)
          Chip(
            label: Text(service),
            backgroundColor: const Color(0xFFEDF5F9),
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

/// Apresentação consistente da espera, inclusive quando a leitura perdeu a validade.
class UnitWaitEstimate extends StatelessWidget {
  const UnitWaitEstimate({
    required this.unit,
    required this.now,
    this.showUpdate = false,
    this.showLabel = true,
    super.key,
  });

  final HealthUnit unit;
  final DateTime now;
  final bool showUpdate;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final wait = unit.currentOperationalDataAt(now)?.waitMinutes;
    final stale = unit.operationalState(now: now) == OperationalDataState.stale;
    final time = unit.operationalData?.updatedAt;
    final labels = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          wait != null
              ? '$wait min'
              : stale
              ? 'Espera sem atualização'
              : 'Espera sem estimativa',
          style: labels.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (wait != null && showLabel)
          Text('Espera estimada', style: labels.bodySmall),
        if (showUpdate && time != null && (wait != null || stale))
          Text(
            stale
                ? 'Última leitura em ${formatUpdateTime(time)}'
                : 'Atualizada em ${formatUpdateTime(time)}',
            style: labels.bodySmall?.copyWith(color: AppColors.muted),
          ),
      ],
    );
  }
}
