import 'package:flutter/material.dart';

class CogniloadTheme {
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceElevated = Color(0xFF1A2235);
  static const Color surfaceHighlight = Color(0xFF1F2D42);

  static const Color primary = Color(0xFF00D4FF);
  static const Color primaryDim = Color(0xFF0099BB);
  static const Color secondary = Color(0xFF7C3AED);
  static const Color accent = Color(0xFFFFB800);
  static const Color accentRed = Color(0xFFFF4757);
  static const Color accentGreen = Color(0xFF00E676);

  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF8899BB);
  static const Color textMuted = Color(0xFF4A5568);

  static const Color scoreLow = Color(0xFF00E676);
  static const Color scoreMedium = Color(0xFFFFB800);
  static const Color scoreHigh = Color(0xFFFF6B35);
  static const Color scoreCritical = Color(0xFFFF4757);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: primary,
        secondary: secondary,
        error: accentRed,
        onSurface: textPrimary,
        onPrimary: background,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1F2D42), width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: textMuted, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 22);
          }
          return const IconThemeData(color: textMuted, size: 22);
        }),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary, fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -2),
        displayMedium: TextStyle(color: textPrimary, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1),
        headlineLarge: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textSecondary, fontSize: 15),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
        bodySmall: TextStyle(color: textMuted, fontSize: 11),
      ),
    );
  }

  static Color scoreColor(double score) {
    if (score < 30) return scoreLow;
    if (score < 60) return scoreMedium;
    if (score < 80) return scoreHigh;
    return scoreCritical;
  }

  static String scoreLabel(double score) {
    if (score < 30) return 'Optimal';
    if (score < 60) return 'Moderate';
    if (score < 80) return 'High Load';
    return 'Critical';
  }
}