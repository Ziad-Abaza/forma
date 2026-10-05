import 'package:flutter/material.dart';

/// Centralized Design System Tokens for Forma Health & Wellness.
///
/// Designed to convey Calmness, Precision, Personal Progress, and Trust.
/// No neon accents, glowing cyberpunk borders, or AI-dashboard visual noise.
class FormaTheme {
  // --- Surfaces & Backgrounds ---
  // Deep slate-obsidian tone: low eye strain, high contrast, medical/fitness clarity
  static const Color obsidianBackground = Color(0xFF0C1017);
  static const Color surfaceCard = Color(0xFF141A24);
  static const Color surfaceElevated = Color(0xFF1C2433);
  static const Color borderSubtle = Color(0xFF263244);
  static const Color borderStrong = Color(0xFF38465C);

  // --- Brand & Functional Accents ---
  // Refined Health Emerald/Sage Teal (Trustworthy, biological, healthy, non-neon)
  static const Color primaryTeal = Color(0xFF14B8A6); // Calm emerald teal
  static const Color primaryTealDark = Color(0xFF0D9488);
  static const Color primaryTealLight = Color(0xFF2DD4BF);

  static const Color secondaryMint = Color(0xFF10B981); // Natural vibrant mint
  static const Color accentCyan = Color(0xFF0EA5E9); // Restrained sky blue

  // Functional Semantic Feedback
  static const Color alertCoral = Color(0xFFEF4444); // Standard accessible red
  static const Color criticalCrimson = alertCoral;
  static const Color warningAmber = Color(0xFFF59E0B); // Amber warning
  static const Color successGreen = Color(0xFF10B981); // Calming success green
  static const Color infoBlue = Color(0xFF3B82F6);

  // --- Typography & Text Hierarchy ---
  static const Color textPrimary = Color(0xFFF8FAFC); // Clean high-legibility off-white (98% lightness)
  static const Color textSecondary = Color(0xFF94A3B8); // Muted slate (meets >4.5:1 on background)
  static const Color textTertiary = Color(0xFF64748B); // Supporting captions & units (>3:1 contrast)

  // --- Epistemic Trust Status Tokens ---
  // Subdued, clinical, informational tokens rather than bright multi-colored pills
  static const Color badgeMeasured = Color(0xFF2563EB); // Reliable cobalt
  static const Color badgeCalculated = Color(0xFF7C3AED); // Muted calculation purple
  static const Color badgeEstimated = Color(0xFFD97706); // Restrained amber
  static const Color badgeAsserted = Color(0xFF059669); // Forest green
  static const Color badgeRecommended = Color(0xFF0D9488); // Sage teal

  // --- Glass & Surfaces ---
  static const Color glassFill = Color(0x0FFFFFFF);
  static const Color glassBorder = Color(0x1F263244);
  static const Color glassFallback = Color(0xF0141A24);
  static const double glassBlur = 12.0;

  // --- Radius Scale ---
  static const double radiusSmall = 8.0;
  static const double radiusTile = 12.0;
  static const double radiusCard = 14.0;
  static const double radiusBubble = 16.0;
  static const double radiusBubbleTail = 4.0;

  // --- Spacing Scale ---
  static const double space2xs = 4.0;
  static const double spaceXs = 8.0;
  static const double spaceSm = 12.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 20.0;
  static const double spaceXl = 24.0;
  static const double space2xl = 32.0;

  // --- Motion & Animation ---
  static const Duration motionFast = Duration(milliseconds: 120);
  static const Duration motionBase = Duration(milliseconds: 200);
  static const Duration motionSlow = Duration(milliseconds: 320);
  static const Curve motionCurve = Curves.easeOutCubic;

  /// Dark Theme builder for the specified locale (English / Arabic).
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
        onPrimary: Colors.black,
        secondary: secondaryMint,
        onSecondary: Colors.black,
        surface: surfaceCard,
        onSurface: textPrimary,
        error: alertCoral,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: obsidianBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: borderSubtle, width: 1),
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: primaryTeal, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTeal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderSubtle),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: isArabic ? 1.4 : 1.2,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: isArabic ? 1.4 : 1.2,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: isArabic ? 1.4 : 1.25,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: isArabic ? 1.4 : 1.3,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.normal,
          height: isArabic ? 1.5 : 1.4,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.normal,
          height: isArabic ? 1.5 : 1.4,
        ),
        labelSmall: TextStyle(
          color: textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          height: isArabic ? 1.4 : 1.2,
        ),
      ),
    );
  }
}
