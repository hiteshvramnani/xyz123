import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the light and dark [ThemeData] from the semantic [AppColors] tokens.
/// Every component theme is driven from these tokens so screens can rely on
/// `Theme.of(context)` instead of restyling each widget by hand.
abstract final class AppTheme {
  static ThemeData get dark => _build(AppColors.dark);
  static ThemeData get light => _build(AppColors.light);

  static ThemeData _build(AppColors c) {
    final isDark = c.brightness == Brightness.dark;
    final text = AppTypography.textTheme(c);

    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.accent,
      onSecondary: c.onPrimary,
      tertiary: c.success,
      onTertiary: c.onPrimary,
      error: c.danger,
      onError: const Color(0xFFFFFFFF),
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.outline,
      outlineVariant: c.outlineStrong,
      surfaceContainerHighest: c.surfaceVariant,
      scrim: c.scrim,
    );

    final statusBarStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: c.surface,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: c.surface,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: AppTypography.sansFamily,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[c],
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: c.textSecondary),
        actionsIconTheme: IconThemeData(color: c.textSecondary),
        systemOverlayStyle: statusBarStyle,
        shape: Border(bottom: BorderSide(color: c.outline)),
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.brMd,
          side: BorderSide(color: c.outline),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.fieldFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: c.textHint),
        labelStyle: text.labelMedium,
        floatingLabelStyle: text.labelMedium?.copyWith(color: c.primary),
        prefixIconColor: c.textTertiary,
        suffixIconColor: c.textTertiary,
        border: OutlineInputBorder(
          borderRadius: AppRadii.brMd,
          borderSide: BorderSide(color: c.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.brMd,
          borderSide: BorderSide(color: c.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.brMd,
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.brMd,
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.brMd,
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.primary.withValues(alpha: 0.35),
          disabledForegroundColor: c.onPrimary.withValues(alpha: 0.7),
          elevation: 0,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: text.labelLarge?.copyWith(color: c.onPrimary),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.brMd),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          side: BorderSide(color: c.outlineStrong),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: text.labelLarge?.copyWith(color: c.textPrimary),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.brMd),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: text.labelLarge?.copyWith(color: c.primary),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.brSm),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textSecondary,
          minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 2,
        extendedTextStyle: text.labelLarge?.copyWith(color: c.onPrimary),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
        showDragHandle: true,
        dragHandleColor: c.outlineStrong,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.brLg,
          side: BorderSide(color: c.outline),
        ),
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceVariant,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.brSm),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.primary.withValues(alpha: 0.4)
              : c.surfaceVariant,
        ),
        trackOutlineColor: WidgetStateProperty.all(c.outlineStrong),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
      ),

      dividerTheme: DividerThemeData(
        color: c.outline,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceVariant,
        labelStyle: text.labelSmall,
        side: BorderSide(color: c.outline),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.brSm),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
      ),
    );
  }
}
