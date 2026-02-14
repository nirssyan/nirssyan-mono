import 'log_level.dart';

/// Structured log entry with timestamp, level, and metadata
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String event;
  final String flow;
  final String? userId;
  final String? sessionId;
  final Map<String, dynamic>? metadata;
  final String? error;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.event,
    required this.flow,
    this.userId,
    this.sessionId,
    this.metadata,
    this.error,
  });

  /// Convert to JSON for structured logging
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'level': level.displayName,
      'event': event,
      'flow': flow,
      if (userId != null) 'user_id': userId,
      if (sessionId != null) 'session_id': sessionId,
      if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
      if (error != null) 'error': error,
    };
  }

  /// Pretty-print for development console output
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('[${level.displayName}] $event');
    buffer.writeln('Time: ${timestamp.toUtc().toIso8601String()}');
    buffer.writeln('Flow: $flow');
    if (userId != null) buffer.writeln('User: $userId');
    if (sessionId != null) buffer.writeln('Session: $sessionId');
    if (metadata != null && metadata!.isNotEmpty) {
      buffer.writeln('Metadata: $metadata');
    }
    if (error != null) buffer.writeln('Error: $error');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return buffer.toString();
  }
}
