import 'package:flutter/material.dart';

class SabuflixTheme {
  SabuflixTheme._();

  static const Color background = Color(0xFF0B0C0E);
  static const Color surface = Color(0xFF15171A); // systemGray6
  static const Color surfaceLight = Color(0xFF202327); // systemGray5
  static const Color elevated = Color(0xFF2A2E33); // systemGray4
  static const Color border = Color(0xFF30343A);
  static const Color borderStrong = Color(0xFF626873); // separator, opaque

  static const Color accent = Color(0xFF648CFF);
  static const Color accentHover = Color(0xFF93AEFF);
  static const Color accentMuted = Color(0xFF1645C0);

  static const Color gold = Color(0xFFFFD60A); // systemYellow, ratings only
  static const Color success = Color(0xFF30D158); // systemGreen

  static const Color textPrimary = Color(0xFFF5F4F0);
  static const Color textSecondary = Color(0xFFBFC1C5);
  static const Color textMuted = Color(0xFF9CA2AB);

  static TextStyle display({
    double fontSize = 40,
    FontWeight fontWeight = FontWeight.w800,
    Color color = textPrimary,
    double height = 1.05,
    double letterSpacing = -1.4,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
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
    return TextStyle(
      fontFamily: 'Manrope',
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
    return TextStyle(
      fontFamily: 'Manrope',
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
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: -0.2,
    );
  }

  static TextStyle label({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textMuted,
    double letterSpacing = 0.6,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
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
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle wordmark({double fontSize = 20, Color color = textPrimary}) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: -1.0,
      height: 1.0,
    );
  }

  static BorderRadius get radiusSm =>
      const BorderRadius.all(Radius.circular(3));
  static BorderRadius get radiusMd =>
      const BorderRadius.all(Radius.circular(4));
  static BorderRadius get radiusLg =>
      const BorderRadius.all(Radius.circular(6));
  static BorderRadius get radiusXl =>
      const BorderRadius.all(Radius.circular(8));
  static BorderRadius get radiusPill =>
      const BorderRadius.all(Radius.circular(999));

  static const Duration durationFast = Duration(milliseconds: 220);
  static const Duration durationMed = Duration(milliseconds: 380);
  static const Curve curveStandard = Curves.easeOutCubic;
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

  static Border get glassBorder =>
      Border.all(color: Colors.white.withValues(alpha: 0.14), width: 0.6);

  static ThemeData get themeData {
    final base = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        onSurface: textPrimary,
        onPrimary: background,
        onSurfaceVariant: textSecondary,
        outline: borderStrong,
        error: Color(0xFFFF453A),
      ),
      splashFactory: InkRipple.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.white12,
      focusColor: Colors.white24,
      dividerColor: border,
      textTheme: ThemeData.dark().textTheme
          .apply(fontFamily: 'Manrope')
          .copyWith(
            bodyLarge: TextStyle(fontFamily: 'Manrope', color: textPrimary),
            bodyMedium: TextStyle(fontFamily: 'Manrope', color: textSecondary),
            titleLarge: TextStyle(
              fontFamily: 'Manrope',
              color: textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
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
          backgroundColor: const Color(0xFF204FE0),
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceLight,
          elevation: 0,
          splashFactory: NoSplash.splashFactory,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          textStyle: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          textStyle: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: -0.4,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          splashFactory: NoSplash.splashFactory,
          textStyle: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: -0.4,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        hintStyle: body(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
        labelStyle: TextStyle(
          fontFamily: 'Manrope',
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'Manrope',
          color: background,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
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
        textStyle: TextStyle(
          fontFamily: 'Manrope',
          color: textPrimary,
          fontSize: 12,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevated,
        contentTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: textPrimary,
      ),
    );
    return base;
  }
}
