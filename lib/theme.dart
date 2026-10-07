import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0D0D13);
  static const card = Color(0xFF14141E);
  static const secondary = Color(0xFF1D1D2A);
  static const border = Color(0xFF2A2A3B);
  static const primary = Color(0xFF7C6CFF);
  static const accent = Color(0xFF5AD1E6);
  static const warm = Color(0xFFF2B05E);
  static const bridge = Color(0xFF7BE0A3);
  static const destructive = Color(0xFFE5606B);
}

ThemeData _base(ColorScheme scheme, Color background, Color card, Color secondary, Color border) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    cardColor: card,
    dividerColor: border,
    appBarTheme: AppBarTheme(backgroundColor: card, elevation: 0, foregroundColor: scheme.onSurface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: secondary,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary)),
    ),
  );
}

ThemeData darkTheme() => _base(
      const ColorScheme.dark().copyWith(primary: AppColors.primary, secondary: AppColors.accent, surface: AppColors.card, error: AppColors.destructive),
      AppColors.background,
      AppColors.card,
      AppColors.secondary,
      AppColors.border,
    );

ThemeData lightTheme() => _base(
      const ColorScheme.light().copyWith(primary: AppColors.primary, secondary: AppColors.accent, error: AppColors.destructive),
      const Color(0xFFF5F5FA),
      Colors.white,
      const Color(0xFFEAEAF2),
      const Color(0xFFD4D4E2),
    );
