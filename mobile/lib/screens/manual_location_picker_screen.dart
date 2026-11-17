import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/widgets/screen_back_button.dart';

class ManualLocationPickerScreen extends StatefulWidget {
  const ManualLocationPickerScreen({super.key, this.initialCenter});

  final LatLng? initialCenter;

  @override
  State<ManualLocationPickerScreen> createState() =>
      _ManualLocationPickerScreenState();
}

class _ManualLocationPickerScreenState
    extends State<ManualLocationPickerScreen> {
  late LatLng _center = widget.initialCenter ?? SearchArea.goiania.center;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ponto de partida'),
      leading: const ScreenBackButton(),
    ),
    body: SafeArea(
      top: false,
      bottom: false,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              onPositionChanged: (camera, _) => _center = camera.center,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.edufrancadev.rotasaude',
              ),
            ],
          ),
          const IgnorePointer(
            child: Center(
              child: FractionalTranslation(
                translation: Offset(0, -.5),
                child: Icon(
                  Icons.location_pin,
                  color: AppColors.blue,
                  size: 48,
                  semanticLabel: 'Pino do ponto de partida',
                  shadows: [Shadow(color: Colors.white, blurRadius: 5)],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Card(
              color: Colors.white,
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Mova o mapa até o ponto de partida',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomLeft,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text('© OpenStreetMap contributors'),
              ),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ponto selecionado'),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_center),
            child: const Text('Confirmar este ponto'),
          ),
        ],
      ),
    ),
  );
}
