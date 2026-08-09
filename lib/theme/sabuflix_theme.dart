import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sabuflix design system.
///
/// A restrained, monochrome-first visual language modelled on Apple's
/// Human Interface Guidelines — true-black canvas, the system gray scale,
/// a single sparing accent, and frosted "Liquid Glass" materials for
/// floating chrome. No badges, no decorative glyphs, no color noise.
class SabuflixTheme {
  SabuflixTheme._();

  // --- Core palette — Apple's own system gray scale (dark mode) --------
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF1C1C1E); // systemGray6
  static const Color surfaceLight = Color(0xFF2C2C2E); // systemGray5
  static const Color elevated = Color(0xFF3A3A3C); // systemGray4
  static const Color border = Color(0xFF38383A);
  static const Color borderStrong = Color(0xFF545458); // separator, opaque

  // Signature accent — Apple's system blue, used only for selection state
  // and small interactive affordances. Never for decoration.
  static const Color accent = Color(0xFF0A84FF);
  static const Color accentHover = Color(0xFF409CFF);
  static const Color accentMuted = Color(0xFF0060C2);

  // Supplementary semantic tokens — Apple system colors.
  static const Color gold = Color(0xFFFFD60A); // systemYellow, ratings only
  static const Color success = Color(0xFF30D158); // systemGreen

  // Text scale — true label hierarchy, solid grays (not alpha) for
  // predictable contrast over photography.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF98989D);
  static const Color textMuted = Color(0xFF636366);

  // --- Typography -------------------------------------------------------
  // Manrope throughout, in place of the default UI grotesques. Its high
  // x-height, flat terminals and near-closed apertures give the wide, cinematic
  // set that tvOS interfaces are built on, and the negative tracking below is
  // what actually sells the Apple TV feel — type gets tighter as it gets
  // bigger, exactly like SF Pro Display's optical sizes.

  /// Poster-scale type: title cards, hero copy, empty-state headers.
  static TextStyle display({
    double fontSize = 40,
    FontWeight fontWeight = FontWeight.w800,
    Color color = textPrimary,
    double height = 1.05,
    double letterSpacing = -1.4,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle headline({
    double fontSize = 30,
    FontWeight fontWeight = FontWeight.w800,
    Color color = textPrimary,
    double height = 1.1,
    double letterSpacing = -0.9,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle title({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double height = 1.2,
    double letterSpacing = -0.5,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w500,
    Color color = textSecondary,
    double height = 1.45,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: -0.2,
    );
  }

  /// All-caps section eyebrow. The only place tracking goes positive.
  static TextStyle label({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textMuted,
    double letterSpacing = 0.6,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle caption({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color color = textSecondary,
    double letterSpacing = -0.25,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // --- Brand wordmark -----------------------------------------------
  // Plain type, nothing else — no mark, no glyph, no color accent. Set heavy
  // and very tight, the way streaming wordmarks are locked up on tvOS.
  static TextStyle wordmark({
    double fontSize = 20,
    Color color = textPrimary,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: -1.0,
      height: 1.0,
    );
  }

  // --- Reusable shapes & motion ------------------------------------------
  static BorderRadius get radiusSm => const BorderRadius.all(Radius.circular(10));
  static BorderRadius get radiusMd => const BorderRadius.all(Radius.circular(14));
  static BorderRadius get radiusLg => const BorderRadius.all(Radius.circular(20));
  static BorderRadius get radiusXl => const BorderRadius.all(Radius.circular(28));
  static BorderRadius get radiusPill => const BorderRadius.all(Radius.circular(999));

  static const Duration durationFast = Duration(milliseconds: 220);
  static const Duration durationMed = Duration(milliseconds: 380);
  static const Curve curveStandard = Curves.easeOutCubic;
  // A gentle overshoot that reads like UIKit's spring animations.
  static const Curve curveSpring = Curves.easeOutBack;

  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ];

  /// Hairline used on the top/light edge of glass panels to fake a
  /// specular highlight, matched by a darker line on the bottom edge.
  static Border get glassBorder => Border.all(color: Colors.white.withValues(alpha: 0.14), width: 0.6);

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
        error: Color(0xFFFF453A),
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerColor: border,
      textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyLarge: GoogleFonts.manrope(color: textPrimary),
        bodyMedium: GoogleFonts.manrope(color: textSecondary),
        titleLarge: GoogleFonts.manrope(color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.6),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: title(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 22),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: background,
          disabledBackgroundColor: surfaceLight,
          elevation: 0,
          splashFactory: NoSplash.splashFactory,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(980)),
          ),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(980)),
          ),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.4),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          splashFactory: NoSplash.splashFactory,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.4),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        hintStyle: body(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: accent, width: 1.2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        selectedColor: textPrimary,
        labelStyle: GoogleFonts.manrope(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: GoogleFonts.manrope(color: background, fontSize: 13, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(980)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        activeTrackColor: Colors.white,
        inactiveTrackColor: Color(0x33FFFFFF),
        thumbColor: Colors.white,
        overlayColor: Color(0x1FFFFFFF),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: elevated,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: GoogleFonts.manrope(color: textPrimary, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevated,
        contentTextStyle: GoogleFonts.manrope(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: textPrimary),
    );
    return base;
  }
}
