import 'package:flutter/material.dart';

/// HydrateAI brand palette.
class AppColors {
  static const navy = Color(0xFF0D1B2A);
  static const teal = Color(0xFF00B4D8);
  static const gold = Color(0xFFF7C948);
  static const offwhite = Color(0xFFF0F4F8);
}

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.navy,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.teal,
    secondary: AppColors.gold,
    surface: AppColors.navy,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.navy,
    foregroundColor: AppColors.offwhite,
    elevation: 0,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.teal,
    foregroundColor: Colors.white,
  ),
);
