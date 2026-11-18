import 'package:flutter/material.dart';

class ScreenBackButton extends StatelessWidget {
  const ScreenBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Voltar',
    icon: const BackButtonIcon(),
    onPressed: () => Navigator.of(context).maybePop(),
  );
}
