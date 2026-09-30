import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rotasaude/screens/map_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/theme/app_colors.dart';

enum _LocationIssue { denied, blocked, serviceOff, positionFailed }

/// Entrada do app: a localização é solicitada somente após uma ação da pessoa.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.locationAccess,
    this.mapBuilder,
    this.onLocationAccepted,
  });

  final LocationAccess? locationAccess;
  final Widget Function(BuildContext, Position)? mapBuilder;
  final VoidCallback? onLocationAccepted;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey _buttonKey = GlobalKey();
  late final LocationAccess _locationAccess =
      widget.locationAccess ?? const DeviceLocationAccess();

  _LocationIssue? _issue;
  bool _busy = false;
  bool _navigating = false;
  bool _awaitingSettingsReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingSettingsReturn) {
      _awaitingSettingsReturn = false;
      _attemptLocation(requestPermission: false);
    }
  }

  Future<void> _onPrimaryPressed() async {
    switch (_issue) {
      case _LocationIssue.blocked:
        await _openSettings(_locationAccess.openAppSettings);
      case _LocationIssue.serviceOff:
        await _openSettings(_locationAccess.openLocationSettings);
      case _:
        await _attemptLocation(requestPermission: true);
    }
  }

  Future<void> _openSettings(Future<bool> Function() open) async {
    _awaitingSettingsReturn = true;
    try {
      final opened = await open();
      if (!opened) {
        _awaitingSettingsReturn = false;
        _showSettingsError();
      }
    } catch (_) {
      _awaitingSettingsReturn = false;
      _showSettingsError();
    }
  }

  void _showSettingsError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir as configurações.')),
    );
  }

  Future<void> _attemptLocation({required bool requestPermission}) async {
    if (_busy || _navigating || !mounted) return;
    final previousIssue = _issue;
    setState(() {
      _busy = true;
      _issue = null;
    });

    try {
      var permission = await _locationAccess.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await _locationAccess.requestPermission();
      }
      if (!mounted) return;

      if (permission == LocationPermission.deniedForever) {
        _showIssue(_LocationIssue.blocked);
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        _showIssue(
          previousIssue == _LocationIssue.blocked
              ? _LocationIssue.blocked
              : _LocationIssue.denied,
        );
        return;
      }

      final serviceEnabled = await _locationAccess.isServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        _showIssue(_LocationIssue.serviceOff);
        return;
      }

      final position = await _locationAccess.getCurrentPosition();
      if (!mounted) return;

      setState(() {
        _busy = false;
        _navigating = true;
      });
      widget.onLocationAccepted?.call();
      await _openMap(position);
      if (mounted) setState(() => _navigating = false);
    } on LocationServiceDisabledException {
      _showIssue(_LocationIssue.serviceOff);
    } on PermissionDeniedException {
      if (!mounted) return;
      final permission = await _locationAccess.checkPermission();
      if (!mounted) return;
      _showIssue(
        permission == LocationPermission.deniedForever
            ? _LocationIssue.blocked
            : _LocationIssue.denied,
      );
    } catch (_) {
      _showIssue(_LocationIssue.positionFailed);
    }
  }

  void _showIssue(_LocationIssue issue) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _issue = issue;
    });
  }

  Future<void> _openMap(Position position) async {
    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = renderBox == null
        ? MediaQuery.sizeOf(context).center(Offset.zero)
        : renderBox.localToGlobal(renderBox.size.center(Offset.zero));
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 800),
        reverseTransitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.mapBuilder?.call(context, position) ??
            MapScreen(position: position),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (reduceMotion) return child;
          return AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) {
              final curve = animation.status == AnimationStatus.reverse
                  ? Curves.easeInCubic
                  : Curves.easeOutBack;
              final progress = curve.transform(animation.value);
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipPath(
                    key: const ValueKey('map-reveal'),
                    clipper: _CircularRevealClipper(
                      origin: origin,
                      progress: progress,
                    ),
                    child: child,
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _RevealRingPainter(
                        origin: origin,
                        progress: progress,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String get _buttonLabel => switch (_issue) {
    _LocationIssue.denied => 'Permitir localização',
    _LocationIssue.blocked => 'Abrir permissões do app',
    _LocationIssue.serviceOff => 'Ativar localização',
    _LocationIssue.positionFailed => 'Tentar novamente',
    null => 'Usar minha localização',
  };

  String? get _issueMessage => switch (_issue) {
    _LocationIssue.denied =>
      'Precisamos da sua localização para encontrar unidades próximas. '
          'Permita o acesso enquanto usa o app.',
    _LocationIssue.blocked =>
      'Para encontrar unidades próximas, permita o acesso à localização '
          'nas configurações do app.',
    _LocationIssue.serviceOff =>
      'A localização do celular está desligada. Ative-a para encontrar '
          'unidades próximas.',
    _LocationIssue.positionFailed =>
      'Não conseguimos obter sua localização agora. Confira o sinal e '
          'tente novamente.',
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topSpace = (constraints.maxHeight * 0.07).clamp(24.0, 56.0);
            final logoWidth = (constraints.maxWidth * 0.48).clamp(146.0, 200.0);

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, topSpace, 24, 0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: SvgPicture.asset(
                                  'assets/brand/svg/logo-completa/colorida-original.svg',
                                  width: logoWidth,
                                  semanticsLabel: 'RotaSaúde',
                                ),
                              ),
                              const SizedBox(height: 44),
                              Text(
                                'Onde você quer buscar atendimento?',
                                style: textTheme.headlineMedium?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                  height: 1.14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Encontre unidades, confira os serviços e '
                                'compare o deslocamento antes de sair.',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: AppColors.navy,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_issueMessage case final message?) ...[
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    message,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: AppColors.navy,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              FilledButton(
                                key: _buttonKey,
                                onPressed: _busy || _navigating
                                    ? null
                                    : _onPrimaryPressed,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  backgroundColor: AppColors.blue,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.blue,
                                  disabledForegroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _busy
                                    ? const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Obtendo localização…'),
                                        ],
                                      )
                                    : Text(_buttonLabel),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  const _CircularRevealClipper({required this.origin, required this.progress});

  final Offset origin;
  final double progress;

  static double radiusFor(Size size, Offset origin, double progress) {
    final farthestX = math.max(origin.dx, size.width - origin.dx);
    final farthestY = math.max(origin.dy, size.height - origin.dy);
    final maxRadius = math.sqrt(farthestX * farthestX + farthestY * farthestY);
    return 18 + (maxRadius - 18) * progress;
  }

  @override
  Path getClip(Size size) {
    return Path()..addOval(
      Rect.fromCircle(
        center: origin,
        radius: radiusFor(size, origin, progress),
      ),
    );
  }

  @override
  bool shouldReclip(covariant _CircularRevealClipper oldClipper) =>
      oldClipper.origin != origin || oldClipper.progress != progress;
}

/// Anel azul na borda do círculo, por cima da tela de origem.
class _RevealRingPainter extends CustomPainter {
  const _RevealRingPainter({required this.origin, required this.progress});

  final Offset origin;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = _CircularRevealClipper.radiusFor(size, origin, progress);
    if (radius <= 0) return;

    final edgeFade = (1 - ((progress - 0.72) / 0.28)).clamp(0.0, 1.0);
    if (edgeFade == 0) return;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = AppColors.blue.withValues(alpha: 0.38 * edgeFade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.blue.withValues(alpha: 0.95 * edgeFade);

    canvas
      ..drawCircle(origin, radius, glow)
      ..drawCircle(origin, radius, ring);
  }

  @override
  bool shouldRepaint(covariant _RevealRingPainter oldDelegate) =>
      oldDelegate.origin != origin || oldDelegate.progress != progress;
}
