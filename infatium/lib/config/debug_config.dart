/// Configuration for debug features.
///
/// These settings control debug-only functionality like remote logging
/// and development tools.
library;

/// Debug feature configuration.
class DebugConfig {
  /// Whether debug logging to /debug/echo is enabled.
  ///
  /// When enabled, all app logs (print statements) are sent to the debug
  /// endpoint for remote monitoring and debugging.
  ///
  /// **Configuration**:
  /// - Set via `ENABLE_DEBUG_LOGGING` environment variable
  /// - Default: `false` (disabled in production)
  /// - Dev environment: typically `true`
  /// - Prod environment: always `false`
  ///
  /// **Usage**:
  /// ```dart
  /// if (kDebugMode || DebugConfig.enableDebugLogging) {
  ///   // Enable debug features
  /// }
  /// ```
  ///
  /// **Note**: This works independently of Flutter build mode (debug/release).
  /// Dev release builds can have debug logging enabled, while prod release
  /// builds have it disabled.
  static const bool enableDebugLogging = String.fromEnvironment(
    'ENABLE_DEBUG_LOGGING',
    defaultValue: 'false',
  ) == 'true';
}
