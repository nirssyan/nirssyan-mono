import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app.dart';
import 'config/notification_config.dart';
import 'config/glitchtip_config.dart';
import 'config/debug_config.dart';
import 'services/debug_log_service.dart';

void main() async {
  // Enable debug logging in debug mode OR if explicitly enabled in config
  if (kDebugMode || DebugConfig.enableDebugLogging) {
    DebugLogService().startCapturingLogs(_initializeApp);
  } else {
    _initializeApp();
  }
}

/// Initialize app with error tracking and Firebase.
void _initializeApp() async {
  // Initialize Sentry (GlitchTip-compatible) for error tracking
  await SentryFlutter.init(
    (options) {
      // GlitchTip DSN (Sentry-compatible)
      options.dsn = GlitchTipConfig.dsn;

      // Environment
      options.environment = kDebugMode ? 'development' : 'production';

      // Performance monitoring (10% sampling in production)
      options.tracesSampleRate = kDebugMode ? 1.0 : 0.1;

      // Performance profiling (experimental)
      // ignore: experimental_member_use
      options.profilesSampleRate = kDebugMode ? 1.0 : 0.1;

      // GDPR: Don't send PII automatically
      options.sendDefaultPii = false;

      // Get app version for release tracking
      PackageInfo.fromPlatform().then((packageInfo) {
        options.release = 'makefeed@${packageInfo.version}+${packageInfo.buildNumber}';
      });

      // Privacy filter: Remove sensitive data before sending
      options.beforeSend = (event, hint) {
        final message = event.message;
        final formatted = message?.formatted;
        if (formatted != null) {
          final sanitized = _sanitizeMessage(formatted);
          // ignore: deprecated_member_use
          event = event.copyWith(
            message: SentryMessage(sanitized),
          );
        }
        return event;
      };

      if (kDebugMode && GlitchTipConfig.isEnabled) {
        // ignore: avoid_print
        print('Makefeed: GlitchTip error tracking enabled');
        // ignore: avoid_print
        print('Makefeed: Dashboard at ${GlitchTipConfig.dashboardUrl}');
      }

      if (kDebugMode) {
        // ignore: avoid_print
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        // ignore: avoid_print
        print('📋 Debug Logging: ENABLED');
        // ignore: avoid_print
        print('📋 All app logs → POST ${DebugLogService().debugUrl}');
        // ignore: avoid_print
        print('📋 Batch size: 100 logs or every 5 seconds');
        // ignore: avoid_print
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Firebase for push notifications
      if (NotificationConfig.enableNotifications) {
        try {
          await Firebase.initializeApp();
        } catch (e) {
          if (kDebugMode) {
            print('Makefeed: Firebase initialization error: $e');
          }
        }
      }

      // Capture Flutter framework errors
      FlutterError.onError = (errorDetails) {
        if (kDebugMode) {
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('Makefeed: Flutter Error Captured');
          print('Error: ${errorDetails.exception}');
          print('Stack: ${errorDetails.stack}');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        }

        Sentry.captureException(
          errorDetails.exception,
          stackTrace: errorDetails.stack,
        );
      };

      // Capture platform errors (async errors not caught by Flutter)
      PlatformDispatcher.instance.onError = (error, stack) {
        if (kDebugMode) {
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('Makefeed: Platform Error Captured');
          print('Error: $error');
          print('Stack: $stack');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        }

        Sentry.captureException(error, stackTrace: stack);
        return true;
      };

      runApp(const MyApp());
    },
  );
}

/// Sanitize error messages to remove sensitive data (GDPR compliance)
String _sanitizeMessage(String message) {
  return message
      // Remove API keys
      .replaceAll(RegExp(r'API_KEY=[a-zA-Z0-9]+'), 'API_KEY=***')
      .replaceAll(RegExp(r'api[_-]?key["\s:=]+[a-zA-Z0-9]+', caseSensitive: false), 'api_key=***')
      // Remove JWT tokens
      .replaceAll(RegExp(r'Bearer [a-zA-Z0-9._-]+'), 'Bearer ***')
      .replaceAll(RegExp(r'eyJ[a-zA-Z0-9._-]+'), '***')
      // Remove email addresses
      .replaceAll(RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'), '***@***.***')
      // Remove refresh tokens
      .replaceAll(RegExp(r'rt_[a-zA-Z0-9]+'), 'rt_***')
      // Remove phone numbers (basic pattern)
      .replaceAll(RegExp(r'\+?\d{10,15}'), '***PHONE***');
}
