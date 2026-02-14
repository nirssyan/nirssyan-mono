import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/error_log_entry.dart';
import 'auth_service.dart';

/// Centralized error logging service using GlitchTip (Sentry-compatible)
///
/// Features:
/// - Automatic error capturing with context (breadcrumbs, user info, device info)
/// - HTTP error tracking with endpoint/status code/method
/// - Rate limiting to prevent error flooding
/// - Deduplication to avoid sending duplicate errors
/// - Privacy filtering (no PII in error reports)
/// - User context from AuthService
class ErrorLoggingService extends ChangeNotifier {
  static final ErrorLoggingService _instance = ErrorLoggingService._internal();
  factory ErrorLoggingService() => _instance;
  ErrorLoggingService._internal();

  /// Breadcrumbs - recent user actions leading to errors
  final List<Map<String, dynamic>> _breadcrumbs = [];
  static const int maxBreadcrumbs = 10;

  /// Current route/screen
  String? _currentRoute;

  /// Rate limiting
  int _errorCount = 0;
  DateTime? _errorCountResetTime;
  static const int maxErrorsPerMinute = 50;

  /// Recent fingerprints cache (deduplication)
  final Set<String> _recentFingerprints = {};

  /// Initialize the error logging service
  ///
  /// Call this during app startup to:
  /// - Set up user context from AuthService
  Future<void> initialize() async {
    // Set user context from AuthService
    AuthService().addListener(_updateUserContext);
    _updateUserContext();

    if (kDebugMode) {
      // ignore: avoid_print
      print('Makefeed: ErrorLoggingService initialized');
    }
  }

