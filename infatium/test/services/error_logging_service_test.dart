import 'package:flutter_test/flutter_test.dart';
import 'package:makefeed/models/error_log_entry.dart';

void main() {
  group('ErrorLogEntry', () {
    test('should generate consistent fingerprint for same error', () {
      final stack = StackTrace.fromString('''
#0      main.<anonymous closure> (file:///test.dart:10:5)
#1      _rootRun (dart:async/zone.dart:1234:13)
#2      _CustomZone.run (dart:async/zone.dart:1135:19)
      ''');

      final fingerprint1 = ErrorLogEntry.generateFingerprint('Exception', stack);
      final fingerprint2 = ErrorLogEntry.generateFingerprint('Exception', stack);

      expect(fingerprint1, equals(fingerprint2));
      expect(fingerprint1.length, equals(16));
    });

    test('should generate different fingerprints for different errors', () {
      final stack = StackTrace.fromString('''
#0      main.<anonymous closure> (file:///test.dart:10:5)
      ''');

      final fingerprint1 = ErrorLogEntry.generateFingerprint('Exception', stack);
      final fingerprint2 = ErrorLogEntry.generateFingerprint('StateError', stack);

      expect(fingerprint1, isNot(equals(fingerprint2)));
    });

    test('should convert to JSON correctly', () {
      final entry = ErrorLogEntry(
        errorId: 'test-123',
        errorType: 'Exception',
        errorMessage: 'Test error',
        stackTrace: 'stack trace here',
        fingerprint: 'abc123',
        timestamp: DateTime.utc(2026, 2, 11, 12, 0),
        platform: 'iOS',
        appVersion: '1.0.2',
        appBuildNumber: '10',
        osVersion: '17.0',
        severity: ErrorSeverity.error,
        userId: 'user-123',
        currentRoute: '/home',
        httpEndpoint: '/api/test',
        httpStatusCode: 500,
        httpMethod: 'GET',
      );

      final json = entry.toJson();

      expect(json['error_id'], equals('test-123'));
      expect(json['error_type'], equals('Exception'));
      expect(json['severity'], equals('error'));
      expect(json['user_id'], equals('user-123'));
      expect(json['current_route'], equals('/home'));
      expect(json['http_status_code'], equals(500));
    });

    test('should omit optional fields when null', () {
      final entry = ErrorLogEntry(
        errorId: 'test-123',
        errorType: 'Exception',
        errorMessage: 'Test error',
        stackTrace: 'stack trace here',
        fingerprint: 'abc123',
        timestamp: DateTime.utc(2026, 2, 11, 12, 0),
        platform: 'iOS',
        appVersion: '1.0.2',
        appBuildNumber: '10',
        osVersion: '17.0',
        severity: ErrorSeverity.warning,
      );

      final json = entry.toJson();

      expect(json.containsKey('user_id'), isFalse);
      expect(json.containsKey('current_route'), isFalse);
      expect(json.containsKey('http_endpoint'), isFalse);
    });
  });
}
