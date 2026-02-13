/// Log level enum following standard 5-level severity model
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical;

  /// Check if this level is at least as severe as [other]
  bool isAtLeast(LogLevel other) {
    return index >= other.index;
  }

  /// Get uppercase string representation for log output
  String get displayName => name.toUpperCase();
}
