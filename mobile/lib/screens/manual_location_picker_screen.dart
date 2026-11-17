import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/theme/app_colors.dart';

/// Permite escolher um ponto no mapa sem usar o GPS do aparelho.
class ManualLocationPickerScreen extends StatefulWidget {
  const ManualLocationPickerScreen({super.key});

  @override
  State<ManualLocationPickerScreen> createState() =>
      _ManualLocationPickerScreenState();
}

class _ManualLocationPickerScreenState
    extends State<ManualLocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selected;
  static final _demoCenter = SearchArea.goiania.center;

  void _onLongPress(TapPosition tapPosition, LatLng point) {
    setState(() => _selected = point);
  }

  void _confirm() {
    final point = _selected;
    if (point == null) return;
    Navigator.of(context).pop(point);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher no mapa'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                'Toque e segure no mapa para marcar o ponto de partida. '
                'O mapa abre em Goiânia apenas como referência — confirme '
                'somente depois de escolher onde você está.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.navy,
                  height: 1.4,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _demoCenter,
                      initialZoom: 12,
                      onLongPress: _onLongPress,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.edufrancadev.rotasaude',
                      ),
                      if (selected != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: selected,
                              width: 48,
                              height: 48,
                              child: const Icon(
                                Icons.place_rounded,
                                color: AppColors.blue,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          child: Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (selected == null)
                    Text(
                      'Nenhum ponto selecionado',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    )
                  else
                    Text(
                      'Ponto selecionado: '
                      '${selected.latitude.toStringAsFixed(5)}, '
                      '${selected.longitude.toStringAsFixed(5)}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: selected == null ? null : _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Confirmar este ponto'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
