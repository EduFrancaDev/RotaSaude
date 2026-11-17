import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/screens/manual_location_picker_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/widgets/screen_back_button.dart';

enum _Issue { denied, blocked, disabled, unavailable }

class OriginSelectionScreen extends StatefulWidget {
  const OriginSelectionScreen({
    required this.locationAccess,
    required this.mapCenter,
    super.key,
  });

  final LocationAccess locationAccess;
  final LatLng? mapCenter;

  @override
  State<OriginSelectionScreen> createState() => _OriginSelectionScreenState();
}

class _OriginSelectionScreenState extends State<OriginSelectionScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _waitingForSettings = false;
  _Issue? _issue;

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
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _useGps(requestPermission: false);
    }
  }

  Future<void> _useGps({bool requestPermission = true}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final access = widget.locationAccess;
    _Issue? issue;
    try {
      if (!await access.isServiceEnabled()) {
        issue = _Issue.disabled;
      } else {
        var permission = await access.checkPermission();
        if (permission == LocationPermission.denied && requestPermission) {
          permission = await access.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          issue = _Issue.blocked;
        } else if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          issue = _Issue.denied;
        } else {
          final position = await access.getCurrentPosition();
          if (mounted) {
            Navigator.of(context).pop(UserLocationOrigin.fromGps(position));
          }
          return;
        }
      }
    } on LocationServiceDisabledException {
      issue = _Issue.disabled;
    } on Exception {
      issue = _Issue.unavailable;
    }
    if (mounted) {
      setState(() {
        _issue = issue;
        _busy = false;
      });
    }
  }

  Future<void> _openSettings() async {
    _waitingForSettings = true;
    bool opened;
    try {
      opened = _issue == _Issue.disabled
          ? await widget.locationAccess.openLocationSettings()
          : await widget.locationAccess.openAppSettings();
    } on Exception {
      opened = false;
    }
    if (opened || !mounted) return;
    _waitingForSettings = false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir os ajustes.')),
    );
  }

  Future<void> _pickOnMap() async {
    final point = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) =>
            ManualLocationPickerScreen(initialCenter: widget.mapCenter),
      ),
    );
    if (mounted && point != null) {
      Navigator.of(context).pop(UserLocationOrigin.manual(point));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (message, action) = switch (_issue) {
      _Issue.denied => (
        'Permita o uso da sua localização ou selecione um ponto no mapa.',
        'Permitir localização',
      ),
      _Issue.blocked => (
        'Permita a localização nos ajustes do aplicativo ou selecione um ponto no mapa.',
        'Abrir permissões do app',
      ),
      _Issue.disabled => (
        'O GPS do aparelho está desligado. Você também pode escolher um ponto no mapa.',
        'Ativar localização',
      ),
      _Issue.unavailable => (
        'Não conseguimos obter sua posição. Tente novamente ou use o mapa.',
        'Tentar novamente',
      ),
      null => (
        'Use sua localização ou escolha de onde você vai sair.',
        'Usar minha localização',
      ),
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Definir ponto de partida'),
        leading: const ScreenBackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : _issue == _Issue.blocked || _issue == _Issue.disabled
                  ? _openSettings
                  : _useGps,
              icon: const Icon(Icons.my_location),
              label: Text(_busy ? 'Obtendo localização…' : action),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickOnMap,
              icon: const Icon(Icons.place_outlined),
              label: const Text('Escolher ponto no mapa'),
            ),
          ],
        ),
      ),
    );
  }
}
