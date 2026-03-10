import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xff111827);
  static const muted = Color(0xff667085);
  static const page = Color(0xfff7f9fc);
  static const border = Color(0xffd8e2ef);
  static const primary = Color(0xff2563eb);
  static const primaryDark = Color(0xff0d0a35);
  static const success = Color(0xff10b981);
  static const warning = Color(0xfff59e0b);
  static const danger = Color(0xffdc2626);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: success,
      error: danger,
      surface: Colors.white,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: page,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: const Color(0xff60a5fa),
      secondary: success,
      error: const Color(0xfff87171),
      surface: const Color(0xff111827),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xff0b1220),
      brightness: Brightness.dark,
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    final borderSide = BorderSide(color: border.withValues(alpha: 0.85));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: borderSide,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: scheme.primary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
