import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

class DiscoveryMapTab extends StatelessWidget {
  const DiscoveryMapTab({
    required this.area,
    required this.userOrigin,
    required this.initialCamera,
    required this.onMapEvent,
    required this.units,
    required this.state,
    required this.carMinutes,
    required this.selectedUnitId,
    required this.summaryUnit,
    required this.straightLineKmByUnitId,
    required this.now,
    required this.onSelectUnit,
    required this.onDismissSummary,
    required this.onDetails,
    super.key,
  });

  final SearchArea? area;
  final UserLocationOrigin? userOrigin;
  final MapCamera? initialCamera;
  final MapEventCallback onMapEvent;
  final List<HealthUnit> units;
  final Widget? state;
  final Map<String, int> carMinutes;
  final String? selectedUnitId;
  final HealthUnit? summaryUnit;
  final Map<String, double?> straightLineKmByUnitId;
  final DateTime now;
  final ValueChanged<String> onSelectUnit;
  final VoidCallback onDismissSummary;
  final ValueChanged<HealthUnit> onDetails;

  @override
  Widget build(BuildContext context) {
    final origin = userOrigin;
    final summary = summaryUnit;
    final center =
        area?.center ?? origin?.coordinate ?? SearchArea.goiania.center;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: initialCamera?.center ?? center,
            initialZoom: initialCamera?.zoom ?? 13,
            initialRotation: initialCamera?.rotation ?? 0,
            onMapEvent: onMapEvent,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.edufrancadev.rotasaude',
              errorTileCallback: (tile, error, stackTrace) {},
            ),
            MarkerLayer(
              markers: [
                if (origin != null)
                  Marker(
                    point: origin.coordinate,
                    width: 52,
                    height: 52,
                    child: Semantics(
                      label: origin.mapMarkerSemanticsLabel,
                      child: Icon(
                        origin.isManual
                            ? Icons.place_rounded
                            : Icons.my_location_rounded,
                        size: 34,
                        color: AppColors.blue,
                        shadows: [Shadow(color: Colors.white, blurRadius: 8)],
                      ),
                    ),
                  ),
                for (final unit in units)
                  if (isValidGeographicPosition(unit.position))
                    Marker(
                      point: unit.position,
                      width: 120,
                      height: 76,
                      alignment: const Alignment(0, 0.36),
                      child: Semantics(
                        excludeSemantics: true,
                        button: true,
                        label:
                            '${unit.name}, ${unit.operationalSummaryAt(now)}',
                        selected: selectedUnitId == unit.id,
                        onTap: () => onSelectUnit(unit.id),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelectUnit(unit.id),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selectedUnitId == unit.id
                                        ? AppColors.navy
                                        : (unit
                                                  .currentOperationalDataAt(now)
                                                  ?.availability
                                                  ?.color ??
                                              AppColors.muted),
                                    width: selectedUnitId == unit.id ? 4 : 2,
                                  ),
                                ),
                                child: SizedBox(
                                  width: selectedUnitId == unit.id ? 52 : 42,
                                  height: selectedUnitId == unit.id ? 52 : 42,
                                  child: Icon(
                                    Icons.local_hospital_outlined,
                                    color:
                                        unit
                                            .currentOperationalDataAt(now)
                                            ?.availability
                                            ?.color ??
                                        AppColors.muted,
                                    size: selectedUnitId == unit.id ? 29 : 23,
                                  ),
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  child: Text(
                                    unit.name.replaceFirst(
                                      'UPA Exemplo ',
                                      'UPA ',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textScaler: MediaQuery.textScalerOf(context)
                                        .clamp(maxScaleFactor: 1.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),
        const Align(
          alignment: Alignment.topLeft,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10, color: AppColors.navy),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (state case final current?)
          Center(
            child: Card(
              color: Colors.white,
              margin: const EdgeInsets.fromLTRB(14, 34, 14, 12),
              clipBehavior: Clip.antiAlias,
              child: current,
            ),
          )
        else if (summary != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.38,
              ),
              child: SingleChildScrollView(
                child: _DismissibleMapUnitSummary(
                  key: const ValueKey('map-unit-summary-card'),
                  onDismissed: onDismissSummary,
                  child: _MapUnitSummary(
                    unit: summary,
                    minutes: carMinutes[summary.id],
                    onClose: onDismissSummary,
                    straightLineKm: straightLineKmByUnitId[summary.id],
                    now: now,
                    onDetails: () => onDetails(summary),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DismissibleMapUnitSummary extends StatefulWidget {
  const _DismissibleMapUnitSummary({
    required this.onDismissed,
    required this.child,
    super.key,
  });

  final VoidCallback onDismissed;
  final Widget child;

  @override
  State<_DismissibleMapUnitSummary> createState() =>
      _DismissibleMapUnitSummaryState();
}

class _DismissibleMapUnitSummaryState
    extends State<_DismissibleMapUnitSummary> {
  static const _dismissDragThreshold = 72.0;

  double _dragExtent = 0;

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldDismiss =
        _dragExtent >= _dismissDragThreshold || velocity > 700;
    if (shouldDismiss) {
      widget.onDismissed();
      return;
    }
    setState(() => _dragExtent = 0);
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (1 - (_dragExtent / 180)).clamp(0.35, 1.0).toDouble();
    return Semantics(
      label: 'Resumo da unidade. Arraste para baixo para ocultar.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragExtent = (_dragExtent + details.delta.dy).clamp(0.0, 220.0);
          });
        },
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragExtent),
          child: Opacity(opacity: opacity, child: widget.child),
        ),
      ),
    );
  }
}

class _MapUnitSummary extends StatelessWidget {
  const _MapUnitSummary({
    required this.unit,
    required this.minutes,
    required this.straightLineKm,
    required this.now,
    required this.onDetails,
    required this.onClose,
  });

  final HealthUnit unit;
  final int? minutes;
  final double? straightLineKm;
  final DateTime now;
  final VoidCallback onDetails;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(10),
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unit.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Ocultar resumo da unidade',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          UnitAvailabilityStatus(unit: unit, now: now),
          const SizedBox(height: 8),
          UnitWaitEstimate(unit: unit, now: now),
          if (straightLineKm case final km?)
            Text('${formatDistanceKilometers(km)} em linha reta')
          else
            const Text(straightLineDistanceUnavailable),
          if (minutes case final value?) Text('$value min de carro'),
          const SizedBox(height: 8),
          FilledButton(onPressed: onDetails, child: const Text('Ver detalhes')),
        ],
      ),
    ),
  );
}
