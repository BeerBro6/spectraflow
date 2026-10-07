import 'package:flutter/material.dart';

class SpectraTheme {
  // Brand Colors based on the Prism Soundwave identity
  static const Color obsidian = Color(0xFF090B10);
  static const Color darkSurface = Color(0xFF131722);
  static const Color glassCard = Color(0x221E2433);
  static const Color glassBorder = Color(0x33FFFFFF);

  // Neon Refraction Colors
  static const Color neonMagenta = Color(0xFFFF2E93);
  static const Color electricViolet = Color(0xFF9D4EDD);
  static const Color cyanWave = Color(0xFF00F2FE);
  static const Color laserWhite = Color(0xFFFFFFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidian,
      colorScheme: const ColorScheme.dark(
        primary: cyanWave,
        secondary: neonMagenta,
        tertiary: electricViolet,
        surface: darkSurface,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: cyanWave,
        inactiveTrackColor: Colors.white24,
        thumbColor: neonMagenta,
        overlayColor: neonMagenta.withValues(alpha: 0.2),
        trackHeight: 4,
      ),
    );
  }
}
