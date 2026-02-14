/// AppMetrica analytics configuration
///
/// This file centralizes all AppMetrica SDK settings including API key,
/// session timeout, crash reporting, and privacy controls.
///
/// **Security:** API key is loaded via --dart-define to prevent hardcoding secrets.
///
/// Example usage:
/// ```bash
/// flutter run --dart-define=APPMETRICA_API_KEY=your_key_here
/// ```
class AppMetricaSettings {
  /// AppMetrica API Key from https://appmetrica.yandex.com/
  ///
  /// **REQUIRED:** Must be provided via --dart-define for all builds.
  ///
  /// Get from: Application Settings → API Key in AppMetrica dashboard
  ///
  /// **Security:** NO default value to prevent accidental exposure.
  static const String apiKey = String.fromEnvironment(
    'APPMETRICA_API_KEY',
    defaultValue: '',
  );

  /// Session timeout (seconds) - time between events before new session starts
  ///
  /// Default: 10 seconds (AppMetrica recommended for mobile apps)
  static const int sessionTimeout = 10;

  /// Enable automatic crash reporting
  ///
  /// Captures unhandled exceptions and native crashes for debugging.
  /// Default: true (helps identify production issues)
  static const bool crashReporting = true;

  /// Enable location tracking
  ///
  /// Default: false (disabled for GDPR/privacy compliance)
  /// Only enable if explicitly required and user consented.
  static const bool locationTracking = false;

  /// Maximum cached events before forced upload
  ///
  /// 0 = unlimited (recommended for offline-first apps)
  /// AppMetrica handles automatic flushing when connectivity restored.
  static const int maxReportsInDatabase = 1000;

  /// Enable AppMetrica SDK logging for debugging
  ///
  /// Default: false (disable in production to reduce log noise)
  static const bool logs = false;

  /// Validate required configuration
  ///
  /// Throws exception if API key is missing.
  /// Call during app initialization to fail fast on misconfiguration.
  static void validate() {
    if (apiKey.isEmpty) {
      throw Exception(
        'APPMETRICA_API_KEY is required. '
        'Pass via: --dart-define=APPMETRICA_API_KEY=your_key\n'
        'Get your API key from: https://appmetrica.yandex.com/ → '
        'Application Settings → API Key',
      );
    }
  }
}
