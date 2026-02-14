import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/log_level.dart';
import '../models/log_entry.dart';

/// Centralized logging service with console output
///
/// Routes logs to:
/// - Console (print): Always in dev, INFO+ in prod
/// - Future: Remote logging service (Phase 2)
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  /// Main logging method
  ///
  /// Usage:
  /// ```dart
  /// LogService().log(
  ///   level: LogLevel.info,
  ///   event: 'SIGN_IN_SUCCESS',
  ///   flow: 'auth',
  ///   userId: 'abc12345',
  ///   metadata: {'provider': 'google'},
  /// );
  /// ```
  void log({
    required LogLevel level,
    required String event,
    required String flow,
    String? userId,
    String? sessionId,
    Map<String, dynamic>? metadata,
    String? error,
  }) {
    try {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        event: event,
        flow: flow,
        userId: userId,
        sessionId: sessionId,
        metadata: metadata,
        error: error,
      );

      // Always log to console (with level filtering)
      _logToConsole(entry);

      // Future: Remote logging service (Phase 2)
      // if (level.isAtLeast(LogLevel.error)) {
      //   _logToRemote(entry);
      // }
    } catch (e) {
      // Logging failures should never crash the app
      if (kDebugMode) {
        print('[LogService] Failed to log event: $e');
      }
    }
  }

  /// Log to console with format based on environment
  void _logToConsole(LogEntry entry) {
    try {
      // In production, only log INFO+ and use JSON format
      if (!kDebugMode) {
        if (entry.level.isAtLeast(LogLevel.info)) {
          print(jsonEncode(entry.toJson()));
        }
        return;
      }

      // In development, pretty-print all levels
      print(entry.toString());
    } catch (e) {
      // Silently fail in production, print in dev
      if (kDebugMode) {
        print('[LogService] Console logging failed: $e');
      }
    }
  }

  // Future: Remote logging to backend API/Sentry (Phase 2)
  // void _logToRemote(LogEntry entry) async {
  //   try {
  //     await http.post(
  //       Uri.parse('${ApiConfig.baseUrl}/logs'),
  //       headers: ApiConfig.commonHeaders,
  //       body: jsonEncode(entry.toJson()),
  //     );
  //   } catch (e) {
  //     // Silently fail - don't want to impact app performance
  //   }
  // }
}
