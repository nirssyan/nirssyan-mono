/// HTTP client for custom auth-service.
///
/// Handles all communication with the auth-service API at
/// https://dev.api.infatium.ru/auth.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/auth_config.dart';
import '../models/custom_auth_models.dart';

/// HTTP client for custom authentication service.
///
/// Provides methods for all auth-service endpoints:
/// - Google OAuth
/// - Apple OAuth
/// - Magic link (send and verify)
/// - Token refresh
/// - Logout
class CustomAuthClient {
  static final CustomAuthClient _instance = CustomAuthClient._internal();
  factory CustomAuthClient() => _instance;
  CustomAuthClient._internal();

  /// Base URL for auth-service (from AuthConfig).
  String get baseUrl => AuthConfig.customAuthBaseUrl;

  /// HTTP client with default timeout.
  final http.Client _client = http.Client();

  /// Sign in with Google OAuth.
  ///
  /// Takes an ID token from Google Sign-In SDK and exchanges it for
  /// a custom auth-service session.
  ///
  /// [idToken] - Google ID token from native Google Sign-In
  ///
  /// Returns [CustomAuthSession] with JWT pair and user data.
  ///
  /// Throws [CustomAuthException] on error.
  Future<CustomAuthSession> signInWithGoogle(String idToken) async {
    return await _post(
      endpoint: '/google',
      body: {'id_token': idToken},
      operation: 'signInWithGoogle',
    );
  }

  /// Sign in with Apple OAuth.
  ///
  /// Takes an identity token from Sign in with Apple and exchanges it for
  /// a custom auth-service session.
  ///
  /// [identityToken] - Apple identity token from sign_in_with_apple package
  ///
  /// Returns [CustomAuthSession] with JWT pair and user data.
  ///
  /// Throws [CustomAuthException] on error.
  Future<CustomAuthSession> signInWithApple(String identityToken) async {
    return await _post(
      endpoint: '/apple',
      body: {'id_token': identityToken},
      operation: 'signInWithApple',
    );
  }

  /// Send a magic link to the user's email.
  ///
  /// The user will receive an email with a link containing a verification token.
  /// The link will redirect to makefeed://auth/callback?token=...&type=magiclink
  ///
  /// [email] - User's email address
  ///
  /// Throws [CustomAuthException] on error.
  Future<void> sendMagicLink(String email) async {
    try {
      final url = Uri.parse('$baseUrl/magic-link');
      final body = jsonEncode({'email': email});

      print('CustomAuthClient: Sending magic link to $email');

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(AuthConfig.httpTimeout);

      _logRequest('POST', url, body);
      _logResponse(response);

      if (response.statusCode != 200) {
        throw _parseError(response, 'sendMagicLink');
      }

      print('CustomAuthClient: Magic link sent successfully');
    } catch (e) {
      if (e is CustomAuthException) rethrow;
      throw CustomAuthException(
        code: AuthConfig.errorNetworkError,
        message: 'Failed to send magic link: $e',
      );
    }
  }

  /// Demo login for Apple App Store Review.
  ///
  /// Calls a special endpoint that allows login without email verification.
  /// Only works for whitelisted demo accounts on the backend.
  ///
  /// [email] - Demo account email (e.g., demo@infatium.ru)
  ///
  /// Returns [CustomAuthSession] with JWT pair and user data.
  ///
  /// Throws [CustomAuthException] on error.
  Future<CustomAuthSession> demoLogin(String email) async {
    return await _post(
      endpoint: '/demo-login',
      body: {'email': email},
      operation: 'demoLogin',
    );
  }

  /// Verify a magic link token.
  ///
  /// Takes the token from the deep link callback and exchanges it for
  /// a custom auth-service session.
  ///
  /// [token] - Verification token from magic link email
  ///
  /// Returns [CustomAuthSession] with JWT pair and user data.
  ///
  /// Throws [CustomAuthException] on error.
  Future<CustomAuthSession> verifyMagicLink(String token) async {
    return await _post(
      endpoint: '/verify',
      body: {'token': token},
      operation: 'verifyMagicLink',
    );
  }

