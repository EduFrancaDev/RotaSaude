import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rotasaude/screens/home_screen.dart';
import 'package:rotasaude/screens/location_required_screen.dart';
import 'package:rotasaude/screens/map_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/location_onboarding_store.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/theme/app_theme.dart';

class RotaSaudeApp extends StatefulWidget {
  const RotaSaudeApp({super.key, this.locationAccess, this.onboardingStore});

  final LocationAccess? locationAccess;
  final LocationOnboardingStore? onboardingStore;

  @override
  State<RotaSaudeApp> createState() => _RotaSaudeAppState();
}

class _RotaSaudeAppState extends State<RotaSaudeApp>
    with WidgetsBindingObserver {
  late final LocationAccess _locationAccess =
      widget.locationAccess ?? const DeviceLocationAccess();
  late final LocationOnboardingStore _onboardingStore =
      widget.onboardingStore ?? const SharedLocationOnboardingStore();

  bool _loaded = false;
  bool _accepted = false;
  LocationBlock? _block;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBlock();
    }
  }

  Future<void> _load() async {
    final accepted = await _onboardingStore.hasAccepted();
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _loaded = true;
    });
    if (accepted) await _refreshBlock();
  }

  Future<void> _markAccepted() async {
    await _onboardingStore.markAccepted();
    if (!mounted) return;
    setState(() => _accepted = true);
  }

  Future<void> _refreshBlock() async {
    if (!_accepted) return;

    final permission = await _locationAccess.checkPermission();
    if (!mounted) return;

    final LocationBlock? block;
    if (permission == LocationPermission.deniedForever) {
      block = LocationBlock.permissionBlocked;
    } else if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      block = LocationBlock.permissionDenied;
    } else if (!await _locationAccess.isServiceEnabled()) {
      block = LocationBlock.serviceOff;
    } else {
      block = null;
    }

    if (!mounted) return;
    setState(() => _block = block);
  }

  Future<void> _openSettings() async {
    final block = _block;
    if (block == null) return;
    if (block == LocationBlock.serviceOff) {
      await _locationAccess.openLocationSettings();
    } else if (block == LocationBlock.permissionDenied) {
      await _locationAccess.requestPermission();
      await _refreshBlock();
    } else {
      await _locationAccess.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RotaSaúde',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) {
        if (_accepted && _block != null) {
          return LocationRequiredScreen(
            block: _block!,
            onOpenSettings: _openSettings,
          );
        }
        return child ?? const SizedBox.shrink();
      },
      home: !_loaded
          ? const Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: CircularProgressIndicator()),
            )
          : _accepted
          ? _ReturningMap(locationAccess: _locationAccess)
          : HomeScreen(
              locationAccess: _locationAccess,
              onLocationAccepted: _markAccepted,
            ),
    );
  }
}

class _ReturningMap extends StatefulWidget {
  const _ReturningMap({required this.locationAccess});

  final LocationAccess locationAccess;

  @override
  State<_ReturningMap> createState() => _ReturningMapState();
}

class _ReturningMapState extends State<_ReturningMap> {
  late Future<Position> _position;

  @override
  void initState() {
    super.initState();
    _position = widget.locationAccess.getCurrentPosition();
  }

  void _retryPosition() {
    setState(() {
      _position = widget.locationAccess.getCurrentPosition();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Position>(
      future: _position,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return MapScreen(position: snapshot.data!);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Obtendo localização…'),
                  ],
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              minimum: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.location_searching_rounded,
                        color: AppColors.blue,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Não conseguimos obter sua localização agora.',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Confira o sinal e tente novamente. A localização do aparelho é necessária para continuar.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _retryPosition,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
