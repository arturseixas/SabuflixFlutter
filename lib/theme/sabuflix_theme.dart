import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sabuflix's cinematic editorial system: warm charcoal, theatrical type,
/// one vermilion accent and matte layers that let artwork stay dominant.
class SabuflixTheme {
  SabuflixTheme._();

  static const Color background = Color(0xFF0B0B0D);
  static const Color surface = Color(0xFF151518);
  static const Color surfaceLight = Color(0xFF1E1E22);
  static const Color elevated = Color(0xFF29292E);
  static const Color border = Color(0xFF2B2B30);
  static const Color borderStrong = Color(0xFF45454C);

  static const Color accent = Color(0xFFC84332);
  static const Color accentHover = Color(0xFFD95642);
  static const Color accentMuted = Color(0xFF7B2A20);
  static const Color accentSoft = Color(0xFF321A18);

  static const Color gold = accent;
  static const Color success = Color(0xFF5ABF88);
  static const Color textPrimary = Color(0xFFF4F1EA);
  static const Color textSecondary = Color(0xFFB5B0A8);
  static const Color textMuted = Color(0xFF77736E);

  static TextStyle display({
    double fontSize = 40,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double height = 1.02,
    double letterSpacing = -1.5,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle headline({
    double fontSize = 30,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double height = 1.08,
    double letterSpacing = -1.0,
  }) {
    return GoogleFonts.spaceGrotesk(
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
    double height = 1.18,
    double letterSpacing = -0.55,
  }) {
    return GoogleFonts.spaceGrotesk(
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
    return GoogleFonts.dmSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: -0.1,
    );
  }

  static TextStyle label({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textMuted,
    double letterSpacing = 0.5,
  }) {
    return GoogleFonts.dmSans(
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
    double letterSpacing = -0.1,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle wordmark({double fontSize = 20, Color color = textPrimary}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: -1.2,
      height: 1,
    );
  }

  // Cards use 12-18px radii; compact controls use 8px; primary actions are pills.
  static BorderRadius get radiusSm =>
      const BorderRadius.all(Radius.circular(8));
  static BorderRadius get radiusMd =>
      const BorderRadius.all(Radius.circular(12));
  static BorderRadius get radiusLg =>
      const BorderRadius.all(Radius.circular(18));
  static BorderRadius get radiusXl =>
      const BorderRadius.all(Radius.circular(26));
  static BorderRadius get radiusPill =>
      const BorderRadius.all(Radius.circular(999));

  static const Duration durationFast = Duration(milliseconds: 180);
  static const Duration durationMed = Duration(milliseconds: 340);
  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.easeOutCubic;

  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: const Color(0xFF070708).withValues(alpha: 0.42),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: const Color(0xFF070708).withValues(alpha: 0.5),
          blurRadius: 34,
          offset: const Offset(0, 16),
        ),
      ];

  static Border get glassBorder =>
      Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.7);

  static ThemeData get themeData {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        onSurface: textPrimary,
        error: Color(0xFFFF6B5C),
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerColor: border,
      textTheme:
          GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyLarge: GoogleFonts.dmSans(color: textPrimary),
        bodyMedium: GoogleFonts.dmSans(color: textSecondary),
        titleLarge: GoogleFonts.spaceGrotesk(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: title(fontSize: 21),
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 22),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: textPrimary,
          disabledBackgroundColor: surfaceLight,
          elevation: 0,
          splashFactory: NoSplash.splashFactory,
          shape: const StadiumBorder(),
          textStyle:
              GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: surfaceLight,
          side: const BorderSide(color: borderStrong),
          shape: const StadiumBorder(),
          textStyle:
              GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          splashFactory: NoSplash.splashFactory,
          textStyle:
              GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        hintStyle: body(color: textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: radiusMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        selectedColor: accent,
        labelStyle: GoogleFonts.dmSans(
            color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
        secondaryLabelStyle: GoogleFonts.dmSans(
            color: textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: radiusPill),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        activeTrackColor: accent,
        inactiveTrackColor: Color(0x33FFFFFF),
        thumbColor: accent,
        overlayColor: Color(0x22C84332),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: elevated, borderRadius: radiusSm),
        textStyle: GoogleFonts.dmSans(color: textPrimary, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevated,
        contentTextStyle: GoogleFonts.dmSans(
            color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
    );
  }
}
