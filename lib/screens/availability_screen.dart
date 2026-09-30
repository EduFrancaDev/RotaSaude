import 'package:flutter/material.dart';
import 'package:rotasaude/models/demo_health_unit.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

class AvailabilityScreen extends StatelessWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disponibilidade'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              'Entenda os indicadores',
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O nível resume dados operacionais da unidade e pode mudar ao longo do dia.',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            for (final level in AvailabilityLevel.values) ...[
              _AvailabilityCard(level: level),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'As cores não representam classificação clínica de pacientes nem substituem a triagem profissional. Os dados deste protótipo são ilustrativos.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.navy,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.level});

  final AvailabilityLevel level;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvailabilityPill(level: level),
            const SizedBox(height: 5),
            Text(
              'Situação operacional da unidade',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