  /// Refresh the authentication session.
  ///
  /// ⚠️ CRITICAL: The refresh token ROTATES on every use!
  /// - The response contains a NEW refresh token
  /// - The OLD refresh token becomes invalid immediately
  /// - Reusing the old token returns 409 Conflict → session revoked
  ///
  /// [refreshToken] - Current refresh token (will be invalidated)
  /// [existingUser] - Current user to reuse (refresh responses don't include user per OAuth 2.0 standard)
  ///
  /// Returns [CustomAuthSession] with NEW JWT pair and user data.
  ///
  /// Throws [CustomAuthException] on error.
  /// Throws with code [AuthConfig.errorTokenReused] on 409 (security alert).
  Future<CustomAuthSession> refreshSession(
    String refreshToken, {
    required CustomAuthUser existingUser,
  }) async {
    return await _post(
      endpoint: '/refresh',
      body: {'refresh_token': refreshToken},
      operation: 'refreshSession',
      existingUser: existingUser,
    );
  }

  /// Logout and revoke the refresh token.
  ///
  /// Invalidates the refresh token on the server.
  /// The access token will remain valid until expiry (15 minutes).
  ///
  /// [refreshToken] - Current refresh token to revoke
  ///
  /// Throws [CustomAuthException] on error (but logout should proceed locally anyway).
  Future<void> logout(String refreshToken) async {
    try {
      final url = Uri.parse('$baseUrl/logout');
      final body = jsonEncode({'refresh_token': refreshToken});

      print('CustomAuthClient: Logging out');

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(AuthConfig.httpTimeout);

      _logRequest('POST', url, body);
      _logResponse(response);

      if (response.statusCode != 200) {
        print('CustomAuthClient: Logout failed with status ${response.statusCode}, proceeding anyway');
      } else {
        print('CustomAuthClient: Logged out successfully');
      }
    } catch (e) {
      print('CustomAuthClient.logout error (non-fatal): $e');
      // Don't throw - logout should succeed locally even if server call fails
    }
  }

