import 'package:flutter/material.dart';
import 'package:rotasaude/screens/location_screen.dart';
import 'package:rotasaude/theme/app_colors.dart';

/// Primeira tela do app, antes da escolha de onde buscar atendimento.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topSpace = (constraints.maxHeight * 0.11).clamp(32.0, 76.0);
            final symbolDiameter = (constraints.maxWidth * 0.72).clamp(
              220.0,
              282.0,
            );

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, topSpace, 20, 0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: _PulsingSymbol(
                                  animation: _pulse,
                                  diameter: symbolDiameter,
                                ),
                              ),
                              const SizedBox(height: 36),
                              Text(
                                'Saúde mais perto\nde você.',
                                style: textTheme.headlineLarge?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Veja unidades próximas, compare a '
                                'disponibilidade e planeje o melhor caminho '
                                'antes de sair.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF62718A),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) =>
                                          const LocationScreen(),
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: AppColors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Começar'),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Informação para escolher melhor onde buscar '
                                'atendimento.',
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF62718A),
                                  height: 1.35,
                                ),
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

class _PulsingSymbol extends StatelessWidget {
  const _PulsingSymbol({required this.animation, required this.diameter});

  final Animation<double> animation;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: diameter + 12,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final pulse = Curves.easeInOut.transform(animation.value);
                return Transform.scale(
                  scale: 0.97 + (pulse * 0.06),
                  child: Opacity(opacity: 0.86 + (pulse * 0.14), child: child),
                );
              },
              child: SizedBox.square(
                dimension: diameter,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFEAF5FD),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Container(
              width: diameter * 0.58,
              height: diameter * 0.58,
              decoration: const BoxDecoration(
                color: AppColors.blue,
                shape: BoxShape.circle,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(height: 5),
                  Icon(Icons.add_rounded, color: Colors.white, size: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
