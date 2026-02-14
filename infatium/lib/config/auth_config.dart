/// Authentication configuration for custom auth-service.
///
/// This file provides configuration for the custom auth system.
/// Use --dart-define flags to control auth service URLs.
class AuthConfig {

  /// Base URL for custom auth-service.
  ///
  /// Can be overridden for staging/dev environments.
  ///
  /// Default: Production auth-service
  ///
  /// Usage:
  /// ```bash
  /// flutter run \
  ///   --dart-define=CUSTOM_AUTH_BASE_URL=https://staging.auth.example.com
  /// ```
  static const String customAuthBaseUrl = String.fromEnvironment(
    'CUSTOM_AUTH_BASE_URL',
    defaultValue: 'https://dev.api.infatium.ru/auth',
  );

  /// Error codes returned by custom auth-service.
  ///
  /// Used for error handling and user messaging.
  static const String errorMissingToken = 'missing_token';
  static const String errorInvalidToken = 'invalid_token';
  static const String errorTokenReused = 'token_reused';
  static const String errorSessionRevoked = 'session_revoked';
  static const String errorTokenExpired = 'token_expired';
  static const String errorRefreshTokenExpired = 'refresh_token_expired';
  static const String errorNetworkError = 'network_error';
  static const String errorUnknown = 'unknown_error';

  /// HTTP status codes for auth errors.
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusConflict = 409; // Token reused - security alert!

  /// Token refresh configuration.
  ///
  /// Custom auth-service issues access tokens with 15-minute lifetime.
  /// We refresh every 12 minutes (3 minutes before expiry) to provide a larger
  /// safety buffer and handle app backgrounding scenarios.
  ///
  /// Why 12 minutes?
  /// - Prevents token expiry if app is backgrounded for short periods
  /// - Provides 3-minute buffer (was 1 minute) before access token expires
  /// - Reduces risk of 401 errors on app resume
  static const Duration accessTokenLifetime = Duration(minutes: 15);
  static const Duration refreshInterval = Duration(minutes: 12);
  static const Duration refreshRetryDelay = Duration(seconds: 30);

  /// Deep link configuration for magic link authentication.
  ///
  /// Must match platform configurations:
  /// - iOS: ios/Runner/Info.plist CFBundleURLSchemes
  /// - Android: android/app/src/main/AndroidManifest.xml intent-filter
  static const String deepLinkScheme = 'makefeed';
  static const String deepLinkHost = 'auth';
  static const String deepLinkPath = 'callback';
  static const String deepLinkCallbackUrl = '$deepLinkScheme://$deepLinkHost/$deepLinkPath';

  /// HTTP timeout for auth-service requests.
  ///
  /// Matches ApiConfig timeout for consistency.
  static const Duration httpTimeout = Duration(seconds: 30);

  /// Password validation configuration.
  ///
  /// These rules apply to password sign-up and password reset flows.
  static const int minPasswordLength = 8;
  static const bool requireUppercase = true;
  static const bool requireLowercase = true;
  static const bool requireNumbers = true;
  static const bool requireSpecialChars = true;
  static const bool logSecurityEvents = true;

  /// Validate configuration on app startup.
  ///
  /// Throws [StateError] if configuration is invalid.
  static void validate() {
    if (customAuthBaseUrl.isEmpty) {
      throw StateError('CUSTOM_AUTH_BASE_URL must be set');
    }
    if (!customAuthBaseUrl.startsWith('https://') && !customAuthBaseUrl.startsWith('http://')) {
      throw StateError('CUSTOM_AUTH_BASE_URL must be a valid HTTP(S) URL: $customAuthBaseUrl');
    }
    print('✓ Auth Config: Using custom auth-service at $customAuthBaseUrl');
  }
}
