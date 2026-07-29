import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sabuflix design system.
///
/// A warm, editorial visual language — deep warm-charcoal canvas, cream
/// type, a signature terracotta accent used sparingly, and serif display
/// headlines paired with a disciplined sans interface layer.
class SabuflixTheme {
  SabuflixTheme._();

  // --- Core palette -------------------------------------------------
  static const Color background = Color(0xFF262624);
  static const Color surface = Color(0xFF30302E);
  static const Color surfaceLight = Color(0xFF3A3935);
  static const Color elevated = Color(0xFF44433E);
  static const Color border = Color(0xFF3E3D39);
  static const Color borderStrong = Color(0xFF52514B);

  // Signature accent — Sabuflix terracotta, used only for primary actions,
  // active states, and the wordmark mark.
  static const Color accent = Color(0xFFD97757);
  static const Color accentHover = Color(0xFFE28A6C);
  static const Color accentMuted = Color(0xFFB35F42);

  // Supplementary semantic tokens.
  static const Color gold = Color(0xFFE8B65A);
  static const Color tvBadge = Color(0xFF8A9A6E);
  static const Color movieBadge = accent;
  static const Color success = Color(0xFF8A9A6E);

  // Text scale — warm cream on warm charcoal, never pure black/white.
  static const Color textPrimary = Color(0xFFF5F4ED);
  static const Color textSecondary = Color(0xFFB8B6AC);
  static const Color textMuted = Color(0xFF87857A);

  // --- Typography -----------------------------------------------------
  // A warm editorial serif for display headlines (titles, hero copy),
  // paired with Inter for interface chrome — the same pairing Claude uses.
  static TextStyle headline({
    double fontSize = 30,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textPrimary,
    double height = 1.14,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.fraunces(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle title({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textPrimary,
    double height = 1.25,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.fraunces(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textSecondary,
    double height = 1.5,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle label({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textMuted,
    double letterSpacing = 0.4,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle caption({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textSecondary,
    double letterSpacing = 0.6,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // --- Brand wordmark ---------------------------------------------------
  // A serif wordmark preceded by the terracotta asterisk mark — see
  // widgets/wordmark.dart for the full composition.
  static TextStyle wordmark({
    double fontSize = 22,
    Color color = textPrimary,
  }) {
    return GoogleFonts.fraunces(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 0,
      height: 1.0,
    );
  }

  static TextStyle wordmarkGlyph({
    double fontSize = 22,
    Color color = accent,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
    );
  }

  // --- Reusable shapes & surfaces ----------------------------------------
  static BorderRadius get radiusSm => const BorderRadius.all(Radius.circular(8));
  static BorderRadius get radiusMd => const BorderRadius.all(Radius.circular(12));
  static BorderRadius get radiusLg => const BorderRadius.all(Radius.circular(16));
  static BorderRadius get radiusXl => const BorderRadius.all(Radius.circular(22));
  static BorderRadius get radiusPill => const BorderRadius.all(Radius.circular(999));

  static const Duration durationFast = Duration(milliseconds: 180);
  static const Duration durationMed = Duration(milliseconds: 260);
  static const Curve curveStandard = Curves.easeOutCubic;

  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  /// Subtle dark glass effect used by overlays / floating bars.
  static BoxDecoration glassSurface({
    Color? color,
    double alpha = 0.88,
    BorderRadius radius = const BorderRadius.all(Radius.circular(20)),
    bool withBorder = true,
  }) {
    return BoxDecoration(
      color: (color ?? surface).withValues(alpha: alpha),
      borderRadius: radius,
      border: withBorder ? Border.all(color: border, width: 1) : null,
      boxShadow: shadowMd,
    );
  }

  /// Flat outlined pill used for compact metadata tags (age rating, format).
  static BoxDecoration tagDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: surfaceLight,
      borderRadius: radiusSm,
      border: Border.all(color: borderColor ?? border),
    );
  }

  // --- Theme data ----------------------------------------------------
  static ThemeData get themeData {
    final base = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        onSurface: textPrimary,
        error: accentHover,
      ),
      splashColor: accent.withValues(alpha: 0.10),
      highlightColor: accent.withValues(alpha: 0.06),
      dividerColor: border,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyLarge: GoogleFonts.inter(color: textPrimary),
        bodyMedium: GoogleFonts.inter(color: textSecondary),
        titleLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: title(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 22),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceLight,
          elevation: 0,
          splashFactory: NoSplash.splashFactory,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: surfaceLight,
          side: const BorderSide(color: borderStrong),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        hintStyle: body(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: borderStrong, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        selectedColor: accent,
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        activeTrackColor: accent,
        inactiveTrackColor: borderStrong,
        thumbColor: Colors.white,
        overlayColor: Color(0x33FFFFFF),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceLight,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: border),
        ),
        textStyle: GoogleFonts.inter(color: textPrimary, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevated,
        contentTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: radiusMd,
          side: const BorderSide(color: border),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
    );
    return base;
  }
}
