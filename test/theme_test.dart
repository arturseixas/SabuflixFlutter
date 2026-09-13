import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/theme/sabuflix_theme.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
}

void main() {
  for (final palette in [const SabuPalette.light(), const SabuPalette.dark()]) {
    test(
        'text contrast and action identity in ${palette.isLight ? 'light' : 'dark'}',
        () {
      for (final surface in [
        palette.background,
        palette.surface,
        palette.surfaceLight
      ]) {
        for (final text in [
          palette.textPrimary,
          palette.textSecondary,
          palette.textMuted
        ]) {
          expect(contrast(text, surface), greaterThanOrEqualTo(4.5));
        }
      }
      expect(contrast(Colors.white, SabuflixTheme.brandBlue),
          greaterThanOrEqualTo(4.5));
      final theme = palette.isLight
          ? SabuflixTheme.lightThemeData
          : SabuflixTheme.themeData;
      final primary = theme.elevatedButtonTheme.style!;
      final secondary = theme.outlinedButtonTheme.style!;
      expect(primary.backgroundColor!.resolve({}), SabuflixTheme.brandBlue);
      expect(primary.foregroundColor!.resolve({}), Colors.white);
      expect(secondary.foregroundColor!.resolve({}), palette.textPrimary);
      expect(primary.shape!.resolve({}), secondary.shape!.resolve({}));
      expect(primary.minimumSize!.resolve({})!.height, 52);
      expect(secondary.minimumSize!.resolve({})!.height, 52);
    });
  }
}
