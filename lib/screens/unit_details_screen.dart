import 'package:flutter/material.dart';
import 'package:rotasaude/models/demo_health_unit.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

class UnitDetailsScreen extends StatelessWidget {
  const UnitDetailsScreen({
    required this.unit,
    required this.onRoute,
    super.key,
  });

  final DemoHealthUnit unit;
  final ValueChanged<TravelMode>? onRoute;

  @override
  Widget build(BuildContext context) {
    final operational = unit.operationalData;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da unidade'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Text(
              unit.name,
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              unit.address,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            if (operational == null)
              const _UnavailableDataCard()
            else ...[
              AvailabilityPill(level: operational.availability),
              const SizedBox(height: 8),
              const IllustrativeNotice(compact: true),
              const SizedBox(height: 14),
              Card.outlined(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          MetricColumn(
                            value: '${operational.waitMinutes ?? '—'} min',
                            label: 'espera estimada',
                          ),
                          MetricColumn(
                            value: '${operational.peopleWaiting ?? '—'}',
                            label: 'aguardando',
                            alignment: CrossAxisAlignment.center,
                          ),
                          MetricColumn(
                            value: unit.distanceKm == null
                                ? '— km'
                                : formatDistanceKilometers(unit.distanceKm!),
                            label: 'de você',
                            alignment: CrossAxisAlignment.end,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        'A espera é estimada e pode mudar. Os valores desta tela são ilustrativos.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              operational == null
                  ? 'Serviços cadastrados'
                  : 'Atendimentos disponíveis',
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ServiceChips(services: unit.services),
            if (operational == null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Os serviços cadastrados podem estar disponíveis, mas confirme diretamente com a unidade antes de se deslocar.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.navy,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (operational != null) ...[
              const SizedBox(height: 18),
              Card.outlined(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (unit.openingHours case final hours?)
                        Text('Funcionamento · $hours'),
                      if (unit.phone case final phone?) ...[
                        if (unit.openingHours != null)
                          const Divider(height: 24),
                        Text('Telefone · $phone'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: operational == null
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).popUntil(
                  (route) => route.isFirst || route.settings.name == '/',
                ),
                child: const Text('Ver outras unidades'),
              ),
            )
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: onRoute == null
                    ? null
                    : () => onRoute!(TravelMode.car),
                child: const Text('Ver opções de rota'),
              ),
            ),
    );
  }
}

class _UnavailableDataCard extends StatelessWidget {
  const _UnavailableDataCard();

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.background,
              child: Icon(Icons.priority_high, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Text(
              'Dados temporariamente indisponíveis',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta unidade não enviou informações recentes. Não mostramos espera ou disponibilidade antigas como se fossem atuais.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            const IllustrativeNotice(compact: true),
          ],
        ),
      ),
    );
  }
}
