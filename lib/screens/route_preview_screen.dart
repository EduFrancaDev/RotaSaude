import 'package:flutter/material.dart';
import 'package:rotasaude/models/demo_health_unit.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/theme/app_theme.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

class RoutePreviewScreen extends StatefulWidget {
  const RoutePreviewScreen({
    required this.unit,
    required this.initialMode,
    super.key,
  });

  final DemoHealthUnit unit;
  final TravelMode initialMode;

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  late TravelMode _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    final route = widget.unit.routeFor(_mode);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rota até a unidade'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: SegmentedButton<TravelMode>(
                style: AppTheme.primarySegmentedButtonStyle,
                segments: const [
                  ButtonSegment(value: TravelMode.car, label: Text('Carro')),
                  ButtonSegment(value: TravelMode.bus, label: Text('Ônibus')),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
            ),
            Expanded(
              child: route == null
                  ? _RouteUnavailable(unit: widget.unit, mode: _mode)
                  : _RouteContent(unit: widget.unit, mode: _mode, route: route),
            ),
          ],
        ),
      ),
      bottomNavigationBar: route == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 6, 18, 14),
              child: OutlinedButton(
                onPressed: () => setState(
                  () => _mode = _mode == TravelMode.car
                      ? TravelMode.bus
                      : TravelMode.car,
                ),
                child: Text(
                  _mode == TravelMode.car
                      ? 'Ver transporte público'
                      : 'Ver rota de carro',
                ),
              ),
            ),
    );
  }
}

class _RouteContent extends StatelessWidget {
  const _RouteContent({
    required this.unit,
    required this.mode,
    required this.route,
  });

  final DemoHealthUnit unit;
  final TravelMode mode;
  final UnitRoutePreview route;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      children: [
        SizedBox(
          height: 250,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: CustomPaint(
              painter: _RouteDiagramPainter(mode: mode),
              child: const Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: _DiagramLabel(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          unit.name,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                '${route.durationMinutes} min',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (route.distanceKm case final distance?)
              Text(
                formatDistanceKilometers(distance),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Text(
                '1 linha · sem integração',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
          ],
        ),
        if (route.traffic case final traffic?) ...[
          const SizedBox(height: 4),
          Text(traffic, style: TextStyle(color: AppColors.muted)),
        ],
        const SizedBox(height: 12),
        const IllustrativeNotice(compact: true),
        const Divider(height: 28),
        if (mode == TravelMode.car && route.description != null) ...[
          Text(
            route.description!,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            'A rota e o trânsito são exemplos, sem cálculo de navegação.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
        if (mode == TravelMode.bus)
          for (var index = 0; index < route.steps.length; index++)
            _RouteStep(
              text: route.steps[index],
              color: index == 1 ? AppColors.teal : AppColors.blue,
            ),
      ],
    );
  }
}

class _DiagramLabel extends StatelessWidget {
  const _DiagramLabel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text('Esquema de trajeto ilustrativo'),
      ),
    );
  }
}

class _RouteStep extends StatelessWidget {
  const _RouteStep({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 11, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteUnavailable extends StatelessWidget {
  const _RouteUnavailable({required this.unit, required this.mode});

  final DemoHealthUnit unit;
  final TravelMode mode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, size: 44, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              'Rota indisponível no protótipo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Não há uma prévia de ${mode.label.toLowerCase()} para ${unit.name}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteDiagramPainter extends CustomPainter {
  const _RouteDiagramPainter({required this.mode});

  final TravelMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(AppColors.mapLand, BlendMode.src);
    final blockPaint = Paint()..color = const Color(0xFFE0E9E8);
    final parkPaint = Paint()..color = const Color(0xFFDCECDD);
    final roadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    final roadEdge = Paint()
      ..color = const Color(0xFFD8E3E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 21;

    for (var column = 0; column < 4; column++) {
      for (var row = 0; row < 3; row++) {
        final rect = Rect.fromLTWH(
          column * size.width / 3.2 + 10,
          row * size.height / 2.4 + 14,
          size.width / 4.6,
          size.height / 4.1,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          blockPaint,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .68, size.height * .12, 62, 40),
        const Radius.circular(4),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .08, size.height * .68, 52, 36),
        const Radius.circular(4),
      ),
      parkPaint,
    );

    final avenue = Path()
      ..moveTo(-10, size.height * .55)
      ..cubicTo(
        size.width * .22,
        size.height * .42,
        size.width * .55,
        size.height * .78,
        size.width + 12,
        size.height * .52,
      );
    canvas
      ..drawPath(avenue, roadEdge)
      ..drawPath(avenue, roadPaint);

    final route = Path()
      ..moveTo(size.width * .24, size.height * .28)
      ..lineTo(size.width * .42, size.height * .32)
      ..lineTo(size.width * .6, size.height * .52)
      ..lineTo(size.width * .51, size.height * .67)
      ..lineTo(size.width * .38, size.height * .85);
    final routeColor = mode == TravelMode.car ? AppColors.blue : AppColors.teal;
    final routePaint = Paint()
      ..color = routeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(route, routePaint);

    final origin = Offset(size.width * .24, size.height * .28);
    final destination = Offset(size.width * .38, size.height * .85);
    canvas
      ..drawCircle(origin, 10, Paint()..color = Colors.white)
      ..drawCircle(origin, 7, Paint()..color = const Color(0xFF69BDF2))
      ..drawCircle(destination, 10, Paint()..color = Colors.white)
      ..drawCircle(destination, 7, Paint()..color = routeColor);
    if (mode == TravelMode.bus) {
      canvas.drawCircle(
        Offset(size.width * .54, size.height * .61),
        7,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(size.width * .54, size.height * .61),
        4,
        Paint()..color = AppColors.teal,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RouteDiagramPainter oldDelegate) =>
      oldDelegate.mode != mode;
}
