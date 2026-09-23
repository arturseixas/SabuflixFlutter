import 'package:flutter/material.dart';

class SabuflixTheme {
  SabuflixTheme._();

  // Cinematheque palette: true black canvas, white type, a single electric
  // blue reserved for the primary action — the way a curated streaming
  // service lets the stills carry all the colour.
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceLight = Color(0xFF1C1C1C);
  static const Color elevated = Color(0xFF242424);
  static const Color border = Color(0xFF262626);
  static const Color borderStrong = Color(0xFF5C5C5C);

  static const Color accent = Color(0xFF8C9BFF);
  static const Color accentHover = Color(0xFFB4BEFF);
  static const Color accentMuted = Color(0xFF0012B8);

  static const Color gold = Color(0xFFFFFFFF); // ratings stay monochrome
  static const Color success = Color(0xFF3DDC84);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8B8);
  static const Color textMuted = Color(0xFF999999);

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

  // Square, print-like edges throughout.
  static BorderRadius get radiusSm => BorderRadius.zero;
  static BorderRadius get radiusMd =>
      const BorderRadius.all(Radius.circular(2));
  static BorderRadius get radiusLg =>
      const BorderRadius.all(Radius.circular(2));
  static BorderRadius get radiusXl =>
      const BorderRadius.all(Radius.circular(4));
  static BorderRadius get radiusPill =>
      const BorderRadius.all(Radius.circular(2));

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

  static SabuPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const SabuPalette.light()
          : const SabuPalette.dark();

  static ThemeData get themeData => _theme(Brightness.dark);
  static ThemeData get lightThemeData => _theme(Brightness.light);
  static const brandBlue = Color(0xFF001EFF);

  static ThemeData _theme(Brightness brightness) {
    final p = brightness == Brightness.light
        ? const SabuPalette.light()
        : const SabuPalette.dark();
    final shape = RoundedRectangleBorder(borderRadius: radiusMd);
    final text = const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -.2);
    final primary = ElevatedButton.styleFrom(
      backgroundColor: brandBlue,
      foregroundColor: Colors.white,
      disabledBackgroundColor: p.surfaceLight,
      disabledForegroundColor: p.textMuted,
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: shape,
      textStyle: text,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: p.background,
      colorScheme:
          ColorScheme.fromSeed(seedColor: brandBlue, brightness: brightness)
              .copyWith(
        primary: brandBlue,
        onPrimary: Colors.white,
        secondary: p.accent,
        onSecondary: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
        onSurfaceVariant: p.textSecondary,
        outline: p.borderStrong,
        outlineVariant: p.border,
        error: p.error,
        surfaceTint: Colors.transparent,
      ),
      textTheme: (brightness == Brightness.light
              ? ThemeData.light()
              : ThemeData.dark())
          .textTheme
          .apply(
              fontFamily: 'Manrope',
              bodyColor: p.textPrimary,
              displayColor: p.textPrimary),
      dividerColor: p.border,
      focusColor: p.accent.withValues(alpha: .2),
      appBarTheme: AppBarTheme(
          backgroundColor: p.background,
          foregroundColor: p.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: p.title(fontSize: 20)),
      iconTheme: IconThemeData(color: p.textSecondary, size: 22),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primary),
      filledButtonTheme: FilledButtonThemeData(style: primary),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        foregroundColor: p.textPrimary,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: p.textPrimary, width: 1.2),
        shape: shape,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: text,
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: p.textPrimary,
        shape: shape,
        minimumSize: const Size(48, 48),
        textStyle: text,
      )),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
        foregroundColor: p.textPrimary,
        minimumSize: const Size(48, 48),
        shape: shape,
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceLight,
        hintStyle: p.body(color: p.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: radiusMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: radiusMd, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: radiusMd,
            borderSide: BorderSide(color: p.textPrimary, width: 1.5)),
      ),
      chipTheme: ChipThemeData(
          backgroundColor: Colors.transparent,
          selectedColor: p.textPrimary,
          // Chips resolve only the label *colour* against their state.
          labelStyle: text.copyWith(
              fontSize: 13,
              color: WidgetStateColor.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? p.background
                      : p.textPrimary)),
          secondaryLabelStyle: text.copyWith(fontSize: 13, color: p.background),
          checkmarkColor: p.background,
          side: BorderSide(color: p.border),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
      dialogTheme: DialogThemeData(
          backgroundColor: p.surface,
          surfaceTintColor: Colors.transparent,
          shape: shape,
          titleTextStyle: p.headline(fontSize: 24),
          contentTextStyle: p.body()),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: p.surface,
          modalBackgroundColor: p.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radiusLg)),
      popupMenuTheme: PopupMenuThemeData(
          color: p.elevated,
          surfaceTintColor: Colors.transparent,
          textStyle: p.body(color: p.textPrimary),
          shape: shape),
      sliderTheme: SliderThemeData(
          activeTrackColor: p.textPrimary,
          thumbColor: p.textPrimary,
          inactiveTrackColor: p.border,
          trackHeight: 3),
      progressIndicatorTheme: ProgressIndicatorThemeData(
          color: p.textPrimary, linearTrackColor: p.border),
      tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(color: p.elevated, borderRadius: radiusMd),
          textStyle: p.caption(color: p.textPrimary)),
      snackBarTheme: SnackBarThemeData(
          backgroundColor: p.elevated,
          contentTextStyle: p.body(color: p.textPrimary),
          behavior: SnackBarBehavior.floating,
          shape: shape),
    );
  }
}

