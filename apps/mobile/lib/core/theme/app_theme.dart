import 'package:flutter/material.dart';

enum GymThemeMode { dark, light }

abstract final class AppColors {
  static var mode = GymThemeMode.dark;

  static const ink = Color(0xFF000000);
  static const lime = Color(0xFFCCFF00);

  static bool get isLight => mode == GymThemeMode.light;

  static Color get black => isLight ? Color(0xFFF5F7EF) : Color(0xFF000000);
  static Color get surface => isLight ? Color(0xFFEFF3E5) : Color(0xFF0A0D0A);
  static Color get panel => isLight ? Color(0xFFFFFFFF) : Color(0xFF111510);
  static Color get border => isLight ? Color(0xFFC9D5B8) : Color(0xFF273020);
  static Color get text => isLight ? Color(0xFF111510) : Color(0xFFF4F7EF);
  static Color get muted => isLight ? Color(0xFF5E6758) : Color(0xFF8F9888);
}

abstract final class AppTheme {
  static ThemeData forMode(GymThemeMode mode) {
    AppColors.mode = mode;
    final base = mode == GymThemeMode.light
        ? ThemeData.light(useMaterial3: true)
        : ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: ColorScheme.fromSeed(
        primary: AppColors.lime,
        seedColor: AppColors.lime,
        brightness: mode == GymThemeMode.light
            ? Brightness.light
            : Brightness.dark,
        surface: AppColors.surface,
        onPrimary: AppColors.ink,
        onSurface: AppColors.text,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
        fontFamily: 'Roboto',
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        filled: true,
        fillColor: AppColors.surface,
      ),
    );
  }
}
