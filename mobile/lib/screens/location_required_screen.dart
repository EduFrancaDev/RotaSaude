import 'package:flutter/material.dart';
import 'package:rotasaude/theme/app_colors.dart';

enum LocationBlock { permissionDenied, permissionBlocked, serviceOff }

/// Bloqueia o app até a localização voltar, como o aviso do Waze.
class LocationRequiredScreen extends StatelessWidget {
  const LocationRequiredScreen({
    required this.block,
    required this.onOpenSettings,
    this.onChooseManual,
    super.key,
  });

  final LocationBlock block;
  final VoidCallback onOpenSettings;
  final VoidCallback? onChooseManual;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final serviceOff = block == LocationBlock.serviceOff;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.location_off_rounded,
                size: 56,
                color: AppColors.blue,
              ),
              const SizedBox(height: 24),
              Text(
                serviceOff
                    ? 'Ative a localização'
                    : 'Permita o acesso à localização',
                style: textTheme.headlineMedium?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                serviceOff
                    ? 'A localização do celular está desligada. O RotaSaúde '
                          'precisa dela para mostrar unidades próximas com GPS.'
                    : 'O acesso à localização está desligado. Permita o uso '
                          'enquanto o app está aberto para usar o GPS.',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.navy,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onOpenSettings,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(switch (block) {
                  LocationBlock.serviceOff => 'Ativar localização',
                  LocationBlock.permissionDenied => 'Permitir localização',
                  LocationBlock.permissionBlocked => 'Abrir permissões do app',
                }),
              ),
              if (onChooseManual != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onChooseManual,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: AppColors.blue,
                    side: const BorderSide(color: AppColors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Escolher localização manualmente'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
