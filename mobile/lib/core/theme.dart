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
  static const Color warningAmber = Color(0xFFFF9F1C);
  static const Color successGreen = Color(0xFF2EA043);

  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textTertiary = Color(0xFF6E7681);

  // Epistemic Class Badge Colors
  static const Color badgeMeasured = Color(0xFF1F6FEB); // Calm Royal Blue
  static const Color badgeCalculated = Color(0xFF8957E5); // Purple
  static const Color badgeEstimated = Color(0xFFD29922); // Amber
  static const Color badgeAsserted = Color(0xFF238636); // Forest Green

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
