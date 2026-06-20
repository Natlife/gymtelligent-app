import 'package:flutter/material.dart';

// Global ValueNotifier to dynamically handle the theme throughout the whole application in real time
final ValueNotifier<ThemeData> appThemeNotifier = ValueNotifier<ThemeData>(
  AppTheme.darkTheme,
);

class AppTheme {
  // Brand Dark Colors (User Theme)
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF1A191A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static final Color textSecondary = const Color(0xFFFFFFFF).withOpacity(0.65);
  static final Color borderLight = const Color(0xFFF5F5F5).withOpacity(0.2);

  // Brand Light Colors (Admin Theme)
  static const Color backgroundLight = Color(0xFFF4F6F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1E293B);
  static final Color textSecondaryLight = const Color(
    0xFF1E293B,
  ).withOpacity(0.65);
  static final Color borderLightLight = const Color(
    0xFF1E293B,
  ).withOpacity(0.12);

  // Brand Neon Gradient Accents
  static const Color gradientStart = Color(0xFF00FE8B); // Neon Green
  static const Color gradientEnd = Color(0xFF00BBFC); // Neon Blue
  static const Color onGradient = Color(0xFF020617);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Dynamic color resolution helpers for seamless Light/Dark theme switching
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : textPrimaryLight;
  }

  static Color getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSecondary
        : textSecondaryLight;
  }

  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFE2E8F0);
  }

  // Dynamic Neon Border for active elements based on current brightness
  static Color getActiveBorderColor(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return isLight
        ? const Color(0xFF059669)
        : gradientStart; // Deep Emerald for Light, Neon Green for Dark
  }

  // User Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: gradientStart,
      cardColor: surface,
      colorScheme: const ColorScheme.dark(
        primary: gradientStart,
        secondary: gradientEnd,
        surface: surface,
      ),
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontSize: 55,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.normal,
          color: textSecondary,
          height: 1.4,
        ),
        bodyLarge: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        labelLarge: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.bold,
          color: onGradient,
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
    );
  }

  // Admin Light Theme (Contrast Mode)
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: gradientStart,
      cardColor: surfaceLight,
      colorScheme: const ColorScheme.light(
        primary: gradientStart,
        secondary: gradientEnd,
        surface: surfaceLight,
      ),
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontSize: 55,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.normal,
          color: textSecondaryLight,
          height: 1.4,
        ),
        bodyLarge: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
        ),
        labelLarge: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.bold,
          color: onGradient,
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: surfaceLight),
    );
  }
}
