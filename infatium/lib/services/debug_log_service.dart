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
/// // In main.dart, start capturing and wrap runApp in a zone:
/// DebugLogService().startCapturing();
/// runZoned(
///   () => runApp(MyApp()),
///   zoneSpecification: ZoneSpecification(
///     print: (self, parent, zone, line) {
///       parent.print(zone, line);
///       DebugLogService().captureLog(line);
///     },
///   ),
/// );
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

  /// Guard to prevent recursive log capture during ping/flush.
  /// When true, print() calls from _sendPing/_flushLogs are ignored
  /// by captureLog() to avoid infinite recursion (since print() is
  /// intercepted by the zone and calls captureLog again).
  bool _isFlushing = false;

  /// Maximum buffer size before force flush (to prevent memory issues).
  static const int _maxBufferSize = 100;

  /// Interval for periodic log flushing (seconds).
  static const int _flushIntervalSeconds = 5;

  /// Start capturing logs and sending them to debug endpoint.
  ///
  /// Does NOT wrap anything in runZoned(). The caller manages zone-based
  /// print interception separately (e.g. wrapping only runApp).
  ///
  /// Call [captureLog] from a ZoneSpecification print handler to feed logs.
  void startCapturing() {
    _isEnabled = true;

    // Start periodic flush timer
    _flushTimer = Timer.periodic(
      Duration(seconds: _flushIntervalSeconds),
      (_) => _flushLogs(),
    );

    // Delay ping to ensure network is ready after app startup
    Future.delayed(Duration(seconds: 2), () => _sendPing());
  }

  /// Send a ping to verify connectivity with the debug endpoint.
  Future<void> _sendPing() async {
    _isFlushing = true;
    try {
      final url = debugUrl;
      // ignore: avoid_print
      print('DebugLogService ping: POST $url');
      final response = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'source': 'flutter_app',
              'type': 'ping',
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(Duration(seconds: 10));
      // ignore: avoid_print
      print('DebugLogService ping: HTTP ${response.statusCode}');
    } catch (e) {
      // ignore: avoid_print
      print('DebugLogService ping FAILED: $e');
    } finally {
      _isFlushing = false;
    }
  }

  /// Capture a log message and add to buffer.
  ///
  /// Call this from a ZoneSpecification print handler to feed logs
  /// when using [startCapturing].
  void captureLog(String message) {
    if (!_isEnabled || _isFlushing) return;

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

    _isFlushing = true;
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

      if (response.statusCode == 200) {
        // ignore: avoid_print
        print('DebugLogService: sent ${logsToSend.length} logs');
      } else {
        // ignore: avoid_print
        print('DebugLogService: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('DebugLogService flush failed: $e');
    } finally {
      _isFlushing = false;
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
