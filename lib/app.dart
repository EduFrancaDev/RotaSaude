import 'package:flutter/material.dart';
import 'package:rotasaude/screens/home_screen.dart';
import 'package:rotasaude/theme/app_theme.dart';

class RotaSaudeApp extends StatelessWidget {
  const RotaSaudeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RotaSaúde',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
