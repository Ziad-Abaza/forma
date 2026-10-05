import 'package:flutter/material.dart';

class FormaTheme {
  // Centralized Design Tokens derived from logo.png visual identity
  static const Color obsidianBackground = Color(0xFF0D1117);
  static const Color surfaceCard = Color(0xFF161B22);
  static const Color surfaceElevated = Color(0xFF21262D);
  static const Color borderSubtle = Color(0xFF30363D);

  static const Color primaryTeal = Color(0xFF00E5FF);
  static const Color secondaryMint = Color(0xFF2EC4B6);
  static const Color accentCyan = Color(0xFF00B4D8);
  static const Color alertCoral = Color(0xFFFF6B6B);
  static const Color criticalCrimson = alertCoral;
  static const Color warningAmber = Color(0xFFFF9F1C);
  static const Color successGreen = Color(0xFF2EA043);

  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  // A11 contrast fix: use #8B949E (~6:1 on obsidianBackground) instead of low contrast #6E7681
  static const Color textTertiary = Color(0xFF8B949E);

  // Glass & Bento Visual System Tokens (Spec §1.2)
  static const Color glassFill = Color(0x0FFFFFFF); // Colors.white @ 6%
  static const Color glassBorder = Color(0x1AFFFFFF); // Colors.white @ 10%
  static const Color glassFallback = Color(0xEB161B22); // #161B22 @ 92%
  static const double glassBlur = 20.0;

  static const double radiusBubble = 20.0;
  static const double radiusBubbleTail = 6.0;
  static const double radiusCard = 16.0;
  static const double radiusTile = 14.0;

  static const Duration motionFast = Duration(milliseconds: 120);
  static const Duration motionBase = Duration(milliseconds: 220);
  static const Duration motionSlow = Duration(milliseconds: 360);
  static const Curve motionCurve = Curves.easeOutCubic;

  // Epistemic Class Badge Colors
  static const Color badgeMeasured = Color(0xFF1F6FEB); // Calm Royal Blue
  static const Color badgeCalculated = Color(0xFF8957E5); // Purple
  static const Color badgeEstimated = Color(0xFFD29922); // Amber
  static const Color badgeAsserted = Color(0xFF238636); // Forest Green
  static const Color badgeRecommended = Color(0xFF00E5FF); // Teal

  static ThemeData darkTheme(Locale locale) {
    final bool isArabic = locale.languageCode == 'ar';
    final String fontFamily = isArabic ? 'Cairo' : 'Inter';

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: obsidianBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryTeal,
        secondary: secondaryMint,
        surface: surfaceCard,
        error: alertCoral,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: obsidianBackground,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: borderSubtle, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryTeal, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
