import 'package:flutter/material.dart';
import 'package:rotasaude/theme/app_colors.dart';

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: AppColors.blue,
      onPrimary: Colors.white,
      secondary: AppColors.teal,
      onSecondary: AppColors.navy,
      surface: Colors.white,
      onSurface: AppColors.navy,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.navy,
      centerTitle: false,
    ),
  );
}
