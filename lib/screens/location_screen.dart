import 'package:flutter/material.dart';
import 'package:rotasaude/theme/app_colors.dart';

/// Primeira etapa após a apresentação: escolha manual de uma cidade.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final TextEditingController _cityController = TextEditingController();
  String? _selectedCity;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  void _selectCity() {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _selectedCity = city);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Localização')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Onde você quer buscar atendimento?',
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Informe uma cidade para iniciar. Você pode alterar a escolha '
              'a qualquer momento nesta tela.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _cityController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _selectedCity = null),
              onSubmitted: (_) => _selectCity(),
              decoration: const InputDecoration(
                labelText: 'Cidade',
                hintText: 'Ex.: São Paulo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _cityController.text.trim().isEmpty
                  ? null
                  : _selectCity,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Usar esta cidade'),
            ),
            if (_selectedCity != null) ...[
              const SizedBox(height: 32),
              Text(
                'Cidade escolhida',
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(_selectedCity!, style: textTheme.bodyLarge),
              const SizedBox(height: 16),
              Text(
                'A consulta às unidades ainda não está disponível nesta versão.',
                style: textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
