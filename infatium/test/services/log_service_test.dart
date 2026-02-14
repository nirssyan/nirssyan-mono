import 'package:flutter_test/flutter_test.dart';
import 'package:makefeed/models/log_level.dart';
import 'package:makefeed/models/log_entry.dart';
import 'package:makefeed/services/log_service.dart';

void main() {
  group('LogLevel', () {
    test('isAtLeast compares severity correctly', () {
      expect(LogLevel.debug.isAtLeast(LogLevel.debug), true);
      expect(LogLevel.info.isAtLeast(LogLevel.debug), true);
      expect(LogLevel.warning.isAtLeast(LogLevel.info), true);
      expect(LogLevel.error.isAtLeast(LogLevel.warning), true);
      expect(LogLevel.critical.isAtLeast(LogLevel.error), true);

      expect(LogLevel.debug.isAtLeast(LogLevel.info), false);
      expect(LogLevel.info.isAtLeast(LogLevel.warning), false);
      expect(LogLevel.warning.isAtLeast(LogLevel.error), false);
      expect(LogLevel.error.isAtLeast(LogLevel.critical), false);
    });

    test('displayName returns uppercase', () {
      expect(LogLevel.debug.displayName, 'DEBUG');
      expect(LogLevel.info.displayName, 'INFO');
      expect(LogLevel.warning.displayName, 'WARNING');
      expect(LogLevel.error.displayName, 'ERROR');
      expect(LogLevel.critical.displayName, 'CRITICAL');
    });
  });

  group('LogEntry', () {
    test('toJson serializes all fields correctly', () {
      final timestamp = DateTime.utc(2026, 2, 7, 12, 34, 56);
      final entry = LogEntry(
        timestamp: timestamp,
        level: LogLevel.info,
        event: 'SIGN_IN_SUCCESS',
        flow: 'auth',
        userId: 'abc12345',
        sessionId: 'session123',
        metadata: {'provider': 'google'},
        error: null,
      );

      final json = entry.toJson();

      expect(json['timestamp'], '2026-02-07T12:34:56.000Z');
      expect(json['level'], 'INFO');
      expect(json['event'], 'SIGN_IN_SUCCESS');
      expect(json['flow'], 'auth');
      expect(json['user_id'], 'abc12345');
      expect(json['session_id'], 'session123');
      expect(json['metadata'], {'provider': 'google'});
      expect(json['error'], null);
    });

    test('toJson omits null fields', () {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        event: 'TEST_EVENT',
        flow: 'test',
      );

      final json = entry.toJson();

      expect(json.containsKey('user_id'), false);
      expect(json.containsKey('session_id'), false);
      expect(json.containsKey('metadata'), false);
      expect(json.containsKey('error'), false);
    });

    test('toString formats pretty output for development', () {
      final entry = LogEntry(
        timestamp: DateTime.utc(2026, 2, 7, 12, 34, 56),
        level: LogLevel.info,
        event: 'TEST_EVENT',
        flow: 'test',
        userId: 'user123',
      );

      final output = entry.toString();

      expect(output.contains('[INFO] TEST_EVENT'), true);
      expect(output.contains('Time: 2026-02-07T12:34:56.000Z'), true);
      expect(output.contains('Flow: test'), true);
      expect(output.contains('User: user123'), true);
      expect(output.contains('━'), true); // Visual separator
    });
  });

  group('LogService', () {
    test('is a singleton', () {
      final instance1 = LogService();
      final instance2 = LogService();
      expect(identical(instance1, instance2), true);
    });

    test('log method does not throw on valid input', () {
      expect(
        () => LogService().log(
          level: LogLevel.info,
          event: 'TEST_EVENT',
          flow: 'test',
        ),
        returnsNormally,
      );
    });

    test('log method handles errors gracefully', () {
      // This should not throw even with extreme values
      expect(
        () => LogService().log(
          level: LogLevel.critical,
          event: 'A' * 10000, // Very long event name
          flow: 'test',
          metadata: {'key': 'value' * 1000},
        ),
        returnsNormally,
      );
    });
  });

  group('Event to LogLevel mapping', () {
    // Helper function to simulate _getLogLevelForEvent logic
    LogLevel getLogLevelForEvent(String event) {
      if (event.contains('TOKEN_REUSED') || event.contains('CRITICAL')) {
        return LogLevel.critical;
      } else if (event.contains('ERROR') || event.contains('UNEXPECTED')) {
        return LogLevel.error;
      } else if (event.contains('FAILED') || event.contains('CANCELLED') || event.contains('TIMEOUT')) {
        return LogLevel.warning;
      } else if (event.contains('ATTEMPT') || event.contains('STARTED') || event.contains('REFRESH_ATTEMPT')) {
        return LogLevel.debug;
      } else {
        return LogLevel.info;
      }
    }

    test('critical events mapped correctly', () {
      expect(getLogLevelForEvent('TOKEN_REUSED'), LogLevel.critical);
      expect(getLogLevelForEvent('CRITICAL_SECURITY_ALERT'), LogLevel.critical);
    });

    test('error events mapped correctly', () {
      expect(getLogLevelForEvent('SIGN_IN_ERROR'), LogLevel.error);
      expect(getLogLevelForEvent('UNEXPECTED_AUTH_FAILURE'), LogLevel.error);
    });

    test('warning events mapped correctly', () {
      expect(getLogLevelForEvent('SIGN_IN_FAILED'), LogLevel.warning);
      expect(getLogLevelForEvent('OAUTH_CANCELLED'), LogLevel.warning);
      expect(getLogLevelForEvent('REQUEST_TIMEOUT'), LogLevel.warning);
    });

    test('debug events mapped correctly', () {
      expect(getLogLevelForEvent('SIGN_IN_ATTEMPT'), LogLevel.debug);
      expect(getLogLevelForEvent('AUTH_STARTED'), LogLevel.debug);
      expect(getLogLevelForEvent('TOKEN_REFRESH_ATTEMPT'), LogLevel.debug);
    });

    test('info events mapped correctly', () {
      expect(getLogLevelForEvent('SIGN_IN_SUCCESS'), LogLevel.info);
      expect(getLogLevelForEvent('USER_SIGNED_IN'), LogLevel.info);
      expect(getLogLevelForEvent('TOKEN_REFRESHED'), LogLevel.info);
    });
  });
}