/// Context-scoped colors: multiple themes can coexist (e.g. a dark player
/// within the light app), without mutable global color state.
class SabuPalette {
  final bool isLight;
  const SabuPalette.light() : isLight = true;
  const SabuPalette.dark() : isLight = false;
  Color get background =>
      isLight ? const Color(0xFFFFFFFF) : SabuflixTheme.background;
  Color get surface =>
      isLight ? const Color(0xFFF7F7F7) : SabuflixTheme.surface;
  Color get surfaceLight =>
      isLight ? const Color(0xFFEEEEEE) : SabuflixTheme.surfaceLight;
  Color get elevated =>
      isLight ? const Color(0xFFFFFFFF) : SabuflixTheme.elevated;
  Color get border => isLight ? const Color(0xFFE2E2E2) : SabuflixTheme.border;
  Color get borderStrong =>
      isLight ? const Color(0xFF8A8A8A) : SabuflixTheme.borderStrong;
  Color get textPrimary =>
      isLight ? const Color(0xFF000000) : SabuflixTheme.textPrimary;
  Color get textSecondary =>
      isLight ? const Color(0xFF4A4A4A) : SabuflixTheme.textSecondary;
  Color get textMuted =>
      isLight ? const Color(0xFF626262) : SabuflixTheme.textMuted;
  Color get accent => isLight ? SabuflixTheme.brandBlue : SabuflixTheme.accent;
  Color get accentHover =>
      isLight ? const Color(0xFF0016C0) : SabuflixTheme.accentHover;
  Color get accentMuted => SabuflixTheme.accentMuted;
  Color get gold => isLight ? const Color(0xFF000000) : SabuflixTheme.gold;
  Color get success =>
      isLight ? const Color(0xFF18703A) : SabuflixTheme.success;
  Color get error =>
      isLight ? const Color(0xFFBA242B) : const Color(0xFFFF777D);
  Color get secondaryFill =>
      isLight ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A);
  TextStyle display({
    double fontSize = 40,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double height = 1.05,
    double letterSpacing = -1.4,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textPrimary,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle headline({
    double fontSize = 30,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double height = 1.1,
    double letterSpacing = -0.9,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textPrimary,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle title({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double height = 1.2,
    double letterSpacing = -0.5,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textPrimary,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle body({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double height = 1.45,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textSecondary,
      height: height,
      letterSpacing: -0.2,
    );
  }

  TextStyle label({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = 0.6,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textMuted,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle caption({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double letterSpacing = -0.25,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textSecondary,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle wordmark({double fontSize = 20, Color? color}) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color ?? textPrimary,
      letterSpacing: -1.0,
      height: 1.0,
    );
  }
}
