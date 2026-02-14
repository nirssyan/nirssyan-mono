/// Data models for custom auth-service.
///
/// These models represent the authentication data structures used by the custom
/// auth-service at https://dev.api.infatium.ru/auth.
library;

import 'dart:convert';

/// Represents a user authenticated via custom auth-service.
class CustomAuthUser {
  /// Unique user identifier (UUID).
  final String id;

  /// User's email address.
  final String email;

  /// Authentication provider (google, apple, magiclink).
  final String? provider;

  /// Additional user metadata from auth-service.
  final Map<String, dynamic>? metadata;

  const CustomAuthUser({
    required this.id,
    required this.email,
    this.provider,
    this.metadata,
  });

  /// Create from JSON response from auth-service.
  factory CustomAuthUser.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null || json['id'] is! String) {
      throw FormatException('Missing or invalid user id in response');
    }
    if (json['email'] == null || json['email'] is! String) {
      throw FormatException('Missing or invalid user email in response');
    }

    return CustomAuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      provider: json['provider'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      if (provider != null) 'provider': provider,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() => 'CustomAuthUser(id: $id, email: $email, provider: $provider)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomAuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          provider == other.provider;

  @override
  int get hashCode => id.hashCode ^ email.hashCode ^ provider.hashCode;
}

/// Represents a complete authentication session from custom auth-service.
///
/// ⚠️ CRITICAL: The refresh token ROTATES on every use! After calling
/// `/auth/refresh`, the old refresh token becomes invalid and you MUST
/// use the new refresh token from the response.
class CustomAuthSession {
  /// JWT access token for API authorization.
  ///
  /// Lifetime: 15 minutes
  /// Include in Authorization header: `Bearer {accessToken}`
  final String accessToken;

  /// Refresh token for obtaining new access tokens.
  ///
  /// ⚠️ CRITICAL: This token ROTATES on every refresh!
  /// After `/auth/refresh`, this token becomes invalid.
  /// Always use the new refresh_token from the response.
  final String refreshToken;

  /// Access token lifetime in seconds (typically 900 = 15 minutes).
  final int expiresIn;

  /// Absolute expiration timestamp for the access token.
  final DateTime expiresAt;

  /// Token type (always "Bearer").
  final String tokenType;

  /// The authenticated user.
  final CustomAuthUser user;

  const CustomAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.expiresAt,
    required this.tokenType,
    required this.user,
  });

  /// Create from JSON response from auth-service.
  ///
  /// Handles both login responses and refresh responses.
  ///
  /// For refresh responses, the backend may not include the user object
  /// (following OAuth 2.0 best practices). In this case, provide [existingUser]
  /// to reuse the current user from the session.
  factory CustomAuthSession.fromJson(
    Map<String, dynamic> json, {
    CustomAuthUser? existingUser,
  }) {
    // Validate required fields exist and have correct types
    if (json['access_token'] == null || json['access_token'] is! String) {
      throw FormatException('Missing or invalid access_token in response');
    }
    if (json['refresh_token'] == null || json['refresh_token'] is! String) {
      throw FormatException('Missing or invalid refresh_token in response');
    }
    if (json['expires_in'] == null || json['expires_in'] is! int) {
      throw FormatException('Missing or invalid expires_in in response');
    }

    // Parse user from JSON OR use existingUser fallback
    final CustomAuthUser user;

    if (json['user'] != null && json['user'] is Map<String, dynamic>) {
      // Login/OAuth response with user data
      user = CustomAuthUser.fromJson(json['user'] as Map<String, dynamic>);
    } else if (existingUser != null) {
      // Refresh response without user data - reuse existing user
      user = existingUser;
    } else {
      // Neither JSON user nor existingUser provided
      throw FormatException('Missing user object in response and no existingUser provided');
    }

    final expiresIn = json['expires_in'] as int;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    return CustomAuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: expiresIn,
      expiresAt: expiresAt,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      user: user,
    );
  }

  /// Convert to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'expires_at': expiresAt.toIso8601String(),
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }

  /// Check if the access token is expired or expires soon.
  ///
  /// [bufferSeconds] - Seconds before expiry to consider "expired" (default: 60).
  /// This allows for network latency and clock skew.
  bool isExpired({int bufferSeconds = 60}) {
    final now = DateTime.now();
    final expiryWithBuffer = expiresAt.subtract(Duration(seconds: bufferSeconds));
    return now.isAfter(expiryWithBuffer);
  }

  @override
  String toString() =>
      'CustomAuthSession(user: ${user.email}, expiresAt: $expiresAt, expired: ${isExpired()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomAuthSession &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          user == other.user;

  @override
  int get hashCode => accessToken.hashCode ^ refreshToken.hashCode ^ user.hashCode;
}

/// Represents stored authentication tokens.
///
/// Used by TokenStorageService for SharedPreferences persistence.
class CustomAuthTokens {
  /// JWT access token.
  final String accessToken;

  /// Refresh token (rotates on every use).
  final String refreshToken;

  /// Absolute expiration timestamp.
  final DateTime expiresAt;

  const CustomAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  /// Create from JSON stored in SharedPreferences.
  factory CustomAuthTokens.fromJson(Map<String, dynamic> json) {
    return CustomAuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  /// Convert to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  /// Encode to JSON string for SharedPreferences.
  String toJsonString() => jsonEncode(toJson());

  /// Decode from JSON string from SharedPreferences.
  static CustomAuthTokens? fromJsonString(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return CustomAuthTokens.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      print('Failed to parse CustomAuthTokens from JSON: $e');
      return null;
    }
  }

  /// Check if the access token is expired or expires soon.
  bool isExpired({int bufferSeconds = 60}) {
    final now = DateTime.now();
    final expiryWithBuffer = expiresAt.subtract(Duration(seconds: bufferSeconds));
    return now.isAfter(expiryWithBuffer);
  }

  @override
  String toString() => 'CustomAuthTokens(expiresAt: $expiresAt, expired: ${isExpired()})';
}

/// Exception thrown by custom auth-service operations.
class CustomAuthException implements Exception {
  /// Error code from auth-service or internal error code.
  final String code;

  /// Human-readable error message.
  final String message;

  /// HTTP status code if applicable.
  final int? statusCode;

  const CustomAuthException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'CustomAuthException($code: $message${statusCode != null ? ' [HTTP $statusCode]' : ''})';
}
