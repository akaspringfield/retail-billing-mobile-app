import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF17212B);
  static const muted = Color(0xFF65758A);
  static const border = Color(0xFFC8D5E6);
  static const page = Color(0xFFF3F8FC);
  static const primary = Color(0xFF2563EB);
  static const cyan = Color(0xFF39B9F2);
  static const navy = Color(0xFF0D0A35);
  static const success = Color(0xFF24713A);
  static const danger = Color(0xFF9B1C1C);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: AppColors.page,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: const TextStyle(
        color: AppColors.ink,
        fontSize: 30,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      titleLarge: const TextStyle(
        color: AppColors.ink,
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      bodyMedium: const TextStyle(
        color: AppColors.muted,
        fontSize: 14,
        height: 1.4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
      ),
    ),
  );
}
