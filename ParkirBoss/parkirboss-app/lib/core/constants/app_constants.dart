/// Spacing & layout constants from the Stitch design system.
/// Neo-brutalist: thick borders, sharp corners, bold shadows.
class AppSpacing {
  AppSpacing._();

  // ─── Spacing Scale ────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  static const double margin = 20.0;
  static const double gutter = 16.0;

  // ─── Border Widths (Neo-Brutalist) ────────────────────────
  static const double borderThin = 2.0;
  static const double borderMedium = 4.0;
  static const double borderThick = 6.0;

  // ─── Border Radius (Stitch: very small / sharp) ──────────
  static const double radiusNone = 0.0;
  static const double radiusXs = 2.0;   // DEFAULT in Stitch
  static const double radiusSm = 4.0;   // lg in Stitch
  static const double radiusMd = 8.0;   // xl in Stitch
  static const double radiusLg = 12.0;  // full in Stitch

  // ─── Shadow Offsets (Neo-Brutalist Drop Shadows) ──────────
  static const double shadowSmall = 4.0;
  static const double shadowMedium = 6.0;
  static const double shadowLarge = 8.0;
}

/// Image asset paths.
class AppAssets {
  AppAssets._();

  static const String onboardingCamera = 'assets/images/onboarding_camera.png';
}

/// API configuration constants.
///
/// NOTE: the live backend base URL used for network calls is `ApiClient.baseUrl`
/// (configurable via --dart-define=API_BASE_URL). The value below mirrors that
/// single source so the two no longer conflict.
class AppApi {
  AppApi._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );
  static const Duration timeout = Duration(seconds: 30);
}
