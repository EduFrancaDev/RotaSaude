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

/// Rótulo da coluna de tempo de deslocamento de carro (rota OSRM na tela de rota).
const carRouteDurationMetricLabel = 'tempo de carro';
const carRouteDurationUnavailable = 'Indisponível';

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

/// Aviso de dado demonstrativo. Só deve ser exibido para unidades ou leituras
/// marcadas com `is_demo` (ou para conteúdo sempre ilustrativo, como rotas).
class IllustrativeNotice extends StatelessWidget {
  const IllustrativeNotice({
    super.key,
    this.compact = false,
    this.short = false,
  });

  final bool compact;
  final bool short;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Dados ilustrativos para o protótipo',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          short ? 'Dados ilustrativos · protótipo' : 'Dados ilustrativos do protótipo. Não representam a situação atual da unidade.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.navy, height: 1.35),
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

class MetricColumn extends StatelessWidget {
  const MetricColumn({
    required this.value,
    required this.label,
    super.key,
    this.alignment = CrossAxisAlignment.start,
    this.compact = false,
  });

  final String value;
  final String label;
  final CrossAxisAlignment alignment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textAlign = switch (alignment) {
      CrossAxisAlignment.center => TextAlign.center,
      CrossAxisAlignment.end => TextAlign.end,
      _ => TextAlign.start,
    };
    final valueAlign = switch (alignment) {
      CrossAxisAlignment.center => Alignment.center,
      CrossAxisAlignment.end => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };
    return Expanded(
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: valueAlign,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              textAlign: textAlign,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 20 : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted, height: 1.25),
          ),
        ],
      ),
    );
  }
}
