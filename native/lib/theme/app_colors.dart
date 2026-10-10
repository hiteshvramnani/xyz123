import 'package:flutter/material.dart';

/// Raw palette. These are the only literal colours in the app; everything
/// else references semantic roles on [AppColors]. A red / black / white
/// identity: near-black or near-white neutrals, a single confident red accent,
/// with green reserved only for positive confirmation.
abstract final class _Palette {
  // Dark neutrals (black)
  static const k0 = Color(0xFF0A0A0B); // page
  static const k1 = Color(0xFF141416); // surface / app bar / cards
  static const k2 = Color(0xFF1D1D20); // raised / inset
  static const kField = Color(0xFF161618);
  static const kLine = Color(0xFF2A2A2E);
  static const kLine2 = Color(0xFF3A3A40);
  static const kText = Color(0xFFF4F4F5);
  static const kText2 = Color(0xFFA1A1AA);
  static const kText3 = Color(0xFF71717A);
  static const kHint = Color(0xFF52525B);

  // Light neutrals (white)
  static const w0 = Color(0xFFF7F7F8);
  static const white = Color(0xFFFFFFFF);
  static const w2 = Color(0xFFF3F3F4);
  static const wLine = Color(0xFFE4E4E7);
  static const wLine2 = Color(0xFFC9C9CF);
  static const wText = Color(0xFF0A0A0B);
  static const wText2 = Color(0xFF52525B);
  static const wText3 = Color(0xFF71717A);
  static const wHint = Color(0xFFA1A1AA);

  // Red accent
  static const red = Color(0xFFDC2626); // primary fill (both modes)
  static const redOnDark = Color(0xFFF87171); // accent on dark surfaces
  static const redOnLight = Color(0xFFB91C1C); // accent on light surfaces
  static const redBright = Color(0xFFEF4444); // error on dark
  static const red300 = Color(0xFFFCA5A5);
  static const red700 = Color(0xFFB91C1C);
  static const redBgLight = Color(0xFFFDE4E4);
  static const whiteOn = Color(0xFFFFFFFF);

  // Green — positive confirmation only
  static const green = Color(0xFF22C55E);
  static const greenDark = Color(0xFF16A34A);
  static const greenBgLight = Color(0xFFDCFCE7);
}

/// Semantic colour roles, provided as a [ThemeExtension] so a single
/// `context.colors.<role>` works across the light and dark themes.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.fieldFill,
    required this.chipBg,
    required this.outline,
    required this.outlineStrong,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.primarySubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textHint,
    required this.success,
    required this.successSubtleBg,
    required this.danger,
    required this.dangerText,
    required this.dangerSubtleBg,
    required this.dangerBorder,
    required this.scrim,
    required this.brightness,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color fieldFill;
  final Color chipBg;
  final Color outline;
  final Color outlineStrong;

  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color primarySubtle;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textHint;

  final Color success;
  final Color successSubtleBg;

  final Color danger;
  final Color dangerText;
  final Color dangerSubtleBg;
  final Color dangerBorder;

  final Color scrim;

  /// Brightness this role set belongs to — handy for conditional affordances.
  final Brightness brightness;

  static const AppColors dark = AppColors(
    background: _Palette.k0,
    surface: _Palette.k1,
    surfaceVariant: _Palette.k2,
    fieldFill: _Palette.kField,
    chipBg: _Palette.k2,
    outline: _Palette.kLine,
    outlineStrong: _Palette.kLine2,
    primary: _Palette.red,
    onPrimary: _Palette.whiteOn,
    accent: _Palette.redOnDark,
    primarySubtle: Color(0x29DC2626), // red @ ~16%
    textPrimary: _Palette.kText,
    textSecondary: _Palette.kText2,
    textTertiary: _Palette.kText3,
    textHint: _Palette.kHint,
    success: _Palette.green,
    successSubtleBg: Color(0x2622C55E),
    danger: _Palette.redBright,
    dangerText: _Palette.red300,
    dangerSubtleBg: Color(0x33EF4444), // red @ 20%
    dangerBorder: Color(0x66EF4444), // red @ 40%
    scrim: Color(0x99000000),
    brightness: Brightness.dark,
  );

  static const AppColors light = AppColors(
    background: _Palette.w0,
    surface: _Palette.white,
    surfaceVariant: _Palette.w2,
    fieldFill: _Palette.white,
    chipBg: _Palette.w2,
    outline: _Palette.wLine,
    outlineStrong: _Palette.wLine2,
    primary: _Palette.red,
    onPrimary: _Palette.whiteOn,
    accent: _Palette.redOnLight,
    primarySubtle: Color(0x14DC2626), // red @ ~8%
    textPrimary: _Palette.wText,
    textSecondary: _Palette.wText2,
    textTertiary: _Palette.wText3,
    textHint: _Palette.wHint,
    success: _Palette.greenDark,
    successSubtleBg: _Palette.greenBgLight,
    danger: _Palette.red,
    dangerText: _Palette.red700,
    dangerSubtleBg: _Palette.redBgLight,
    dangerBorder: _Palette.red300,
    scrim: Color(0x40000000),
    brightness: Brightness.light,
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? fieldFill,
    Color? chipBg,
    Color? outline,
    Color? outlineStrong,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? primarySubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textHint,
    Color? success,
    Color? successSubtleBg,
    Color? danger,
    Color? dangerText,
    Color? dangerSubtleBg,
    Color? dangerBorder,
    Color? scrim,
    Brightness? brightness,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      fieldFill: fieldFill ?? this.fieldFill,
      chipBg: chipBg ?? this.chipBg,
      outline: outline ?? this.outline,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      primarySubtle: primarySubtle ?? this.primarySubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textHint: textHint ?? this.textHint,
      success: success ?? this.success,
      successSubtleBg: successSubtleBg ?? this.successSubtleBg,
      danger: danger ?? this.danger,
      dangerText: dangerText ?? this.dangerText,
      dangerSubtleBg: dangerSubtleBg ?? this.dangerSubtleBg,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      scrim: scrim ?? this.scrim,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      fieldFill: Color.lerp(fieldFill, other.fieldFill, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      primarySubtle: Color.lerp(primarySubtle, other.primarySubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSubtleBg: Color.lerp(successSubtleBg, other.successSubtleBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      dangerSubtleBg: Color.lerp(dangerSubtleBg, other.dangerSubtleBg, t)!,
      dangerBorder: Color.lerp(dangerBorder, other.dangerBorder, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}

/// Ergonomic access: `context.colors.primary`.
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}
