import 'dart:async';

import 'package:rotasaude/widgets/screen_back_button.dart';

import 'package:flutter/material.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/services/external_maps.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

class UnitDetailsScreen extends StatefulWidget {
  const UnitDetailsScreen({
    required this.unit,
    required this.straightLineKm,
    required this.onRoute,
    this.now,
    super.key,
  });

  final HealthUnit unit;
  final double? straightLineKm;
  final VoidCallback onRoute;
  final DateTime Function()? now;

  @override
  State<UnitDetailsScreen> createState() => _UnitDetailsScreenState();
}

class _UnitDetailsScreenState extends State<UnitDetailsScreen> {
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final now = widget.now?.call() ?? DateTime.now();
    final current = unit.currentOperationalDataAt(now);
    final canRoute = mapDestination(unit) != null;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da unidade'),
        leading: const ScreenBackButton(),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              unit.name,
              style: text.headlineSmall?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (unit.address.trim().isNotEmpty)
              SelectableText(
                unit.address,
                style: text.bodyLarge?.copyWith(color: AppColors.muted),
              ),
            const SizedBox(height: 14),
            Card.outlined(
              color: Colors.white,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (current?.availability case final level?) ...[
                      AvailabilityPill(level: level),
                      const SizedBox(height: 10),
                    ],
                    UnitWaitEstimate(unit: unit, now: now, showUpdate: true),
                    if (current?.peopleWaiting case final people?)
                      Text('$people aguardando'),
                    const SizedBox(height: 8),
                    if (widget.straightLineKm case final km?)
                      Text('${formatDistanceKilometers(km)} em linha reta')
                    else
                      const Text(straightLineDistanceUnavailable),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Serviços cadastrados',
              style: text.titleLarge?.copyWith(color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            if (unit.services.isEmpty)
              const Text('Nenhum serviço informado.')
            else
              ServiceChips(services: unit.services),
            if (unit.openingHours != null || unit.phone != null) ...[
              const SizedBox(height: 18),
              Card.outlined(
                color: Colors.white,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (unit.openingHours case final hours?)
                        Text('Funcionamento · $hours'),
                      if (unit.phone case final phone?)
                        Text('Telefone · $phone'),
                    ],
                  ),
                ),
              ),
            ],
            if (current == null) ...[
              const SizedBox(height: 12),
              Text(
                'Confirme o atendimento diretamente com a unidade.',
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ],
            if (!canRoute) ...[
              const SizedBox(height: 12),
              const Text(
                'A unidade não informou um endereço ou ponto no mapa.',
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 6, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canRoute)
              FilledButton.icon(
                onPressed: widget.onRoute,
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Ver rota'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Ver outras unidades'),
            ),
          ],
        ),
      ),
    );
  }
}
