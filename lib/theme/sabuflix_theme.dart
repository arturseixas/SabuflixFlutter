import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SabuflixTheme {
  // Anthropic / Claude Warm Dark Color Palette
  static const Color background = Color(0xFF181614);
  static const Color surface = Color(0xFF23201D);
  static const Color surfaceLight = Color(0xFF2D2925);
  static const Color border = Color(0xFF38332E);
  static const Color terracotta = Color(0xFFE07A5F);
  static const Color terracottaHover = Color(0xFFEB8A70);
  static const Color amber = Color(0xFFD97706);
  static const Color textPrimary = Color(0xFFF5F5F4);
  static const Color textSecondary = Color(0xFFA8A29E);
  static const Color textMuted = Color(0xFF78716C);

  static TextStyle serifHeader({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.bold,
    Color color = textPrimary,
    double height = 1.15,
  }) {
    return GoogleFonts.dmSerifDisplay(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle sansBody({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textSecondary,
    double height = 1.4,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static ThemeData get themeData {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: terracotta,
      colorScheme: const ColorScheme.dark(
        primary: terracotta,
        secondary: terracotta,
        surface: surface,
        background: background,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
      ),
    );
  }
}
