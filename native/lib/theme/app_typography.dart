import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the app's type scale for a given [AppColors] set, so text colours
/// stay correct in both light and dark themes.
///
/// One corporate superfamily, bundled with the app (no network, no
/// platform-default substitution): IBM Plex Sans for UI/chrome, IBM Plex Mono
/// for machine data. Sans is a variable font whose weight axis is driven via
/// [FontVariation]; Mono ships as static weights. Monospace data uses tabular
/// (fixed-width) figures so numbers align in columns.
abstract final class AppTypography {
  static const String sansFamily = 'IBM Plex Sans';
  static const String monoFamily = 'IBM Plex Mono';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle _sans({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
    double? height,
    required Color color,
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      fontWeight: fontWeight,
      fontVariations: [FontVariation('wght', fontWeight.value.toDouble())],
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  static TextTheme textTheme(AppColors c) {
    return TextTheme(
      headlineSmall: _sans(
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: c.textPrimary,
      ),
      titleLarge: _sans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: c.textPrimary,
      ),
      titleMedium: _sans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: c.textPrimary,
      ),
      bodyLarge: _sans(fontSize: 14, height: 1.45, color: c.textPrimary),
      bodyMedium: _sans(fontSize: 13, height: 1.45, color: c.textSecondary),
      bodySmall: _sans(fontSize: 12, height: 1.35, color: c.textTertiary),
      labelLarge: _sans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: c.textPrimary,
      ),
      // Section captions — rendered UPPER CASE via SectionLabel, lightly tracked.
      labelMedium: _sans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: c.textTertiary,
      ),
      labelSmall: _sans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: c.textTertiary,
      ),
    );
  }

  /// Monospace style for machine data (IBM Plex Mono), with tabular figures.
  static TextStyle mono(
    AppColors c, {
    double fontSize = 13,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = 0.1,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontWeight: fontWeight,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      height: 1.35,
      color: color ?? c.textPrimary,
      fontFeatures: _tabular,
    );
  }
}

/// `context.mono(...)` convenience for machine-data text.
extension AppMonoX on BuildContext {
  TextStyle mono({
    double fontSize = 13,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
  }) =>
      AppTypography.mono(
        colors,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
}
