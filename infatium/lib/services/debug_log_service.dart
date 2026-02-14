/// Service for sending app logs to debug endpoint.
///
/// Captures all print() statements and sends them to POST /debug/echo
/// for remote debugging and monitoring.
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Service that sends app logs to debug endpoint.
///
/// Usage:
/// ```dart
/// // In main.dart, wrap app initialization:
/// DebugLogService().startCapturingLogs(() {
///   runApp(MyApp());
/// });
/// ```
class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  /// HTTP client for sending logs.
  final http.Client _client = http.Client();

  /// Debug endpoint URL.
  String get debugUrl => '${ApiConfig.baseUrl}/debug/echo';

  /// Buffer for batching logs before sending.
  final List<String> _logBuffer = [];

  /// Timer for periodic log flushing.
  Timer? _flushTimer;

  /// Whether log capturing is enabled.
  bool _isEnabled = false;

  /// Maximum buffer size before force flush (to prevent memory issues).
  static const int _maxBufferSize = 100;

  /// Interval for periodic log flushing (seconds).
  static const int _flushIntervalSeconds = 5;

  /// Start capturing all print() statements and send them to debug endpoint.
  ///
  /// This wraps the app in a Zone that intercepts all print() calls.
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   DebugLogService().startCapturingLogs(() {
  ///     runApp(MyApp());
  ///   });
  /// }
  /// ```
  void startCapturingLogs(Function() appInitializer) {
    _isEnabled = true;

    // Start periodic flush timer
    _flushTimer = Timer.periodic(
      Duration(seconds: _flushIntervalSeconds),
      (_) => _flushLogs(),
    );

    // Run app in a Zone that captures print() calls
    runZoned(
      appInitializer,
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          // Call original print (so logs still appear in console)
          parent.print(zone, line);

          // Send to debug endpoint
          _captureLog(line);
        },
      ),
    );
  }

  /// Capture a log message and add to buffer.
  void _captureLog(String message) {
    if (!_isEnabled) return;

    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';

    _logBuffer.add(logEntry);

    // Force flush if buffer is full
    if (_logBuffer.length >= _maxBufferSize) {
      _flushLogs();
    }
  }

  /// Flush buffered logs to debug endpoint.
  Future<void> _flushLogs() async {
    if (_logBuffer.isEmpty) return;

    // Copy buffer and clear it immediately (to avoid blocking new logs)
    final logsToSend = List<String>.from(_logBuffer);
    _logBuffer.clear();

    try {
      final body = jsonEncode({
        'source': 'flutter_app',
        'timestamp': DateTime.now().toIso8601String(),
        'logs': logsToSend,
        'count': logsToSend.length,
      });

      final response = await _client
          .post(
            Uri.parse(debugUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode != 200) {
        // Don't use print here to avoid infinite loop
        // Just silently fail (logs are already in console)
      }
    } catch (e) {
      // Silently fail - debug logging shouldn't crash the app
      // Original logs are still in console
    }
  }

  /// Stop capturing logs and flush remaining buffer.
  Future<void> stop() async {
    _isEnabled = false;
    _flushTimer?.cancel();
    _flushTimer = null;

    // Final flush
    await _flushLogs();
  }

  /// Dispose the service.
  void dispose() {
    stop();
    _client.close();
  }
}
