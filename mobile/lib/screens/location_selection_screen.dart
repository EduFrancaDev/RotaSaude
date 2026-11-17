import 'package:flutter/material.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/services/search_text.dart';
import 'package:rotasaude/theme/app_colors.dart';
import 'package:rotasaude/widgets/screen_back_button.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key, this.currentArea});

  final SearchArea? currentArea;

  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final _controller = TextEditingController();
  SearchArea? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentArea;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SearchArea> get _matches {
    final query = normalizedSearchText(_controller.text);
    if (query.isEmpty) return SearchArea.suggestions;
    return SearchArea.suggestions
        .where((area) => normalizedSearchText(area.name).contains(query))
        .toList(growable: false);
  }

  void _choose(SearchArea area) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = area;
      _controller.text = area.name;
    });
  }

  void _confirm() {
    final area = _selected;
    if (area == null) return;
    Navigator.of(context).pop(area);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final suggestions = _matches;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher cidade'),
        leading: const ScreenBackButton(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Text(
                    'Escolha uma cidade atendida pelo RotaSaúde.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() => _selected = null),
                    onSubmitted: (_) {
                      if (suggestions.length == 1) _choose(suggestions.single);
                    },
                    decoration: InputDecoration(
                      labelText: 'Buscar cidade',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              onPressed: () => setState(() {
                                _controller.clear();
                                _selected = null;
                              }),
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (suggestions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Nenhuma cidade encontrada. Edite a busca ou escolha uma das cidades disponíveis abaixo.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  for (final area
                      in suggestions.isEmpty
                          ? SearchArea.suggestions
                          : suggestions) ...[
                    _AreaSuggestionTile(
                      area: area,
                      selected: _selected?.id == area.id,
                      onTap: () => _choose(area),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected == null ? null : _confirm,
                  child: Text(
                    _selected == null
                        ? 'Selecione uma sugestão'
                        : 'Ver unidades em ${_selected!.name.split(',').first}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaSuggestionTile extends StatelessWidget {
  const _AreaSuggestionTile({
    required this.area,
    required this.selected,
    required this.onTap,
  });

  final SearchArea area;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? const Color(0xFFEAF4FA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 70),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? AppColors.blue : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        area.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        area.suggestionSubtitle,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: AppColors.blue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
