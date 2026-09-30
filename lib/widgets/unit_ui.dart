import 'package:flutter/material.dart';
import 'package:rotasaude/models/demo_health_unit.dart';
import 'package:rotasaude/theme/app_colors.dart';

String formatDistanceKilometers(double distanceKm) =>
    '${distanceKm.toStringAsFixed(1).replaceFirst('.', ',')} km';

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
    return Expanded(
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Text(
            value,
            textAlign: textAlign,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 20 : null,
              fontFeatures: const [FontFeature.tabularFigures()],
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
