import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Capsule radius — the single value that enforces the pill-shape brand identity.
const double kCapsuleRadius = 50.0;

/// BloodPulse Theme Configuration
///
/// Typography contract:
///   • Georgia  → displayLarge, headlineLarge, headlineMedium, titleLarge
///   • Inter    → body*, label*, everything else
///
/// Shape contract:
///   • Buttons & InputFields → BorderRadius.circular(kCapsuleRadius)
class AppTheme {
  AppTheme._();

  // ────────────────────────────────────────────────────────────────────────────
  // LIGHT THEME
  // ────────────────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      // ── Scaffold ──
      scaffoldBackgroundColor: AppColors.surface,

      // ── Color Scheme ──
      colorScheme: const ColorScheme.light(
        primary:          AppColors.primary,
        onPrimary:        AppColors.onPrimary,
        secondary:        AppColors.secondary,
        onSecondary:      AppColors.onPrimary,
        tertiary:         AppColors.tertiary,
        onTertiary:       AppColors.onPrimary,
        surface:          AppColors.surface,
        onSurface:        AppColors.textLight,
        error:            AppColors.error,
        onError:          AppColors.onPrimary,
      ),

      // ── Typography ──
      textTheme: _buildTextTheme(onLight: true),
      primaryTextTheme: _buildTextTheme(onLight: false),

      // ── Elevated Button ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const StadiumBorder(),                 // full pill
          elevation: 0,
          shadowColor: AppColors.primaryGlow,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ── Outlined Button ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ── Input Decoration ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.neutral,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.neutral,
        ),
        errorStyle: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.error,
        ),
        // Default border — capsule
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        // Focus ring uses brand red (#C30121)
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shadowColor: AppColors.primaryGlowSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _georgiaStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textLight,
        ),
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        shape: const StadiumBorder(),
        side: BorderSide(color: Colors.grey.shade300),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // DARK THEME
  // ────────────────────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,

      colorScheme: const ColorScheme.dark(
        primary:          AppColors.primary,
        onPrimary:        AppColors.onPrimary,
        secondary:        AppColors.secondary,
        onSecondary:      AppColors.onPrimary,
        tertiary:         AppColors.tertiary,
        onTertiary:       AppColors.onPrimary,
        surface:          AppColors.surfaceDark,
        onSurface:        AppColors.textDark,
        error:            AppColors.error,
        onError:          AppColors.onPrimary,
      ),

      textTheme: _buildTextTheme(onLight: false),
      primaryTextTheme: _buildTextTheme(onLight: true),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const StadiumBorder(),
          elevation: 0,
          shadowColor: AppColors.primaryGlow,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.neutral),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.neutral),
        errorStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _georgiaStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardDark,
        selectedColor: AppColors.primary,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        shape: const StadiumBorder(),
        side: const BorderSide(color: Colors.transparent),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF2C2C2C),
        thickness: 1,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ────────────────────────────────────────────────────────────────────────────

  /// Builds the full [TextTheme] honouring the typography contract:
  ///   Georgia  → display / headline / title
  ///   Inter    → body / label / everything else
  static TextTheme _buildTextTheme({required bool onLight}) {
    final Color textColor = onLight ? AppColors.textLight : AppColors.textDark;

    TextStyle interStyle({required double fontSize, required FontWeight fontWeight, double letterSpacing = 0}) {
      return TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: const ['sans-serif'],
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: textColor,
        letterSpacing: letterSpacing,
      );
    }

    return TextTheme(
      // ── Display ──
      displayLarge: _georgiaStyle(
        fontSize: 57, fontWeight: FontWeight.bold, color: textColor,
      ),
      displayMedium: _georgiaStyle(
        fontSize: 45, fontWeight: FontWeight.bold, color: textColor,
      ),
      displaySmall: _georgiaStyle(
        fontSize: 36, fontWeight: FontWeight.bold, color: textColor,
      ),
      // ── Headline ──
      headlineLarge: _georgiaStyle(
        fontSize: 32, fontWeight: FontWeight.bold, color: textColor,
      ),
      headlineMedium: _georgiaStyle(
        fontSize: 28, fontWeight: FontWeight.w700, color: textColor,
      ),
      headlineSmall: _georgiaStyle(
        fontSize: 24, fontWeight: FontWeight.w700, color: textColor,
      ),
      // ── Title (Georgia) ──
      titleLarge: _georgiaStyle(
        fontSize: 22, fontWeight: FontWeight.w600, color: textColor,
      ),
      // ── Title / Body / Label — Inter ──
      titleMedium: interStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: interStyle(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: interStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: interStyle(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: interStyle(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: interStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      labelMedium: interStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: interStyle(fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 0.5),
    );
  }

  /// Convenience constructor for Georgia [TextStyle].
  static TextStyle _georgiaStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: 'Georgia',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}
