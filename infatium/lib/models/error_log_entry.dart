import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Error severity levels for error tracking
enum ErrorSeverity {
  /// Low priority - informational errors that don't affect functionality
  warning,

  /// Medium priority - errors that affect functionality but app can recover
  error,

  /// High priority - critical errors that crash the app or lose data
  fatal,
}

/// Error log entry model for structured error tracking
///
/// This model captures all context needed to diagnose and fix errors:
/// - Error details (type, message, stack trace)
/// - User context (user ID, session ID)
/// - Device context (platform, OS version, app version)
/// - App context (current route, user flow, breadcrumbs)
/// - HTTP context (endpoint, status code, method) for API errors
class ErrorLogEntry {
  /// Unique identifier for this error occurrence
  final String errorId;

  /// Error type (e.g., "Exception", "StateError", "HttpException")
  final String errorType;

  /// Human-readable error message
  final String errorMessage;

  /// Stack trace for debugging
  final String stackTrace;

  /// Fingerprint for error grouping (same fingerprint = same issue)
  final String fingerprint;

  /// When the error occurred
  final DateTime timestamp;

  /// User ID (if authenticated)
  final String? userId;

  /// Session ID for tracking user journey
  final String? sessionId;

  /// Platform (iOS, Android, Web, macOS, Windows, Linux)
  final String platform;

  /// App version (from pubspec.yaml)
  final String appVersion;

  /// App build number (from pubspec.yaml)
  final String appBuildNumber;

  /// OS version
  final String osVersion;

  /// Current route/screen when error occurred
  final String? currentRoute;

  /// Current user flow (e.g., "onboarding", "feed_creation", "chat")
  final String? currentFlow;

  /// Breadcrumbs - recent user actions leading to error
  final List<Map<String, dynamic>>? breadcrumbs;

  /// Extra context data for debugging
  final Map<String, dynamic>? extraContext;

  /// Error severity
  final ErrorSeverity severity;

  /// HTTP endpoint (for API errors)
  final String? httpEndpoint;

  /// HTTP status code (for API errors)
  final int? httpStatusCode;

  /// HTTP method (for API errors)
  final String? httpMethod;

  ErrorLogEntry({
    required this.errorId,
    required this.errorType,
    required this.errorMessage,
    required this.stackTrace,
    required this.fingerprint,
    required this.timestamp,
    required this.platform,
    required this.appVersion,
    required this.appBuildNumber,
    required this.osVersion,
    required this.severity,
    this.userId,
    this.sessionId,
    this.currentRoute,
    this.currentFlow,
    this.breadcrumbs,
    this.extraContext,
    this.httpEndpoint,
    this.httpStatusCode,
    this.httpMethod,
  });

  /// Convert to JSON for sending to GlitchTip
  Map<String, dynamic> toJson() {
    return {
      'error_id': errorId,
      'error_type': errorType,
      'error_message': errorMessage,
      'stack_trace': stackTrace,
      'fingerprint': fingerprint,
      'timestamp': timestamp.toUtc().toIso8601String(),
      if (userId != null) 'user_id': userId,
      if (sessionId != null) 'session_id': sessionId,
      'platform': platform,
      'app_version': appVersion,
      'app_build_number': appBuildNumber,
      'os_version': osVersion,
      if (currentRoute != null) 'current_route': currentRoute,
      if (currentFlow != null) 'current_flow': currentFlow,
      if (breadcrumbs != null) 'breadcrumbs': breadcrumbs,
      if (extraContext != null) 'extra_context': extraContext,
      'severity': severity.name,
      if (httpEndpoint != null) 'http_endpoint': httpEndpoint,
      if (httpStatusCode != null) 'http_status_code': httpStatusCode,
      if (httpMethod != null) 'http_method': httpMethod,
    };
  }

  /// Generate fingerprint for error grouping
  ///
  /// Errors with the same fingerprint are grouped together in GlitchTip.
  /// Uses error type + top 3 stack trace lines for uniqueness.
  static String generateFingerprint(String errorType, StackTrace? stack) {
    final stackLines = stack?.toString().split('\n').take(3).join('\n') ?? '';
    final raw = '$errorType|$stackLines';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 16);
  }
}
