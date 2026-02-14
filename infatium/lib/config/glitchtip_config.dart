/// GlitchTip Error Tracking Configuration
///
/// This file configures the connection to our self-hosted GlitchTip instance
/// for error tracking and monitoring.
///
/// GlitchTip is Sentry-compatible, so we use the sentry_flutter SDK.
class GlitchTipConfig {
  /// GlitchTip DSN (Data Source Name) for sending error reports
  ///
  /// This is loaded from environment variables via --dart-define-from-file
  /// Production DSN: https://f3a86334caf4467da51f2f4d60ae7186@glitchtip.infra.makekod.ru/1
  static const String dsn = String.fromEnvironment(
    'GLITCHTIP_DSN',
    defaultValue: '',
  );

  /// GlitchTip Dashboard URL for viewing errors
  static const String dashboardUrl = 'https://glitchtip.infra.makekod.ru';

  /// Validate that GlitchTip is properly configured
  ///
  /// Throws an exception if DSN is missing or invalid.
  /// Call this during app initialization to fail fast on misconfiguration.
  static void validate() {
    if (dsn.isEmpty) {
      throw Exception(
        'GLITCHTIP_DSN is not configured. '
        'Add it to your config/*.local.json file.',
      );
    }

    if (!dsn.contains('glitchtip.infra.makekod.ru')) {
      throw Exception(
        'Invalid GLITCHTIP_DSN: must point to glitchtip.infra.makekod.ru. '
        'Current DSN: $dsn',
      );
    }
  }

  /// Whether error tracking is enabled
  ///
  /// Returns false if DSN is not configured (e.g., in local development without config)
  static bool get isEnabled => dsn.isNotEmpty;
}
