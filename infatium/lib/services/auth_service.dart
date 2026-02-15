import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/auth_config.dart';
import '../models/auth_error_codes.dart';
import '../models/custom_auth_models.dart';
import '../models/custom_auth_state.dart';
import 'analytics_service.dart';
import '../models/analytics_event_schema.dart';
import 'error_logging_service.dart';
import '../models/error_log_entry.dart';
import 'feed_builder_state_service.dart';
import 'feed_cache_service.dart';
import 'news_service.dart';
import 'seen_posts_service.dart';
import 'token_storage_service.dart';
import 'custom_auth_client.dart';
import 'log_service.dart';
import '../models/log_level.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Custom auth session
  CustomAuthSession? _customSession;
  final TokenStorageService _tokenStorage = TokenStorageService();
  final CustomAuthClient _customAuthClient = CustomAuthClient();
  Timer? _customRefreshTimer;
  bool _isRefreshing = false;
  int _tokenRefreshAttempts = 0;
  static const int _maxRefreshAttempts = 3;
  DateTime? _appPausedAt; // Track when app was backgrounded
  final StreamController<CustomAuthState> _customAuthStateController =
      StreamController<CustomAuthState>.broadcast();

  // Инициализация
  Future<void> initialize() async {
    // Validate auth configuration
    AuthConfig.validate();
    await _initializeCustomAuth();
  }

  // Initialize custom auth
  Future<void> _initializeCustomAuth() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔧 AuthService: Initializing custom auth');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      // Load tokens from SharedPreferences
      final tokens = await _tokenStorage.getTokens();
      if (tokens != null) {
        print('✓ Found stored tokens');
        print('  Expires at: ${tokens.expiresAt}');
        print('  Is expired: ${tokens.isExpired()}');
        print('  Time until expiry: ${tokens.expiresAt.difference(DateTime.now()).inMinutes} minutes');

        final user = await _tokenStorage.getUser();
        if (user != null) {
          print('✓ Found stored user: ${user.email}');

          // Restore session object (even if access token expired)
          _customSession = CustomAuthSession(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresIn: tokens.expiresAt.difference(DateTime.now()).inSeconds,
            expiresAt: tokens.expiresAt,
            tokenType: 'Bearer',
            user: user,
          );

          if (tokens.isExpired()) {
            // Access token expired — try to refresh using refresh token
            print('⚠️ Access token expired, attempting refresh...');
            try {
              await _refreshCustomSession();
              // If refresh succeeded, _customSession is updated and timer is started
              // (by _refreshCustomSession itself)
              if (_customSession != null) {
                _customAuthStateController.add(CustomAuthState(
                  CustomAuthEvent.signedIn,
                  _customSession,
                ));
                print('✓ Session restored via refresh for ${user.email}');
              } else {
                // Logged out during refresh (session_revoked or max retries)
                print('✗ Logged out during refresh, initialization complete');
              }
            } catch (e) {
              // Refresh failed — refresh token also invalid, force logout
              print('✗ Refresh failed on init, clearing session: $e');
              _customSession = null;
              await _tokenStorage.clearAll();
            }
          } else {
            // Access token valid — start normal management
            _startCustomSessionManagement();
            _customAuthStateController.add(CustomAuthState(
              CustomAuthEvent.signedIn,
              _customSession,
            ));
            print('✓ Custom auth session restored for ${user.email}');
          }
        } else {
          print('✗ No stored user found (tokens without user - partial state)');
          await _tokenStorage.clearAll();
        }
      } else {
        print('ℹ️ No valid custom auth session found');
      }
    } catch (e) {
      // Catch any initialization errors to ensure initialization completes
      print('⚠️ AuthService: Error during initialization: $e');
      _logSecurityEvent('AUTH_INIT_ERROR', {'error': e.toString()});

      // Clear session on critical errors
      _customSession = null;
      await _tokenStorage.clearAll();
    } finally {
      // ALWAYS complete initialization, even if logged out
      // This allows the app to show login screen instead of staying on splash
      print('AuthService: Initialization complete (authenticated: $isAuthenticated)');
    }
  }

  // Геттеры
  CustomAuthUser? get currentUser => _customSession?.user;

  CustomAuthSession? get currentSession => _customSession;

  bool get isAuthenticated => _customSession != null;

  String? get currentUserEmail => _customSession?.user.email;

  String? get currentUserName =>
      _customSession?.user.metadata?['full_name'] as String?;

  String? get currentUserPhotoURL =>
      _customSession?.user.metadata?['avatar_url'] as String?;

  String? get currentUserId => _customSession?.user.id;

  // Поток состояния авторизации
  Stream<CustomAuthState> get authStateChanges =>
      _customAuthStateController.stream;

  // ==================== Custom Auth Session Management ====================

  /// Start custom auth session management with auto-refresh.
  void _startCustomSessionManagement() {
    _stopCustomSessionManagement();

    if (_customSession == null) return;

    // Refresh every 12 minutes (3 min before 15-min expiry)
    // Larger safety buffer helps with app backgrounding scenarios
    // IMPORTANT: Callback is sync to avoid Timer.periodic issues with async callbacks
    _customRefreshTimer = Timer.periodic(AuthConfig.refreshInterval, (_) {
      // Schedule async refresh without awaiting (runs in background)
      _refreshCustomSession();
    });

    // Also schedule immediate refresh if token expires soon
    final timeUntilExpiry = _customSession!.expiresAt.difference(DateTime.now());
    if (timeUntilExpiry < Duration(minutes: 2)) {
      Future.delayed(Duration(seconds: 10), () => _refreshCustomSession());
    }

    print('AuthService: Custom session management started (refresh in ${AuthConfig.refreshInterval.inMinutes} min)');
  }

  /// Stop custom auth session management.
  void _stopCustomSessionManagement() {
    _customRefreshTimer?.cancel();
    _customRefreshTimer = null;
  }

  /// Refresh custom auth session (with token rotation).
  ///
  /// ⚠️ CRITICAL: Refresh token rotates on every use!
  /// The new refresh token must be saved immediately.
  Future<void> _refreshCustomSession() async {
    if (_isRefreshing) {
      print('AuthService: Refresh already in progress, skipping');
      return;
    }
    if (_customSession == null) {
      print('AuthService: No custom session to refresh');
      return;
    }

    // Check max retry limit
    if (_tokenRefreshAttempts >= _maxRefreshAttempts) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('⚠️ LOGOUT REASON: MAX_REFRESH_ATTEMPTS_EXCEEDED');
      print('⚠️ AuthService: Max token refresh attempts ($_maxRefreshAttempts) reached');
      print('⚠️ All refresh attempts failed (network issues or backend problems)');
      print('⚠️ Action: Force logout to prevent infinite retry loop');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logSecurityEvent('SECURITY_ALERT: MAX_REFRESH_ATTEMPTS_EXCEEDED - Forcing logout');
      await _forceCustomLogout();
      return;
    }

    _isRefreshing = true;
    _tokenRefreshAttempts++;
    bool shouldRetry = false;

    final oldRefreshToken = _customSession!.refreshToken;

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔄 AuthService: Starting token refresh (attempt $_tokenRefreshAttempts/$_maxRefreshAttempts)');
    print('   Using refresh token: ${_tokenPreview(oldRefreshToken)}');
    print('   Current session expires: ${_customSession!.expiresAt}');
    print('   Time until expiry: ${_customSession!.expiresAt.difference(DateTime.now()).inMinutes}m');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      _logSecurityEvent('CUSTOM_TOKEN_REFRESH_ATTEMPT', {
        'attempt': _tokenRefreshAttempts,
      });

      final newSession = await _customAuthClient.refreshSession(
        oldRefreshToken,
        existingUser: _customSession!.user, // Reuse existing user (OAuth 2.0 standard)
      );

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ Refresh response received from backend');
      print('   New refresh token: ${_tokenPreview(newSession.refreshToken)}');
      print('   New expires at: ${newSession.expiresAt}');

      // CRITICAL: Verify tokens rotated
      if (newSession.refreshToken == oldRefreshToken) {
        throw Exception('CRITICAL: Backend returned SAME refresh token! Token rotation failed!');
      }
      print('✓ Token rotation verified (old != new)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ⚠️ CRITICAL: Save immediately! Refresh token rotates
      // Use try-catch to distinguish storage errors from network errors
      try {
        await _setCustomSession(newSession);
      } catch (storageError) {
        // Storage exception - NOT retryable
        // Token refresh succeeded on backend, but we failed to persist new tokens
        // Retrying would use the old refresh token → 409 Conflict
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('⚠️ LOGOUT REASON: STORAGE_ERROR');
        print('⚠️ AuthService: Failed to save tokens after refresh');
        print('⚠️ Error: $storageError');
        print('⚠️ Impact: Refresh succeeded on backend, but tokens not persisted');
        print('⚠️ Action: Logout to prevent 409 on next refresh attempt');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _logSecurityEvent('STORAGE_ERROR: Failed to persist new tokens - forcing logout');
        await ErrorLoggingService().captureException(
          storageError,
          StackTrace.current,
          context: 'token_refresh_storage',
          extraData: {'operation': 'saveSession'},
          severity: ErrorSeverity.error,
        );
        await _forceCustomLogout();
        return; // Exit without retry
      }

      // CRITICAL: Verify _customSession updated
      if (_customSession!.refreshToken != newSession.refreshToken) {
        throw Exception('CRITICAL: _customSession not updated after save!');
      }
      print('✓ VERIFIED: _customSession.refreshToken = ${_tokenPreview(_customSession!.refreshToken)}');

      _logSecurityEvent('CUSTOM_TOKEN_REFRESHED');
      _customAuthStateController.add(CustomAuthState(
        CustomAuthEvent.tokenRefreshed,
        newSession,
      ));

      // Reset retry counter on success
      _tokenRefreshAttempts = 0;

      // Restart timer with new expiry
      _startCustomSessionManagement();

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ SUCCESS: Token refresh completed');
      print('✅ New tokens saved and verified');
      print('✅ User: ${newSession.user.email}');
      print('✅ New expiry: ${newSession.expiresAt}');
      print('✅ Retry counter reset: $_tokenRefreshAttempts');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } on CustomAuthException catch (e) {
      // Network/API errors from refresh endpoint
      _logSecurityEvent('CUSTOM_TOKEN_REFRESH_FAILED: $e');

      final errorString = e.toString().toLowerCase();
      final isTokenReused = errorString.contains('token_reused') || e.statusCode == 409;
      final isTokenAlreadyRefreshed = errorString.contains('token_already_refreshed') || errorString.contains('already refreshed');
      final isSessionRevoked = errorString.contains('session_revoked');
      final isUnauthorized = e.statusCode == 401;

      if (isTokenAlreadyRefreshed) {
        // Token was already refreshed - check if access token is still valid
        // Case A: Access token still valid → race condition (OK, skip)
        // Case B: Access token expired → try silent re-login for demo, logout for OAuth

        if (_customSession != null && !_customSession!.isExpired()) {
          // Case A: Access token still valid - this is a race condition (safe)
          print('ℹ️ AuthService: Token already refreshed (race condition detected)');
          print('   This is normal when multiple refresh attempts happen concurrently');
          print('   The first refresh succeeded, this one arrived late within grace period');
          print('   Status Code: ${e.statusCode}');
          print('   Access token still valid until: ${_customSession!.expiresAt}');
          print('   Time left: ${_customSession!.expiresAt.difference(DateTime.now()).inMinutes}m');
          print('   No action needed - session is still valid');
          // Reset refresh flag and attempts counter
          _tokenRefreshAttempts = 0;
          // Don't logout - the session is fine, just skip this refresh
        } else {
          // Case B: Access token expired + refresh failed
          // For demo accounts: Try silent re-login (backend doesn't store demo refresh tokens)
          // For OAuth accounts: This means token storage is corrupted, logout is correct

          final isDemoAccount = _customSession?.user.email == 'demo@infatium.ru';

          if (isDemoAccount) {
            print('ℹ️ Demo account with expired token, attempting silent re-login...');
            try {
              await _silentDemoReLogin();
              print('✅ Silent re-login successful');
              _tokenRefreshAttempts = 0;
              return; // Exit without logout
            } catch (e) {
              print('❌ Silent re-login failed: $e');
              // Fallthrough to logout
            }
          }

          // For OAuth accounts OR if demo re-login failed
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('⚠️ LOGOUT REASON: TOKEN_ALREADY_REFRESHED + ACCESS_TOKEN_EXPIRED');
          print('⚠️ AuthService: Refresh token was already used AND access token expired');
          print('⚠️ Status Code: ${e.statusCode}');
          print('⚠️ Error: $e');
          print('⚠️ Root cause: Token storage corrupted or backend token mismatch');
          print('⚠️ Action: Force logout');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          _logSecurityEvent('SECURITY_ALERT: TOKEN_ALREADY_REFRESHED_WITH_EXPIRED_ACCESS - Forcing logout');
          await _forceCustomLogout();
        }
      } else if (isTokenReused) {
        // Token reuse detected (409) - SECURITY ALERT
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('⚠️ LOGOUT REASON: TOKEN_REUSED (409 Conflict)');
        print('⚠️ AuthService: Refresh token was already used');
        print('⚠️ Status Code: ${e.statusCode}');
        print('⚠️ Error: $e');
        print('⚠️ Possible causes:');
        print('   1. Storage failed on previous refresh → retry with old token');
        print('   2. User logged in on another device');
        print('   3. Token theft (security incident)');
        print('⚠️ Action: Force logout for security');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _logSecurityEvent('SECURITY_ALERT: TOKEN_REUSED - Forcing logout');
        await _forceCustomLogout();
      } else if (isSessionRevoked || isUnauthorized) {
        // Session revoked on backend (401) - log out user immediately
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('⚠️ LOGOUT REASON: SESSION_REVOKED (401 Unauthorized)');
        print('⚠️ AuthService: Session was revoked on backend');
        print('⚠️ Status Code: ${e.statusCode}');
        print('⚠️ Error: $e');
        print('⚠️ Possible causes:');
        print('   1. Admin revoked session');
        print('   2. User account suspended/deleted');
        print('   3. Security policy enforcement');
        print('⚠️ Action: Force logout');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _logSecurityEvent('SECURITY_ALERT: SESSION_REVOKED - Forcing logout');
        await _forceCustomLogout();
      } else {
        // Network error - retryable
        print('⚠️ AuthService: Network error during refresh (attempt $_tokenRefreshAttempts/$_maxRefreshAttempts)');
        print('   Status Code: ${e.statusCode}');
        print('   Error: $e');
        print('   Will retry after ${AuthConfig.refreshRetryDelay.inSeconds}s');
        shouldRetry = true;
      }
    } on FormatException catch (e) {
      // Parsing error - NOT retryable
      _logSecurityEvent('CUSTOM_TOKEN_REFRESH_FAILED: Parsing error - $e');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('⚠️ LOGOUT REASON: PARSING_ERROR');
      print('⚠️ AuthService: Failed to parse refresh response');
      print('⚠️ Error: $e');
      print('⚠️ Possible causes:');
      print('   1. Backend API format changed');
      print('   2. Server/client version mismatch');
      print('   3. Missing required fields in response');
      print('⚠️ Impact: Cannot parse new tokens from backend');
      print('⚠️ Action: Logout to prevent token reuse (backend may have rotated token)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logSecurityEvent('SECURITY_ALERT: PARSING_ERROR - Forcing logout to prevent stale token reuse');
      await ErrorLoggingService().captureException(
        e,
        StackTrace.current,
        context: 'token_refresh_parsing',
        extraData: {'error': e.toString()},
        severity: ErrorSeverity.error,
      );
      await _forceCustomLogout();
    } catch (e) {
      // Unknown error - log and logout for safety
      _logSecurityEvent('CUSTOM_TOKEN_REFRESH_FAILED: Unknown error - $e');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('⚠️ LOGOUT REASON: UNKNOWN_ERROR');
      print('⚠️ AuthService: Unexpected error during token refresh');
      print('⚠️ Error: $e');
      print('⚠️ Action: Logout for safety (cannot determine if tokens are valid)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logSecurityEvent('SECURITY_ALERT: UNKNOWN_ERROR - Forcing logout');
      await ErrorLoggingService().captureException(
        e,
        StackTrace.current,
        context: 'token_refresh_unknown',
        extraData: {'error': e.toString()},
        severity: ErrorSeverity.error,
      );
      await _forceCustomLogout();
    } finally {
      _isRefreshing = false;
    }

    // Retry outside try/catch/finally so _isRefreshing is already false
    if (shouldRetry && _customSession != null && _tokenRefreshAttempts < _maxRefreshAttempts) {
      print('⏳ AuthService: Token refresh failed (attempt $_tokenRefreshAttempts/$_maxRefreshAttempts)');
      print('   Retrying in ${AuthConfig.refreshRetryDelay.inSeconds} seconds...');
      await Future.delayed(AuthConfig.refreshRetryDelay);

      // Validate tokens are still valid before retry
      final storedTokens = await _tokenStorage.getTokens();
      if (storedTokens == null) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('⚠️ LOGOUT REASON: TOKENS_CLEARED_DURING_RETRY');
        print('⚠️ AuthService: Stored tokens were cleared during retry delay');
        print('⚠️ Action: Cannot retry without tokens, forcing logout');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        await _forceCustomLogout();
        return;
      }

      // Check if tokens expired during retry delay (shouldn't happen with refresh token, but be safe)
      if (storedTokens.isExpired()) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('⚠️ LOGOUT REASON: TOKENS_EXPIRED_DURING_RETRY');
        print('⚠️ AuthService: Stored tokens expired during retry delay');
        print('⚠️ Action: Cannot retry with expired tokens, forcing logout');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        await _forceCustomLogout();
        return;
      }

      if (_customSession != null) {
        await _refreshCustomSession();
      }
    } else if (shouldRetry && _tokenRefreshAttempts >= _maxRefreshAttempts) {
      // Max retries exceeded after waiting
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('⚠️ LOGOUT REASON: MAX_RETRIES_EXCEEDED_AFTER_DELAY');
      print('⚠️ AuthService: All $_maxRefreshAttempts retry attempts failed');
      print('⚠️ Action: Force logout after exhausting all retries');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      await _forceCustomLogout();
    }
  }

  /// Set custom auth session and save to storage.
  ///
  /// ⚠️ CRITICAL: Must save immediately after token refresh!
  /// Uses atomic save to prevent partial state.
  Future<void> _setCustomSession(CustomAuthSession session) async {
    final oldRefreshToken = _customSession?.refreshToken;

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📝 _setCustomSession: Updating session');
    print('   Old refresh token: ${_tokenPreview(oldRefreshToken)}');
    print('   New refresh token: ${_tokenPreview(session.refreshToken)}');
    print('   New expires at: ${session.expiresAt}');

    _customSession = session;

    // CRITICAL: Verify assignment worked
    if (_customSession!.refreshToken != session.refreshToken) {
      throw Exception('CRITICAL: _customSession assignment failed!');
    }
    print('✓ In-memory session updated');

    // Use atomic save to prevent partial state
    final saved = await _tokenStorage.saveSession(
      CustomAuthTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        expiresAt: session.expiresAt,
      ),
      session.user,
    );

    if (!saved) {
      // Critical: tokens not saved, clear in-memory session
      _customSession = null;
      throw Exception('Failed to persist session to storage');
    }

    // CRITICAL: Read back from storage to verify
    final verifyTokens = await _tokenStorage.getTokens();
    if (verifyTokens == null) {
      throw Exception('CRITICAL: Tokens not in storage after save!');
    }
    if (verifyTokens.refreshToken != session.refreshToken) {
      throw Exception('CRITICAL: Storage contains wrong refresh token!');
    }
    print('✓ Storage verified: tokens match');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    notifyListeners();
  }

  /// Helper to preview token for logging (shows first/last 8 chars).
  String _tokenPreview(String? token) {
    if (token == null) return 'null';
    if (token.length < 16) return token;
    return '${token.substring(0, 8)}...${token.substring(token.length - 8)}';
  }

  /// Force logout for custom auth (security event).
  Future<void> _forceCustomLogout() async {
    _stopCustomSessionManagement();
    _customSession = null;
    await _tokenStorage.clearAll();

    _customAuthStateController.add(CustomAuthState(CustomAuthEvent.signedOut, null));

    // Clear app state
    await AnalyticsService().reset();
    FeedBuilderStateService().clear();
    FeedCacheService().clearCache();
    NewsService.clearCache();
    await SeenPostsService().clearSeenPosts();

    notifyListeners();

    _logSecurityEvent('CUSTOM_FORCE_LOGOUT_SUCCESS');
  }

  // Валидация пароля
  AuthResult _validatePassword(String password) {
    const minPasswordLength = 8;
    const requireUppercase = true;
    const requireLowercase = true;
    const requireNumbers = true;
    const requireSpecialChars = true;

    if (password.length < minPasswordLength) {
      return AuthResult(
        success: false,
        errorCode: AuthErrorCode.passwordTooShort,
      );
    }

    if (requireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      return AuthResult(success: false, errorCode: AuthErrorCode.passwordNeedsUppercase);
    }

    if (requireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      return AuthResult(success: false, errorCode: AuthErrorCode.passwordNeedsLowercase);
    }

    if (requireNumbers && !password.contains(RegExp(r'[0-9]'))) {
      return AuthResult(success: false, errorCode: AuthErrorCode.passwordNeedsNumbers);
    }

    if (requireSpecialChars && !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return AuthResult(success: false, errorCode: AuthErrorCode.passwordNeedsSpecialChars);
    }

    return AuthResult(success: true);
  }

  // Хеширование email для логирования (GDPR compliance)
  String _hashEmail(String email) {
    final bytes = utf8.encode(email.toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8); // Только первые 8 символов для логов
  }

  // Логирование событий безопасности
  void _logSecurityEvent(String event, [Map<String, dynamic>? metadata]) {
    const logSecurityEvents = true; // Always log security events for custom auth
    if (!logSecurityEvents) return;

    final level = _getLogLevelForEvent(event);
    final userId = currentUser != null ? _hashEmail(currentUser!.id) : null;
    final sessionId = currentSession?.user.id;

    LogService().log(
      level: level,
      event: event,
      flow: 'auth',
      userId: userId,
      sessionId: sessionId,
      metadata: metadata,
    );
  }

  // Map event names to log levels
  LogLevel _getLogLevelForEvent(String event) {
    if (event.contains('TOKEN_REUSED') || event.contains('CRITICAL')) {
      return LogLevel.critical;
    } else if (event.contains('ERROR') || event.contains('UNEXPECTED')) {
      return LogLevel.error;
    } else if (event.contains('FAILED') || event.contains('CANCELLED') || event.contains('TIMEOUT')) {
      return LogLevel.warning;
    } else if (event.contains('ATTEMPT') || event.contains('STARTED') || event.contains('REFRESH_ATTEMPT')) {
      return LogLevel.debug;
    } else {
      return LogLevel.info; // SUCCESS, SIGNED_IN, etc.
    }
  }

  // Вход через email и пароль
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) async {
    try {
      _logSecurityEvent('SIGN_IN_ATTEMPT', {'email_hash': _hashEmail(email)});
      await AnalyticsService().capture(EventSchema.userSignInAttempted, properties: {
        'provider': 'email',
        'method': 'password',
      });
      print('========================================');
      print('AuthService: Email/Password Sign-In Started');
      print('Email hash: ${_hashEmail(email)}');
      print('========================================');

      // TODO: Implement email/password sign-in with custom auth-service
      // For now, return not implemented error
      _logSecurityEvent('SIGN_IN_NOT_IMPLEMENTED', {'email_hash': _hashEmail(email)});
      return AuthResult(success: false, errorCode: AuthErrorCode.signInError);
    } catch (e) {
      _logSecurityEvent('SIGN_IN_UNEXPECTED_ERROR', {
        'email_hash': _hashEmail(email),
        'error': e.toString()
      });
      await AnalyticsService().capture(EventSchema.userSignInFailed, properties: {
        'provider': 'email',
        'error': e.toString(),
      });
      print('❌ Email sign-in ERROR (Unexpected)');
      print('   Error: $e');
      print('========================================');

      return AuthResult(success: false, errorCode: AuthErrorCode.unknownError);
    }
  }

  // Регистрация через email и пароль
  Future<AuthResult> createUserWithEmailAndPassword(String email, String password, {String? fullName}) async {
    try {
      // Валидация пароля
      final passwordValidation = _validatePassword(password);
      if (!passwordValidation.success) {
        print('❌ Password validation failed: ${passwordValidation.errorCode}');
        return passwordValidation;
      }

      _logSecurityEvent('SIGN_UP_ATTEMPT', {'email_hash': _hashEmail(email)});
      await AnalyticsService().capture(EventSchema.userSignInAttempted, properties: {
        'provider': 'email',
        'method': 'signup',
      });
      print('========================================');
      print('AuthService: Email/Password Sign-Up Started');
      print('Email hash: ${_hashEmail(email)}');
      print('========================================');

      // TODO: Implement email/password sign-up with custom auth-service
      // For now, return not implemented error
      _logSecurityEvent('SIGN_UP_NOT_IMPLEMENTED', {'email_hash': _hashEmail(email)});
      return AuthResult(success: false, errorCode: AuthErrorCode.signUpError);
    } catch (e) {
      _logSecurityEvent('SIGN_UP_UNEXPECTED_ERROR', {
        'email_hash': _hashEmail(email),
        'error': e.toString()
      });
      await AnalyticsService().capture(EventSchema.userSignInFailed, properties: {
        'provider': 'email',
        'error': e.toString(),
      });
      print('❌ Email sign-up ERROR (Unexpected)');
      print('   Error: $e');
      print('========================================');

      return AuthResult(success: false, errorCode: AuthErrorCode.unknownError);
    }
  }

  // OAuth вход через Google (нативный на iOS/Android)
  Future<AuthResult> signInWithGoogle() async {
    try {
      _logSecurityEvent('CUSTOM_OAUTH_SIGN_IN_ATTEMPT', {'provider': 'google'});
      await AnalyticsService().capture(EventSchema.userSignInAttempted, properties: {'provider': 'google'});

      // Step 1: Get id_token from native Google Sign In
      final clientId = Platform.isIOS
          ? '715376087095-b1rsvvumtrilroc1n6285j531rp81trh.apps.googleusercontent.com'
          : '715376087095-bl8qcgde9ck9bb747vrdtiuod8t2k9v4.apps.googleusercontent.com';
      final serverClientId = '715376087095-6hhrt2ha4qbhobv4lilrp4u8tsmho3uo.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: clientId,
        serverClientId: serverClientId,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        _logSecurityEvent('CUSTOM_OAUTH_SIGN_IN_CANCELLED', {'provider': 'google'});
        await AnalyticsService().capture(EventSchema.userSignInFailed, properties: {
          'provider': 'google',
          'error': 'cancelled',
        });
        return AuthResult(success: false, errorCode: AuthErrorCode.googleSignInCancelled);
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        _logSecurityEvent('CUSTOM_OAUTH_SIGN_IN_ERROR', {
          'provider': 'google',
          'error': 'no_id_token'
        });
        await AnalyticsService().capture(EventSchema.userSignInFailed, properties: {
          'provider': 'google',
          'error': 'no_id_token',
        });
        return AuthResult(success: false, errorCode: AuthErrorCode.googleNoIdToken);
      }

      // Step 2: Send id_token to custom auth-service
      final session = await _customAuthClient.signInWithGoogle(idToken);

      // Step 3: Save session
      await _setCustomSession(session);

      // Step 4: Start token management
      _startCustomSessionManagement();

      // Step 5: Fire auth event
      _customAuthStateController.add(CustomAuthState(
        CustomAuthEvent.signedIn,
        session,
      ));

      // Step 6: Identify user in analytics
      await AnalyticsService().identify(
        userId: session.user.id,
        properties: {
          'provider': 'google',
          'email_hash': _hashEmail(session.user.email),
        },
      );

      _logSecurityEvent('CUSTOM_OAUTH_SIGN_IN_SUCCESS', {'provider': 'google'});
      await AnalyticsService().capture(EventSchema.userSignedIn, properties: {'provider': 'google', 'method': 'oauth'});

      return AuthResult(success: true);
    } catch (e) {
      _logSecurityEvent('CUSTOM_OAUTH_SIGN_IN_ERROR', {
        'provider': 'google',
        'error': e.toString()
      });
      await AnalyticsService().capture(EventSchema.userSignInFailed, properties: {
        'provider': 'google',
        'error': e.toString(),
      });
      return AuthResult(success: false, errorCode: AuthErrorCode.googleSignInError);
    }
  }

  // Вход через Apple (нативный на iOS/macOS)
  Future<AuthResult> signInWithApple() async {
    try {
      _logSecurityEvent('CUSTOM_OAUTH_SIGN_IN_ATTEMPT', {'provider': 'apple'});
      await AnalyticsService().capture(EventSchema.userSignInAttempted, properties: {'provider': 'apple'});

      // Step 1: Get identity_token from native Sign in with Apple
      if (Platform.isIOS || Platform.isMacOS) {
        final available = await SignInWithApple.isAvailable();
        if (!available) {
          await AnalyticsService().capture(EventSchema.userSignInFailed, properties: {
            'provider': 'apple',
            'error': 'not_available',
          });
          return AuthResult(success: false, errorCode: AuthErrorCode.appleSignInError);
        }

        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        if (credential.identityToken == null) {
          _logSecurityEvent('CUSTOM_OAUTH_SIGN_IN_ERROR', {
            'provider': 'apple',
            'error': 'no_identity_token'
          });
          await AnalyticsService().capture(EventSchema.userSignInFailed, properties: {
            'provider': 'apple',
            'error': 'no_identity_token',
          });
          return AuthResult(success: false, errorCode: AuthErrorCode.appleSignInError);
        }

        // Step 2: Send identity_token to custom auth-service
        final session = await _customAuthClient.signInWithApple(credential.identityToken!);

        // Step 3: Save session
        await _setCustomSession(session);

        // Step 4: Start token management
        _startCustomSessionManagement();

        // Step 5: Fire auth event
        _customAuthStateController.add(CustomAuthState(
          CustomAuthEvent.signedIn,
          session,
        ));

        // Step 6: Identify user in analytics
        await AnalyticsService().identify(
          userId: session.user.id,
          properties: {
            'provider': 'apple',
            'email_hash': _hashEmail(session.user.email),
          },
        );

        _logSecurityEvent('CUSTOM_OAUTH_SIGN_IN_SUCCESS', {'provider': 'apple'});
        await AnalyticsService().capture(EventSchema.userSignedIn, properties: {'provider': 'apple', 'method': 'oauth'});

        return AuthResult(success: true);
      }

      // Not on Apple platform
      await AnalyticsService().capture(EventSchema.userSignInFailed, properties: {
        'provider': 'apple',
        'error': 'platform_not_supported',
      });
      return AuthResult(success: false, errorCode: AuthErrorCode.appleSignInError);
    } catch (e) {
      _logSecurityEvent('CUSTOM_OAUTH_SIGN_IN_ERROR', {
        'provider': 'apple',
        'error': e.toString()
      });
      await AnalyticsService().capture(EventSchema.userSignInFailed, properties: {
        'provider': 'apple',
        'error': e.toString(),
      });
      return AuthResult(success: false, errorCode: AuthErrorCode.appleSignInError);
    }
  }

  /// Вход через Magic Link (passwordless authentication)
  ///
  /// Отправляет email с ссылкой для входа без пароля.
  /// После клика по ссылке приложение автоматически авторизует пользователя.
  ///
  /// Email будет отправлен через SMTP сервер, настроенный на бэкенде.
  /// Ссылка будет вести на `makefeed://auth/callback`, который откроет приложение.
  ///
  /// [email] - Email адрес для отправки magic link
  Future<AuthResult> signInWithMagicLink(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      _logSecurityEvent('CUSTOM_MAGIC_LINK_ATTEMPT', {'email_hash': _hashEmail(email)});

      // Demo login for Apple App Store Review
      if (normalizedEmail == 'demo@infatium.ru') {
        return await _tryDemoLogin(normalizedEmail);
      }

      // Send magic link via custom auth-service
      await _customAuthClient.sendMagicLink(normalizedEmail);

      _logSecurityEvent('CUSTOM_MAGIC_LINK_SENT', {'email_hash': _hashEmail(email)});

      return AuthResult(
        success: true,
        messageKey: 'authMessageCheckEmailForLink',
      );
    } catch (e) {
      _logSecurityEvent('CUSTOM_MAGIC_LINK_ERROR', {
        'email_hash': _hashEmail(email),
        'error': e.toString()
      });

      if (e is CustomAuthException) {
        switch (e.code) {
          case AuthConfig.errorInvalidToken:
            return AuthResult(success: false, errorCode: AuthErrorCode.magicLinkInvalidEmail);
          default:
            return AuthResult(success: false, errorCode: AuthErrorCode.magicLinkSendError);
        }
      }

      return AuthResult(success: false, errorCode: AuthErrorCode.magicLinkError);
    }
  }

  /// Demo login for Apple App Store Review.
  ///
  /// Calls the /demo-login endpoint which returns a JWT session directly,
  /// bypassing the magic link email flow. Only works for whitelisted demo accounts.
  Future<AuthResult> _tryDemoLogin(String email) async {
    try {
      _logSecurityEvent('DEMO_LOGIN_ATTEMPT', {'email_hash': _hashEmail(email)});
      await AnalyticsService().capture(EventSchema.userSignInAttempted, properties: {
        'provider': 'demo',
        'method': 'demo_login',
      });

      final session = await _customAuthClient.demoLogin(email);

      // Save session
      await _setCustomSession(session);

      // Start token management
      _startCustomSessionManagement();

      // Fire auth event
      _customAuthStateController.add(CustomAuthState(
        CustomAuthEvent.signedIn,
        session,
      ));

      // Identify user in analytics
      await AnalyticsService().identify(
        userId: session.user.id,
        properties: {
          'provider': 'demo',
          'email_hash': _hashEmail(session.user.email),
        },
      );

      _logSecurityEvent('DEMO_LOGIN_SUCCESS', {'email_hash': _hashEmail(email)});
      await AnalyticsService().capture(EventSchema.userSignedIn, properties: {'provider': 'demo', 'method': 'demo_login'});

      return AuthResult(success: true);
    } catch (e) {
      _logSecurityEvent('DEMO_LOGIN_ERROR', {
        'email_hash': _hashEmail(email),
        'error': e.toString(),
      });
      await AnalyticsService().capture(EventSchema.userSignInFailed, properties: {
        'provider': 'demo',
        'error': e.toString(),
      });

      if (e is CustomAuthException) {
        if (e.code == AuthConfig.errorMissingToken || e.code == 'missing_email') {
          return AuthResult(success: false, errorCode: AuthErrorCode.demoLoginMissingToken);
        }
        if (e.statusCode != null && e.statusCode! >= 500) {
          return AuthResult(success: false, errorCode: AuthErrorCode.demoLoginConnectionError);
        }
        return AuthResult(success: false, errorCode: AuthErrorCode.demoLoginFailed);
      }

      return AuthResult(success: false, errorCode: AuthErrorCode.demoLoginConnectionError);
    }
  }

  /// Silent re-login for demo account when tokens expire.
  ///
  /// Called when demo refresh token fails (not in backend DB).
  /// Creates a new session without user interaction.
  Future<void> _silentDemoReLogin() async {
    final currentEmail = _customSession?.user.email;
    if (currentEmail == null || currentEmail != 'demo@infatium.ru') {
      throw Exception('Silent re-login only for demo accounts');
    }

    print('🔄 AuthService: Performing silent demo re-login...');

    // Call demo-login endpoint again (currentEmail is guaranteed non-null here)
    final session = await _customAuthClient.demoLogin(currentEmail);

    // Replace current session
    await _setCustomSession(session);

    // Restart token management
    _startCustomSessionManagement();

    // Fire auth event (silent, no navigation)
    _customAuthStateController.add(CustomAuthState(
      CustomAuthEvent.tokenRefreshed,
      session,
    ));

    _logSecurityEvent('DEMO_SILENT_RELOGIN_SUCCESS');
  }

  /// Handle magic link callback from deep link.
  ///
  /// Called by DeepLinkService when app is opened via makefeed://auth/callback?token=...
  ///
  /// [token] - Verification token from magic link email
  Future<AuthResult> handleMagicLinkCallback(String token) async {
    try {
      _logSecurityEvent('CUSTOM_MAGIC_LINK_CALLBACK', {});

      // Verify token with custom auth-service
      final session = await _customAuthClient.verifyMagicLink(token);

      // Save session
      await _setCustomSession(session);

      // Start token management
      _startCustomSessionManagement();

      // Fire auth event
      _customAuthStateController.add(CustomAuthState(
        CustomAuthEvent.signedIn,
        session,
      ));

      // Identify user in analytics
      await AnalyticsService().identify(
        userId: session.user.id,
        properties: {
          'provider': 'magiclink',
          'email_hash': _hashEmail(session.user.email),
        },
      );

      _logSecurityEvent('CUSTOM_MAGIC_LINK_SUCCESS', {});
      await AnalyticsService().capture(EventSchema.userSignedIn, properties: {'provider': 'email', 'method': 'magic_link'});

      return AuthResult(success: true);
    } catch (e) {
      _logSecurityEvent('CUSTOM_MAGIC_LINK_CALLBACK_ERROR', {
        'error': e.toString()
      });
      await AnalyticsService().capture(EventSchema.userSignInFailed, properties: {
        'provider': 'email',
        'error': e.toString(),
      });
      return AuthResult(success: false, errorCode: AuthErrorCode.magicLinkError);
    }
  }

  /// Check if token needs refresh and refresh if needed.
  ///
  /// Called on app resume from background. If the token is expired or
  /// about to expire (< 2 minutes remaining), refreshes immediately.
  /// Otherwise restarts the periodic timer.
  Future<void> refreshIfNeeded() async {
    if (_customSession == null) return;

    final timeUntilExpiry = _customSession!.expiresAt.difference(DateTime.now());
    print('AuthService: refreshIfNeeded - time until expiry: ${timeUntilExpiry.inSeconds}s');

    if (timeUntilExpiry < const Duration(minutes: 2)) {
      // Token expired or about to expire — refresh immediately
      print('AuthService: Token expired or expiring soon, refreshing now');
      await _refreshCustomSession();
    } else {
      // Token still valid — restart periodic timer
      print('AuthService: Token still valid, restarting timer');
      _startCustomSessionManagement();
    }
  }

  /// Handle app lifecycle changes.
  ///
  /// On paused: Check if token is expiring soon and proactively refresh before backgrounding.
  /// On resumed: Check how long app was paused and refresh if token is expiring soon.
  ///
  /// This prevents 401 errors when app is backgrounded for extended periods.
  ///
  /// IMPORTANT: This method is called from didChangeAppLifecycleState which is sync,
  /// so we can't make this method async. Instead, we schedule async operations.
  void handleAppLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      print('AuthService: App paused, stopping refresh timer');
      _appPausedAt = DateTime.now();
      print('AuthService: Pause timestamp: $_appPausedAt');

      // ⚠️ WARNING: If refresh is in progress, token save might fail
      if (_isRefreshing) {
        print('⚠️ AuthService: Warning - token refresh in progress during app pause');
        print('⚠️ If app terminates now, tokens may not be saved → potential 409 on next launch');
      }

      // Proactive refresh if token expiring soon (< 10 minutes)
      if (_customSession != null && !_isRefreshing) {
        final timeUntilExpiry = _customSession!.expiresAt.difference(DateTime.now());
        print('AuthService: Time until expiry: ${timeUntilExpiry.inMinutes}m ${timeUntilExpiry.inSeconds % 60}s');

        if (timeUntilExpiry < const Duration(minutes: 10)) {
          print('⚡ AuthService: Token expiring soon, refreshing proactively before pause');
          // Schedule async refresh (unawaited - runs in background)
          _refreshCustomSession().then((_) {
            print('✓ Proactive refresh completed before pause');
          }).catchError((e) {
            print('✗ Proactive refresh failed before pause: $e');
            // Continue with pause even if refresh fails
          });
        } else {
          print('AuthService: Token still valid for ${timeUntilExpiry.inMinutes} minutes, no proactive refresh needed');
        }
      } else if (_isRefreshing) {
        print('⚠️ AuthService: Refresh already in progress on pause, skipping proactive refresh');
      }

      _stopCustomSessionManagement();
    } else if (state == AppLifecycleState.resumed) {
      print('AuthService: App resumed, checking session validity');

      // Log how long app was backgrounded
      if (_appPausedAt != null) {
        final backgroundDuration = DateTime.now().difference(_appPausedAt!);
        print('AuthService: App was backgrounded for: ${backgroundDuration.inMinutes}m ${backgroundDuration.inSeconds % 60}s');
        _appPausedAt = null;
      }

      if (_customSession != null) {
        final timeUntilExpiry = _customSession!.expiresAt.difference(DateTime.now());
        print('AuthService: Time until expiry on resume: ${timeUntilExpiry.inMinutes}m ${timeUntilExpiry.inSeconds % 60}s');

        if (timeUntilExpiry < const Duration(minutes: 5)) {
          // Token expiring soon or already expired — immediate refresh
          // Check if refresh already in progress to avoid race condition
          if (_isRefreshing) {
            print('⚠️ AuthService: Refresh already in progress on resume, skipping duplicate');
            return;
          }

          print('⚡ AuthService: Token expiring soon on resume, refreshing immediately');
          // Schedule async refresh (unawaited - runs in background)
          _refreshCustomSession().then((_) {
            print('✓ Immediate refresh completed on resume');
          }).catchError((e) {
            print('✗ Immediate refresh failed on resume: $e');
          });
        } else {
          // Token still valid — restart normal timer
          print('AuthService: Token still valid, restarting timer');
          _startCustomSessionManagement();
        }
      }
    }
  }

  // Обновление сессии
  Future<AuthResult> refreshSession() async {
    // Custom auth handles refresh automatically via timer
    // Manual refresh can be triggered if needed
    await _refreshCustomSession();
    return AuthResult(success: _customSession != null);
  }

  // Выход
  Future<void> signOut() async {
    try {
      _logSecurityEvent('CUSTOM_SIGN_OUT_ATTEMPT');

      // Track analytics event before clearing session
      await AnalyticsService().capture(EventSchema.userLoggedOut);

      if (_customSession != null) {
        try {
          await _customAuthClient.logout(_customSession!.refreshToken);
        } catch (e) {
          _logSecurityEvent('CUSTOM_LOGOUT_ERROR', {'error': e.toString()});
          // Continue with local logout even if server call fails
        }
      }

      await _forceCustomLogout();

      _logSecurityEvent('CUSTOM_SIGN_OUT_SUCCESS');
    } catch (e) {
      _logSecurityEvent('CUSTOM_SIGN_OUT_ERROR', {'error': e.toString()});
    }
  }

  // Сброс пароля
  Future<AuthResult> resetPassword(String email) async {
    try {
      _logSecurityEvent('PASSWORD_RESET_ATTEMPT', {'email_hash': _hashEmail(email)});

      // TODO: Implement password reset with custom auth-service
      // For now, return not implemented error
      _logSecurityEvent('PASSWORD_RESET_NOT_IMPLEMENTED', {'email_hash': _hashEmail(email)});
      return AuthResult(success: false, errorCode: AuthErrorCode.passwordResetError);
    } catch (e) {
      _logSecurityEvent('PASSWORD_RESET_UNEXPECTED_ERROR', {
        'email_hash': _hashEmail(email),
        'error': e.toString()
      });
      return AuthResult(success: false, errorCode: AuthErrorCode.unknownError);
    }
  }

  // Изменение пароля
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      // Валидация нового пароля
      final passwordValidation = _validatePassword(newPassword);
      if (!passwordValidation.success) {
        return passwordValidation;
      }

      _logSecurityEvent('PASSWORD_UPDATE_ATTEMPT');

      // TODO: Implement password update with custom auth-service
      // For now, return not implemented error
      _logSecurityEvent('PASSWORD_UPDATE_NOT_IMPLEMENTED');
      return AuthResult(success: false, errorCode: AuthErrorCode.passwordUpdateError);
    } catch (e) {
      _logSecurityEvent('PASSWORD_UPDATE_UNEXPECTED_ERROR', {'error': e.toString()});
      return AuthResult(success: false, errorCode: AuthErrorCode.unknownError);
    }
  }

  // Обновление профиля пользователя
  Future<AuthResult> updateProfile({String? fullName, String? avatarUrl}) async {
    try {
      _logSecurityEvent('PROFILE_UPDATE_ATTEMPT');

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) {
        return AuthResult(success: false, errorCode: AuthErrorCode.noDataToUpdate);
      }

      // TODO: Implement profile update with custom auth-service
      // For now, return not implemented error
      _logSecurityEvent('PROFILE_UPDATE_NOT_IMPLEMENTED');
      return AuthResult(success: false, errorCode: AuthErrorCode.profileUpdateError);
    } catch (e) {
      _logSecurityEvent('PROFILE_UPDATE_UNEXPECTED_ERROR', {'error': e.toString()});
      return AuthResult(success: false, errorCode: AuthErrorCode.unknownError);
    }
  }

  // Удаление аккаунта
  Future<AuthResult> deleteAccount() async {
    try {
      _logSecurityEvent('ACCOUNT_DELETE_ATTEMPT');

      final user = currentUser;
      if (user == null) {
        return AuthResult(success: false, error: 'User not authenticated');
      }

      // DELETE /users/me API request
      final url = Uri.parse('${ApiConfig.baseUrl}/users/me');
      final response = await http.delete(
        url,
        headers: {
          ...ApiConfig.commonHeaders,
          'user-id': user.id,
          'Authorization': 'Bearer ${currentSession?.accessToken}',
        },
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        // Parse response to log deletion stats
        try {
          final data = json.decode(response.body);
          _logSecurityEvent('ACCOUNT_DELETE_SUCCESS', {
            'deleted_feeds': data['deleted_feeds'] ?? 0,
            'deleted_chats': data['deleted_chats'] ?? 0,
            'deleted_tags': data['deleted_tags'] ?? 0,
            'deleted_posts_seen': data['deleted_posts_seen'] ?? 0,
          });

          // Track analytics before signing out
          if (AnalyticsService().isInitialized) {
            AnalyticsService().capture(EventSchema.accountDeleted, properties: {
              'deleted_feeds': data['deleted_feeds'] ?? 0,
              'deleted_chats': data['deleted_chats'] ?? 0,
            });
          }
        } catch (e) {
          // Log parse error but continue with deletion
          if (kDebugMode) {
            print('Error parsing delete response: $e');
          }
        }

        // Sign out after successful deletion
        await signOut();
        return AuthResult(success: true, messageKey: 'authMessageAccountDeleted');
      } else {
        _logSecurityEvent('ACCOUNT_DELETE_FAILED', {
          'status_code': response.statusCode,
          'response': response.body,
        });
        return AuthResult(
          success: false,
          errorCode: AuthErrorCode.accountDeleteFailed,
        );
      }
    } on TimeoutException {
      _logSecurityEvent('ACCOUNT_DELETE_TIMEOUT');
      return AuthResult(success: false, errorCode: AuthErrorCode.networkError);
    } catch (e) {
      _logSecurityEvent('ACCOUNT_DELETE_ERROR', {'error': e.toString()});
      return AuthResult(success: false, errorCode: AuthErrorCode.accountDeleteError);
    }
  }

  // Проверка статуса email
  Future<bool> isEmailVerified() async {
    // Custom auth doesn't require email verification for OAuth
    // Magic link automatically verifies email
    return true;
  }

  // Повторная отправка подтверждения email
  Future<AuthResult> resendEmailConfirmation() async {
    try {
      if (currentUser?.email == null) {
        return AuthResult(success: false, errorCode: AuthErrorCode.userNotFound);
      }

      _logSecurityEvent('EMAIL_CONFIRMATION_RESEND_ATTEMPT');

      // TODO: Implement email confirmation resend with custom auth-service
      // For now, return not implemented error
      _logSecurityEvent('EMAIL_CONFIRMATION_RESEND_NOT_IMPLEMENTED');
      return AuthResult(success: false, errorCode: AuthErrorCode.emailConfirmationError);
    } catch (e) {
      _logSecurityEvent('EMAIL_CONFIRMATION_RESEND_ERROR', {'error': e.toString()});
      return AuthResult(success: false, errorCode: AuthErrorCode.emailConfirmationError);
    }
  }

  // Очистка ресурсов
  @override
  void dispose() {
    _stopCustomSessionManagement();
    _customAuthStateController.close();
    super.dispose();
  }
}

class AuthResult {
  final bool success;
  final String? error;
  final AuthErrorCode? errorCode;
  final String? message;
  final String? messageKey;
  final CustomAuthUser? user;
  final bool needsEmailConfirmation;

  AuthResult({
    required this.success,
    this.error,
    this.errorCode,
    this.message,
    this.messageKey,
    this.user,
    this.needsEmailConfirmation = false,
  });
}