  /// Update user context in Sentry when auth state changes
  void _updateUserContext() {
    final user = AuthService().currentUser;
    if (user != null) {
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(
          id: user.id,
          // GDPR: Don't send email directly, use hash
          // ignore: deprecated_member_use
          extras: {
            'email_hash': user.email.hashCode.toString(),
          },
        ));
      });

      if (kDebugMode) {
        // ignore: avoid_print
        print('Makefeed: User context updated in Sentry (user_id: ${user.id})');
      }
    } else {
      // Clear user context on logout
      Sentry.configureScope((scope) => scope.setUser(null));
    }
  }

  /// Set current route/screen
  ///
  /// Call this when navigating to a new screen to add context to errors.
  void setCurrentRoute(String route) {
    _currentRoute = route;

    // Update Sentry transaction name
    Sentry.configureScope((scope) {
      scope.setTag('route', route);
    });
  }

  /// Add breadcrumb - user action for error context
  ///
  /// Breadcrumbs are like a trail of breadcrumbs showing what the user did
  /// leading up to an error. They help reproduce and fix bugs.
  ///
  /// Example:
  /// ```dart
  /// ErrorLoggingService().addBreadcrumb(
  ///   'send_message',
  ///   'chat_page',
  ///   data: {'chat_id': chatId, 'message_length': 123},
  /// );
  /// ```
  void addBreadcrumb(String action, String screen, {Map<String, dynamic>? data}) {
    _breadcrumbs.add({
      'action': action,
      'screen': screen,
      'timestamp': DateTime.now().toIso8601String(),
      if (data != null) 'data': data,
    });

    // Keep only recent breadcrumbs
    if (_breadcrumbs.length > maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }

    // Add to Sentry
    Sentry.addBreadcrumb(Breadcrumb(
      message: '[$screen] $action',
      level: SentryLevel.info,
      data: data,
    ));

    if (kDebugMode) {
      // ignore: avoid_print
      print('Makefeed: Breadcrumb added - [$screen] $action');
    }
  }

  /// Capture exception with full context
  ///
  /// This is the main method for logging errors. It captures:
  /// - Error object and stack trace
  /// - User context (user ID, session ID)
  /// - Device context (platform, OS version, app version)
  /// - App context (current route, breadcrumbs)
  /// - Extra data for debugging
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await fetchData();
  /// } catch (e, stack) {
  ///   await ErrorLoggingService().captureException(
  ///     e,
  ///     stack,
  ///     context: 'news_fetch',
  ///     extraData: {'feed_id': feedId},
  ///     severity: ErrorSeverity.error,
  ///   );
  ///   rethrow;
  /// }
  /// ```
  Future<void> captureException(
    Object error,
    StackTrace? stack, {
    String? context,
    Map<String, dynamic>? extraData,
    ErrorSeverity severity = ErrorSeverity.error,
    bool fatal = false,
  }) async {
    // Rate limiting
    if (!_shouldCaptureError()) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ErrorLoggingService] Rate limit exceeded, skipping error');
      }
      return;
    }

    try {
      // Generate fingerprint for deduplication
      final fingerprint = ErrorLogEntry.generateFingerprint(
        error.runtimeType.toString(),
        stack,
      );

      // Skip if duplicate
      if (_isDuplicate(fingerprint)) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[ErrorLoggingService] Duplicate error, skipping');
        }
        return;
      }

      // Build Sentry event
      final sentryLevel = _severityToSentryLevel(severity);

      // Send to GlitchTip via Sentry
      await Sentry.captureException(
        error,
        stackTrace: stack,
        hint: Hint.withMap({
          'context': context,
          'route': _currentRoute,
          'breadcrumbs': _breadcrumbs,
          if (extraData != null) 'extra': extraData,
        }),
        withScope: (scope) {
          scope.level = sentryLevel;
          scope.fingerprint = [fingerprint];

          if (context != null) {
            scope.setTag('context', context);
          }

          if (_currentRoute != null) {
            scope.setTag('route', _currentRoute!);
          }

          if (extraData != null) {
            scope.setContexts('extra', extraData);
          }

          // Add breadcrumbs
          for (final breadcrumb in _breadcrumbs) {
            scope.addBreadcrumb(Breadcrumb(
              message: '[${breadcrumb['screen']}] ${breadcrumb['action']}',
              timestamp: DateTime.parse(breadcrumb['timestamp'] as String),
              data: breadcrumb['data'] as Map<String, dynamic>?,
            ));
          }
        },
      );

      if (kDebugMode) {
        // ignore: avoid_print
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        // ignore: avoid_print
        print('[ErrorLoggingService] Captured ${severity.name}');
        // ignore: avoid_print
        print('Error: $error');
        // ignore: avoid_print
        print('Context: $context');
        // ignore: avoid_print
        print('Route: $_currentRoute');
        // ignore: avoid_print
        if (extraData != null) print('Extra: $extraData');
        // ignore: avoid_print
        print('Fingerprint: $fingerprint');
        // ignore: avoid_print
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
    } catch (e) {
      // Silent fail - don't want error logging to crash the app
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ErrorLoggingService] Failed to capture error: $e');
      }
    }
  }

  /// Capture HTTP error with endpoint/status code/method
  ///
  /// Use this for API errors to get better context in GlitchTip.
  ///
  /// Example:
  /// ```dart
  /// if (response.statusCode >= 400) {
  ///   await ErrorLoggingService().captureHttpError(
  ///     endpoint: '/api/chats',
  ///     statusCode: 500,
  ///     method: 'POST',
  ///     errorMessage: response.body,
  ///     service: 'chat',
  ///   );
  /// }
  /// ```
  Future<void> captureHttpError({
    required String endpoint,
    required int statusCode,
    required String method,
    String? errorMessage,
    String? service,
  }) async {
    final errorMsg = errorMessage ?? '';
    final error = HttpException(
      'HTTP $statusCode: $method $endpoint $errorMsg',
    );

    await captureException(
      error,
      StackTrace.current,
      context: service ?? 'http',
      extraData: {
        'endpoint': endpoint,
        'status_code': statusCode,
        'method': method,
        if (errorMessage != null) 'error_message': errorMessage,
      },
      severity: statusCode >= 500 ? ErrorSeverity.error : ErrorSeverity.warning,
    );
  }

  /// Check if we should capture this error (rate limiting)
  bool _shouldCaptureError() {
    final now = DateTime.now();

    // Reset counter every minute
    if (_errorCountResetTime == null ||
        now.difference(_errorCountResetTime!) > const Duration(minutes: 1)) {
      _errorCount = 0;
      _errorCountResetTime = now;
    }

    _errorCount++;
    return _errorCount <= maxErrorsPerMinute;
  }

  /// Check if this error is a duplicate (deduplication)
  bool _isDuplicate(String fingerprint) {
    if (_recentFingerprints.contains(fingerprint)) {
      return true;
    }

    _recentFingerprints.add(fingerprint);

    // Clear cache if too large
    if (_recentFingerprints.length > 100) {
      _recentFingerprints.clear();
    }

    return false;
  }

  /// Convert ErrorSeverity to Sentry level
  SentryLevel _severityToSentryLevel(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.warning:
        return SentryLevel.warning;
      case ErrorSeverity.error:
        return SentryLevel.error;
      case ErrorSeverity.fatal:
        return SentryLevel.fatal;
    }
  }

  @override
  void dispose() {
    AuthService().removeListener(_updateUserContext);
    super.dispose();
  }
}
