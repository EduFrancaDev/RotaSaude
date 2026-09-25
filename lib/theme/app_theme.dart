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
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.background,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    ),
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.border,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.navy),
      bodyMedium: TextStyle(color: AppColors.navy),
      titleMedium: TextStyle(color: AppColors.navy),
      titleLarge: TextStyle(color: AppColors.navy),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.navy,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFE7F1FB),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.blue
              : AppColors.muted,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.blue
              : AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        );
      }),
    ),
  );

  static final primarySegmentedButtonStyle = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected)
          ? AppColors.blue
          : Colors.white;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected)
          ? Colors.white
          : AppColors.navy;
    }),
    side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
  );
}
