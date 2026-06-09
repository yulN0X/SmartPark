import 'package:flutter/material.dart';

/// Typography tokens from the Stitch "Parkir Boss" design system.
/// Headlines/Labels: Space Grotesk (bold, industrial)
/// Body: Inter (clean, readable)
class AppTypography {
  AppTypography._();

  // ─── Font Families ────────────────────────────────────────
  static const String headlineFamily = 'SpaceGrotesk';
  static const String displayFamily = 'SpaceGrotesk';
  static const String bodyFamily = 'Inter';
  static const String labelFamily = 'SpaceGrotesk';

  // ─── Display ──────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFamily,
    fontSize: 48,
    fontWeight: FontWeight.w900,
    height: 1.0,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: displayFamily,
    fontSize: 40,
    fontWeight: FontWeight.w900,
    height: 1.1,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: displayFamily,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );

  // ─── Headline ─────────────────────────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: headlineFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: headlineFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: headlineFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  // ─── Title ────────────────────────────────────────────────
  static const TextStyle titleLarge = TextStyle(
    fontFamily: headlineFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: headlineFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.15,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: headlineFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.1,
  );

  // ─── Body ─────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // ─── Label ────────────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: labelFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 1.6, // 0.1em of 16px
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: labelFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0.7, // 0.05em of 14px
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: labelFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0.6, // 0.05em of 12px
  );
}
