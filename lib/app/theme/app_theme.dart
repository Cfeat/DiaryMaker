import 'package:flutter/material.dart';

import 'font_option.dart';

/// 日记向视觉：纸感浅底 + 墨色字，避免默认灰白简陋感。
abstract final class AppTheme {
  static ThemeData build({
    required AppFontOption font,
    required AppColorMood mood,
  }) {
    final seed = mood.seed;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xFFF6F1E8),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F1E8),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: const Color(0xFFF6F1E8).withValues(alpha: 0.92),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.72),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.55),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: seed.withValues(alpha: 0.25)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final textTheme = font.textTheme(base.textTheme);
    return base.copyWith(
      textTheme: textTheme.apply(
        bodyColor: const Color(0xFF1C1B19),
        displayColor: const Color(0xFF1C1B19),
      ),
      primaryTextTheme: textTheme,
    );
  }
}
