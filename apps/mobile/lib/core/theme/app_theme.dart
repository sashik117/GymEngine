import 'package:flutter/material.dart';

enum GymThemeMode { dark, light }

abstract final class AppColors {
  static var mode = GymThemeMode.dark;

  static const electricLime = Color(0xFFCCFF00);
  static const emerald = Color(0xFF10B981);
  static const emeraldStrong = Color(0xFF059669);

  static bool get isLight => mode == GymThemeMode.light;

  static Color get black => isLight ? Color(0xFFF1F5F9) : Color(0xFF0B0F19);
  static Color get surface => isLight ? Color(0xFFF8FAFC) : Color(0xFF111827);
  static Color get panel => isLight ? Color(0xFFFFFFFF) : Color(0xFF1E293B);
  static Color get border => isLight ? Color(0xFFCBD5E1) : Color(0xFF334155);
  static Color get text => isLight ? Color(0xFF0F172A) : Color(0xFFF8FAFC);
  static Color get muted => isLight ? Color(0xFF64748B) : Color(0xFF94A3B8);
  static Color get lime => isLight ? emerald : electricLime;
  static Color get accentStrong => isLight ? emeraldStrong : electricLime;
  static Color get ink => isLight ? Color(0xFFFFFFFF) : Color(0xFF020617);
  static Color get radarGrid => isLight ? Color(0xFF94A3B8) : Color(0xFF64748B);
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.panel,
        contentTextStyle: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
