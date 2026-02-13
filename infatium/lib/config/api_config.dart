/// Centralized API configuration using compile-time constants.
///
/// All API keys and endpoints are loaded from environment variables
/// via --dart-define flags during build time. This prevents hardcoding
/// sensitive credentials in source code.
///
/// Example build command:
/// ```bash
/// flutter build apk --release \
///   --dart-define=API_KEY=your_api_key \
///   --dart-define=API_BASE_URL=https://api.example.com
/// ```
class ApiConfig {
  // ==================== PUBLIC ENDPOINTS (can have defaults) ====================

  /// Base URL for makefeed backend API.
  ///
  /// This is a public URL and can have a default value.
  /// Override via --dart-define=API_BASE_URL=<your_url> for different environments.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dev.api.infatium.ru',
  );

  // ==================== SECRET KEYS (MUST be provided, no defaults!) ====================

  /// n8n webhook API key for backend communication.
  ///
  /// ⚠️ CRITICAL SECURITY: This is a secret API key!
  /// MUST be provided via --dart-define=API_KEY=<your_key>
  /// NO default value to prevent accidental exposure.
  ///
  /// Required for all API requests to makefeed backend.
  /// Get this from your n8n webhook configuration.
  ///
  /// Build command example:
  /// flutter run --dart-define=API_KEY=your_actual_key
  static const String apiKey = String.fromEnvironment('API_KEY');

  /// Request timeout duration for API calls.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Validates that all required SECRET KEYS are provided.
  ///
  /// Public URLs (baseUrl) have defaults and don't need validation.
  /// Only validates critical secrets that MUST be provided.
  ///
  /// Throws [ConfigurationException] if required secrets are missing.
  /// Call this during app initialization to fail fast.
  static void validate() {
    final errors = <String>[];

    // Only validate SECRET KEYS (no defaults for security)
    if (apiKey.isEmpty) {
      errors.add(
        '⚠️ API_KEY is required!\n'
        '   Set via: --dart-define=API_KEY=your_actual_key\n'
        '   Get from: n8n webhook configuration',
      );
    }

    if (errors.isNotEmpty) {
      throw ConfigurationException(
        '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
        '  CRITICAL: Missing required SECRET KEYS!\n'
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n'
        '${errors.join('\n\n')}\n\n'
        'Public URLs (API_BASE_URL) are optional.\n'
        'Analytics (Matomo) configured in lib/config/matomo_config.dart.\n'
        'See .env.example for full configuration details.\n'
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n',
      );
    }
  }

  /// Returns common headers for API requests.
  ///
  /// Includes API key and content type.
  /// Add user-specific headers (user-id, Authorization) separately.
  static Map<String, String> get commonHeaders => {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      };
}

/// Exception thrown when required configuration is missing.
class ConfigurationException implements Exception {
  final String message;
  ConfigurationException(this.message);

  @override
  String toString() => 'ConfigurationException: $message';
}
