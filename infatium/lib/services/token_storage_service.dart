/// Service for storing and retrieving custom auth tokens.
///
/// Uses SharedPreferences for persistent storage across app restarts.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_auth_models.dart';

/// Manages persistent storage of custom authentication tokens and user data.
///
/// Singleton service that stores tokens in SharedPreferences with the
/// `custom_auth.` prefix.
class TokenStorageService {
  static final TokenStorageService _instance = TokenStorageService._internal();
  factory TokenStorageService() => _instance;
  TokenStorageService._internal();

  // Storage keys with custom_auth prefix
  static const String _tokensKey = 'custom_auth.tokens';
  static const String _userKey = 'custom_auth.user';

  /// Get stored authentication tokens.
  ///
  /// Returns null if no tokens are stored or if they fail validation.
  Future<CustomAuthTokens?> getTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokensJson = prefs.getString(_tokensKey);

      if (tokensJson == null || tokensJson.isEmpty) {
        return null;
      }

      final tokens = CustomAuthTokens.fromJsonString(tokensJson);

      if (tokens == null) {
        print('TokenStorageService: Failed to parse tokens, clearing storage');
        await clearTokens();
        return null;
      }

      return tokens;
    } catch (e) {
      print('TokenStorageService.getTokens error: $e');
      return null;
    }
  }

  /// Save authentication tokens.
  ///
  /// ⚠️ CRITICAL: This must be called immediately after token refresh
  /// because refresh tokens rotate on every use!
  Future<void> saveTokens(CustomAuthTokens tokens) async {
    try {
      await _saveWithTimeout(() async {
        final prefs = await SharedPreferences.getInstance();
        final tokensJson = tokens.toJsonString();

        final success = await prefs.setString(_tokensKey, tokensJson);

        if (!success) {
          throw Exception('Failed to save tokens to SharedPreferences');
        }

        print('TokenStorageService: Tokens saved successfully (expires: ${tokens.expiresAt})');
      });
    } catch (e) {
      print('TokenStorageService.saveTokens error: $e');
      rethrow;
    }
  }

  /// Clear stored authentication tokens.
  ///
  /// Called on logout or when token storage becomes corrupted.
  Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokensKey);
      print('TokenStorageService: Tokens cleared');
    } catch (e) {
      print('TokenStorageService.clearTokens error: $e');
      rethrow;
    }
  }

  /// Get stored user data.
  ///
  /// Returns null if no user is stored or if data fails validation.
  Future<CustomAuthUser?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);

      if (userJson == null || userJson.isEmpty) {
        return null;
      }

      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      final user = CustomAuthUser.fromJson(userData);

      return user;
    } catch (e) {
      print('TokenStorageService.getUser error: $e');
      return null;
    }
  }

  /// Save user data.
  ///
  /// Called after successful authentication or token refresh.
  Future<void> saveUser(CustomAuthUser user) async {
    try {
      await _saveWithTimeout(() async {
        final prefs = await SharedPreferences.getInstance();
        final userJson = jsonEncode(user.toJson());

        final success = await prefs.setString(_userKey, userJson);

        if (!success) {
          throw Exception('Failed to save user to SharedPreferences');
        }

        print('TokenStorageService: User saved successfully (${user.email})');
      });
    } catch (e) {
      print('TokenStorageService.saveUser error: $e');
      rethrow;
    }
  }

  /// Atomically save both tokens and user data.
  ///
  /// ⚠️ CRITICAL: This is the recommended way to save session data after token refresh.
  /// If either save fails, both are rolled back to prevent partial state.
  ///
  /// Returns true if both saved successfully, false otherwise.
  Future<bool> saveSession(CustomAuthTokens tokens, CustomAuthUser user) async {
    try {
      return await _saveSessionWithTimeout(() async {
        final prefs = await SharedPreferences.getInstance();

        // Serialize both
        final tokensJson = tokens.toJsonString();
        final userJson = jsonEncode(user.toJson());

        print('TokenStorageService: Saving session...');
        print('  Refresh token: ${_preview(tokens.refreshToken)}');

        // Save tokens first
        final tokensSuccess = await prefs.setString(_tokensKey, tokensJson);
        if (!tokensSuccess) {
          print('❌ TokenStorageService: Failed to save tokens');
          return false;
        }

        // Save user data
        final userSuccess = await prefs.setString(_userKey, userJson);
        if (!userSuccess) {
          // Rollback tokens if user save failed
          await prefs.remove(_tokensKey);
          print('❌ TokenStorageService: Failed to save user, rolled back tokens');
          return false;
        }

        // CRITICAL: Read back to verify
        final verifyTokensJson = prefs.getString(_tokensKey);
        if (verifyTokensJson == null) {
          print('❌ CRITICAL: Tokens not in storage after save!');
          return false;
        }

        final verifyTokens = CustomAuthTokens.fromJsonString(verifyTokensJson);
        if (verifyTokens == null || verifyTokens.refreshToken != tokens.refreshToken) {
          print('❌ CRITICAL: Storage verification failed!');
          print('   Expected: ${_preview(tokens.refreshToken)}');
          print('   Got: ${_preview(verifyTokens?.refreshToken)}');
          return false;
        }

        print('✓ TokenStorageService: Session saved and verified');
        return true;
      });
    } catch (e) {
      print('❌ TokenStorageService: Exception: $e');
      return false;
    }
  }

  /// Helper to preview token for logging (shows first/last 8 chars).
  String _preview(String? token) {
    if (token == null) return 'null';
    if (token.length < 16) return token;
    return '${token.substring(0, 8)}...${token.substring(token.length - 8)}';
  }

  /// Clear stored user data.
  ///
  /// Called on logout or when switching users.
  Future<void> clearUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      print('TokenStorageService: User cleared');
    } catch (e) {
      print('TokenStorageService.clearUser error: $e');
      rethrow;
    }
  }

  /// Clear all custom auth data (tokens + user).
  ///
  /// Called on logout or when resetting auth state.
  Future<void> clearAll() async {
    await clearTokens();
    await clearUser();
    print('TokenStorageService: All data cleared');
  }

  /// Check if valid tokens exist in storage.
  ///
  /// Returns true if tokens exist and are not expired.
  Future<bool> hasValidTokens() async {
    final tokens = await getTokens();
    if (tokens == null) return false;
    return !tokens.isExpired();
  }

  /// Debug: Print all stored custom auth data.
  ///
  /// Only use in development for debugging.
  Future<void> debugPrintStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokensJson = prefs.getString(_tokensKey);
      final userJson = prefs.getString(_userKey);

      print('=== TokenStorageService Debug ===');
      print('Tokens: ${tokensJson != null ? 'EXISTS (${tokensJson.length} chars)' : 'NULL'}');
      print('User: ${userJson != null ? 'EXISTS' : 'NULL'}');

      if (tokensJson != null) {
        final tokens = CustomAuthTokens.fromJsonString(tokensJson);
        if (tokens != null) {
          print('Token expires at: ${tokens.expiresAt}');
          print('Token expired: ${tokens.isExpired()}');
        }
      }

      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        print('User email: ${userData['email']}');
        print('User ID: ${userData['id']}');
      }

      print('================================');
    } catch (e) {
      print('TokenStorageService.debugPrintStorage error: $e');
    }
  }

  // Helper: Execute storage operation with timeout
  Future<void> _saveWithTimeout(Future<void> Function() operation) async {
    await operation().timeout(
      Duration(seconds: 5),
      onTimeout: () {
        throw Exception('Storage operation timeout - took too long');
      },
    );
  }

  // Helper: Execute session save with timeout and bool return
  Future<bool> _saveSessionWithTimeout(Future<bool> Function() operation) async {
    try {
      return await operation().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('TokenStorageService: Session save timeout');
          return false;
        },
      );
    } catch (e) {
      print('TokenStorageService: Session save exception: $e');
      return false;
    }
  }
}
