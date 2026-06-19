import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/core/constants/app_constants.dart';

/// Parkir Boss ThemeData — neo-brutalist Material3 theme
/// built from the Stitch design tokens.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.bodyFamily,

      // ─── Color Scheme ───────────────────────────────────────
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        inversePrimary: AppColors.inversePrimary,
        surfaceTint: AppColors.surfaceTint,
      ),

      // ─── Scaffold ───────────────────────────────────────────
      scaffoldBackgroundColor: AppColors.background,

      // ─── Text Theme ─────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.onSurface),
        displayMedium: AppTypography.displayMedium.copyWith(color: AppColors.onSurface),
        displaySmall: AppTypography.displaySmall.copyWith(color: AppColors.onSurface),
        headlineLarge: AppTypography.headlineLarge.copyWith(color: AppColors.onSurface),
        headlineMedium: AppTypography.headlineMedium.copyWith(color: AppColors.onSurface),
        headlineSmall: AppTypography.headlineSmall.copyWith(color: AppColors.onSurface),
        titleLarge: AppTypography.titleLarge.copyWith(color: AppColors.onSurface),
        titleMedium: AppTypography.titleMedium.copyWith(color: AppColors.onSurface),
        titleSmall: AppTypography.titleSmall.copyWith(color: AppColors.onSurface),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.onSurface),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
        bodySmall: AppTypography.bodySmall.copyWith(color: AppColors.onSurface),
        labelLarge: AppTypography.labelLarge.copyWith(color: AppColors.onSurface),
        labelMedium: AppTypography.labelMedium.copyWith(color: AppColors.onSurface),
        labelSmall: AppTypography.labelSmall.copyWith(color: AppColors.onSurface),
      ),

      // ─── AppBar ─────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.onSurface,
        ),
      ),

      // ─── Elevated Button (Neo-Brutalist) ────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tertiary,
          foregroundColor: AppColors.onTertiary,
          textStyle: AppTypography.labelLarge.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            side: const BorderSide(
              color: AppColors.primary,
              width: AppSpacing.borderMedium,
            ),
          ),
          elevation: 0,
        ),
      ),

      // ─── Outlined Button ──────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          textStyle: AppTypography.labelLarge,
          side: const BorderSide(
            color: AppColors.primary,
            width: AppSpacing.borderThin,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          ),
        ),
      ),

      // ─── Card ─────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          side: const BorderSide(
            color: AppColors.primary,
            width: AppSpacing.borderMedium,
          ),
        ),
      ),

      // ─── Input Decoration ─────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: AppSpacing.borderMedium,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: AppSpacing.borderMedium,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          borderSide: const BorderSide(
            color: AppColors.tertiary,
            width: AppSpacing.borderMedium,
          ),
        ),
      ),

      // ─── Divider ──────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.primary,
        thickness: AppSpacing.borderMedium,
      ),
    );
  }
}
