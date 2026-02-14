import 'dart:developer';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// A singleton HTTP client wrapper that automatically handles 401 errors
/// by refreshing the JWT token and retrying the request once.
///
/// This ensures consistent token refresh behavior across all API services
/// without duplicating retry logic.
///
/// Usage:
/// ```dart
/// final client = AuthenticatedHttpClient();
/// final response = await client.get(uri, headers: headers);
/// ```
class AuthenticatedHttpClient {
  static final AuthenticatedHttpClient _instance = AuthenticatedHttpClient._internal();
  factory AuthenticatedHttpClient() => _instance;
  AuthenticatedHttpClient._internal();

  final http.Client _client = http.Client();

  /// Makes a GET request with automatic 401 retry logic.
  ///
  /// If the response is 401, attempts to refresh the token and retries once.
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return _makeRequest(() async {
      final request = http.Request('GET', url);
      if (headers != null) request.headers.addAll(headers);

      final streamedResponse = await _client.send(request).timeout(
        timeout ?? const Duration(seconds: 30),
      );
      return await http.Response.fromStream(streamedResponse);
    }, headers: headers);
  }

  /// Makes a POST request with automatic 401 retry logic.
  ///
  /// If the response is 401, attempts to refresh the token and retries once.
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _makeRequest(() async {
      final request = http.Request('POST', url);
      if (headers != null) request.headers.addAll(headers);
      if (body != null) {
        if (body is String) {
          request.body = body;
        } else {
          throw ArgumentError('Body must be a String');
        }
      }

      final streamedResponse = await _client.send(request).timeout(
        timeout ?? const Duration(seconds: 30),
      );
      return await http.Response.fromStream(streamedResponse);
    }, headers: headers);
  }

  /// Makes a PATCH request with automatic 401 retry logic.
  ///
  /// If the response is 401, attempts to refresh the token and retries once.
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _makeRequest(() async {
      final request = http.Request('PATCH', url);
      if (headers != null) request.headers.addAll(headers);
      if (body != null) {
        if (body is String) {
          request.body = body;
        } else {
          throw ArgumentError('Body must be a String');
        }
      }

      final streamedResponse = await _client.send(request).timeout(
        timeout ?? const Duration(seconds: 30),
      );
      return await http.Response.fromStream(streamedResponse);
    }, headers: headers);
  }

  /// Makes a DELETE request with automatic 401 retry logic.
  ///
  /// If the response is 401, attempts to refresh the token and retries once.
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _makeRequest(() async {
      final request = http.Request('DELETE', url);
      if (headers != null) request.headers.addAll(headers);
      if (body != null) {
        if (body is String) {
          request.body = body;
        } else {
          throw ArgumentError('Body must be a String');
        }
      }

      final streamedResponse = await _client.send(request).timeout(
        timeout ?? const Duration(seconds: 30),
      );
      return await http.Response.fromStream(streamedResponse);
    }, headers: headers);
  }

  /// Sends a multipart request with automatic 401 retry logic.
  ///
  /// Special handling for multipart requests: updates the Authorization header
  /// with the new token on retry.
  ///
  /// If the response is 401, attempts to refresh the token, updates the
  /// Authorization header, and retries once.
  Future<http.Response> sendMultipart(
    http.MultipartRequest request, {
    Duration? timeout,
  }) async {
    // First attempt
    var streamedResponse = await _client.send(request).timeout(
      timeout ?? const Duration(seconds: 30),
    );
    var response = await http.Response.fromStream(streamedResponse);

    // Retry once on 401 after refreshing token
    if (response.statusCode == 401) {
      log('AuthenticatedHttpClient: Got 401 on multipart request, attempting token refresh and retry');
      final refreshResult = await AuthService().refreshSession();

      if (refreshResult.success) {
        log('AuthenticatedHttpClient: Token refreshed, updating Authorization header and retrying multipart request');

        // Update Authorization header with new token
        final newAccessToken = AuthService().currentSession?.accessToken;
        if (newAccessToken != null) {
          request.headers['Authorization'] = 'Bearer $newAccessToken';
        }

        // Retry the request
        streamedResponse = await _client.send(request).timeout(
          timeout ?? const Duration(seconds: 30),
        );
        response = await http.Response.fromStream(streamedResponse);
        log('AuthenticatedHttpClient: Multipart retry response status: ${response.statusCode}');
      } else {
        log('AuthenticatedHttpClient: Token refresh failed for multipart request, cannot retry');
      }
    }

    return response;
  }

  /// Core retry logic: attempts request, retries once on 401 after token refresh.
  ///
  /// This pattern is copied from TagService (lines 89-100) which has proven
  /// to work correctly with the backend's JWT contract.
  Future<http.Response> _makeRequest(
    Future<http.Response> Function() makeRequest, {
    Map<String, String>? headers,
  }) async {
    // First attempt
    var response = await makeRequest();

    // Retry once on 401 after refreshing token
    if (response.statusCode == 401) {
      log('AuthenticatedHttpClient: Got 401, attempting token refresh and retry');
      final refreshResult = await AuthService().refreshSession();

      if (refreshResult.success) {
        log('AuthenticatedHttpClient: Token refreshed, retrying request');

        // Update Authorization header with new token if headers were provided
        if (headers != null) {
          final newAccessToken = AuthService().currentSession?.accessToken;
          if (newAccessToken != null) {
            headers['Authorization'] = 'Bearer $newAccessToken';
          }
        }

        // Retry the request
        response = await makeRequest();
        log('AuthenticatedHttpClient: Retry response status: ${response.statusCode}');
      } else {
        log('AuthenticatedHttpClient: Token refresh failed, cannot retry');
      }
    }

    return response;
  }

  /// Closes the underlying HTTP client.
  /// Should be called when the client is no longer needed (e.g., app shutdown).
  void close() {
    _client.close();
  }
}