  /// Generic POST request to auth-service that returns a session.
  ///
  /// Handles common error cases and JSON parsing.
  ///
  /// [existingUser] - Optional existing user to reuse for refresh responses
  /// that don't include user data (OAuth 2.0 standard behavior).
  Future<CustomAuthSession> _post({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    CustomAuthUser? existingUser,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final bodyJson = jsonEncode(body);

      print('CustomAuthClient: $operation request to $endpoint');

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: bodyJson,
          )
          .timeout(AuthConfig.httpTimeout);

      _logRequest('POST', url, bodyJson);
      _logResponse(response);

      if (response.statusCode != 200) {
        throw _parseError(response, operation);
      }

      // Validate response has body before parsing
      if (response.body.isEmpty) {
        throw CustomAuthException(
          code: AuthConfig.errorUnknown,
          message: 'Server returned empty response body (HTTP ${response.statusCode}) during $operation',
          statusCode: response.statusCode,
        );
      }

      // Parse JSON response
      final responseData = jsonDecode(response.body);

      // Validate response is a Map
      if (responseData is! Map<String, dynamic>) {
        throw CustomAuthException(
          code: AuthConfig.errorUnknown,
          message: 'Invalid response format during $operation: expected JSON object, got ${responseData.runtimeType}',
          statusCode: response.statusCode,
        );
      }

      // Attempt to parse session from JSON
      print('CustomAuthClient: Parsing session from response');
      try {
        final session = CustomAuthSession.fromJson(
          responseData,
          existingUser: existingUser,
        );
        print('CustomAuthClient: $operation successful (user: ${session.user.email})');
        return session;
      } catch (e) {
        // Parsing failed - log full response for debugging
        print('CustomAuthClient: Failed to parse session: $e');
        print('CustomAuthClient: Response data: $responseData');
        rethrow;
      }
    } catch (e) {
      if (e is CustomAuthException) rethrow;
      throw CustomAuthException(
        code: AuthConfig.errorNetworkError,
        message: 'Network error during $operation: $e',
      );
    }
  }

  /// Parse error response from auth-service.
  CustomAuthException _parseError(http.Response response, String operation) {
    final statusCode = response.statusCode;

    // Special case: 409 Conflict - token reused (security alert!)
    if (statusCode == AuthConfig.statusConflict) {
      return CustomAuthException(
        code: AuthConfig.errorTokenReused,
        message: 'Refresh token was reused - session revoked for security',
        statusCode: statusCode,
      );
    }

    // Try to parse error from response body
    try {
      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final errorCode = errorData['error'] as String?;
      final errorMessage = errorData['message'] as String?;

      return CustomAuthException(
        code: errorCode ?? AuthConfig.errorUnknown,
        message: errorMessage ?? 'HTTP $statusCode during $operation',
        statusCode: statusCode,
      );
    } catch (e) {
      // Failed to parse error response
      return CustomAuthException(
        code: AuthConfig.errorUnknown,
        message: 'HTTP $statusCode during $operation: ${response.body}',
        statusCode: statusCode,
      );
    }
  }

  /// Log HTTP request for debugging.
  void _logRequest(String method, Uri url, String body) {
    print('CustomAuthClient: $method ${url.path}');
    print('CustomAuthClient: Request body: ${_sanitizeBody(body)}');
  }

  /// Log HTTP response for debugging.
  void _logResponse(http.Response response) {
    print('CustomAuthClient: Response ${response.statusCode}');
    print('CustomAuthClient: Response body length: ${response.body.length}');

    // Log sanitized response for debugging
    if (response.statusCode == 200) {
      // For success responses, sanitize tokens but show structure
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sanitized = Map<String, dynamic>.from(data);

        // Sanitize sensitive fields
        if (sanitized.containsKey('access_token')) {
          final token = sanitized['access_token'] as String;
          sanitized['access_token'] = token.length > 16 ? '${token.substring(0, 8)}...${token.substring(token.length - 8)}' : '***';
        }
        if (sanitized.containsKey('refresh_token')) {
          final token = sanitized['refresh_token'] as String;
          sanitized['refresh_token'] = token.length > 16 ? '${token.substring(0, 8)}...${token.substring(token.length - 8)}' : '***';
        }

        print('CustomAuthClient: Response body (sanitized): ${jsonEncode(sanitized)}');
      } catch (e) {
        // Fallback to truncated body if parsing fails
        final bodyPreview = response.body.length > 200
            ? '${response.body.substring(0, 200)}...'
            : response.body;
        print('CustomAuthClient: Response body preview: $bodyPreview');
      }
    } else {
      // For errors, log full body
      print('CustomAuthClient: Response body: ${response.body}');
    }
  }

  /// Sanitize request body for logging (hide sensitive tokens).
  String _sanitizeBody(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final sanitized = Map<String, dynamic>.from(data);

      // Hide sensitive fields
      if (sanitized.containsKey('id_token')) {
        sanitized['id_token'] = '***REDACTED***';
      }
      if (sanitized.containsKey('refresh_token')) {
        final token = sanitized['refresh_token'] as String;
        sanitized['refresh_token'] = '${token.substring(0, 8)}...';
      }
      if (sanitized.containsKey('token')) {
        final token = sanitized['token'] as String;
        sanitized['token'] = '${token.substring(0, 8)}...';
      }

      return jsonEncode(sanitized);
    } catch (e) {
      return '***PARSE ERROR***';
    }
  }

  /// Dispose the HTTP client.
  void dispose() {
    _client.close();
  }
}
