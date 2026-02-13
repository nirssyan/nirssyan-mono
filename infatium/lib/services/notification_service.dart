import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/notification_config.dart';
import 'auth_service.dart';
import 'navigation_service.dart';
import 'analytics_service.dart';
import 'authenticated_http_client.dart';

/// Background message handler - MUST be top-level function.
///
/// Called when a push notification arrives while the app is in background
/// or terminated. Handles silent/data-only notifications.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background processing
  await Firebase.initializeApp();
  debugPrint('NotificationService: Background message: ${message.messageId}');
  debugPrint('NotificationService: Data: ${message.data}');
}

/// Service for managing push notifications via Firebase Cloud Messaging.
///
/// Handles:
/// - FCM token registration with backend
/// - Permission requests
/// - Foreground/background message handling
/// - Notification tap actions (deep linking)
///
/// Usage:
/// ```dart
/// // Initialize during app startup (after Firebase.initializeApp())
/// await NotificationService().initialize();
///
/// // Unregister on logout
/// await NotificationService().unregisterToken();
/// ```
class NotificationService extends ChangeNotifier {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AuthenticatedHttpClient _httpClient = AuthenticatedHttpClient();

  String? _deviceToken;
  bool _isInitialized = false;
  NotificationSettings? _settings;

  /// Current FCM device token (null if not obtained or no permission).
  String? get deviceToken => _deviceToken;

  /// Whether the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether the user has granted notification permission.
  bool get hasPermission =>
      _settings?.authorizationStatus == AuthorizationStatus.authorized ||
      _settings?.authorizationStatus == AuthorizationStatus.provisional;

  /// Initialize the notification service.
  ///
  /// Should be called after Firebase.initializeApp() in main.dart
  /// and during app initialization in app.dart.
  ///
  /// Safe to call multiple times - only initializes once.
  Future<void> initialize() async {
    if (!NotificationConfig.enableNotifications) {
      debugPrint('NotificationService: Disabled by feature flag');
      return;
    }

    if (_isInitialized) {
      debugPrint('NotificationService: Already initialized');
      return;
    }

    try {
      debugPrint('NotificationService: Initializing...');

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Request notification permission
      _settings = await _requestPermission();

      if (!hasPermission) {
        debugPrint('NotificationService: Permission denied by user');
        _isInitialized = true;
        notifyListeners();
        return;
      }

      // Get FCM token
      await _fetchToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_onTokenRefresh);

      // Setup foreground/background message handlers
      _setupMessageHandlers();

      // Check if app was opened from a notification
      await _checkInitialMessage();

      _isInitialized = true;
      notifyListeners();

      debugPrint('NotificationService: Initialized successfully');
      debugPrint('NotificationService: Token = $_deviceToken');
    } catch (e, stackTrace) {
      debugPrint('NotificationService: Initialization error: $e');
      debugPrint('NotificationService: Stack trace: $stackTrace');
      _isInitialized = true; // Mark as initialized to prevent retry loops
      notifyListeners();
    }
  }

  /// Request notification permission from the user.
  Future<NotificationSettings> _requestPermission() async {
    debugPrint('NotificationService: Requesting permission...');

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    debugPrint(
        'NotificationService: Permission status: ${settings.authorizationStatus}');
    return settings;
  }

  /// Fetch FCM token from Firebase.
  Future<void> _fetchToken() async {
    try {
      // On iOS, we need APNs token first
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint(
              'NotificationService: APNs token not available yet, will get FCM token via onTokenRefresh');
          // APNs token may not be available immediately
          // FCM token will come later via onTokenRefresh
          return;
        }
        debugPrint('NotificationService: APNs token obtained');
      }

      _deviceToken = await _messaging.getToken();
      debugPrint('NotificationService: FCM token obtained');

      if (_deviceToken != null) {
        await _registerTokenWithBackend(_deviceToken!);
      }
    } catch (e) {
      debugPrint('NotificationService: Error fetching token: $e');
    }
  }

  /// Handle FCM token refresh.
  ///
  /// Tokens can be refreshed by Firebase at any time.
  /// We need to re-register with backend when this happens.
  void _onTokenRefresh(String newToken) async {
    debugPrint('NotificationService: Token refreshed');
    _deviceToken = newToken;
    await _registerTokenWithBackend(newToken);
    notifyListeners();
  }

  /// Register device token with backend.
  ///
  /// Backend needs to know the device token to send targeted push notifications.
  /// This is called on:
  /// - Initial token fetch
  /// - Token refresh
  /// - User login (re-register for new user)
  Future<void> registerTokenWithBackend() async {
    if (_deviceToken == null) {
      debugPrint('NotificationService: No token to register');
      return;
    }
    await _registerTokenWithBackend(_deviceToken!);
  }

  Future<void> _registerTokenWithBackend(String token) async {
    final user = AuthService().currentUser;
    if (user == null) {
      debugPrint(
          'NotificationService: Cannot register token - user not authenticated');
      return;
    }

    try {
      debugPrint('NotificationService: Registering token with backend...');

      final deviceId = await _getOrCreateDeviceId();

      final response = await _httpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/device-tokens/'),
        headers: {
          ...ApiConfig.commonHeaders,
          'user-id': user.id,
          'Authorization':
              'Bearer ${AuthService().currentSession?.accessToken}',
        },
        body: jsonEncode({
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'device_id': deviceId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('NotificationService: Token registered with backend');
      } else {
        debugPrint(
            'NotificationService: Failed to register token: ${response.statusCode}');
        debugPrint('NotificationService: Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('NotificationService: Error registering token: $e');
    }
  }

  /// Unregister device token from backend.
  ///
  /// Call this when user logs out to stop receiving notifications
  /// for the previous user on this device.
  Future<void> unregisterToken() async {
    if (_deviceToken == null) {
      debugPrint('NotificationService: No token to unregister');
      return;
    }

    final user = AuthService().currentUser;
    final session = AuthService().currentSession;

    // We need valid auth to make the API call
    if (user == null || session == null) {
      debugPrint(
          'NotificationService: Cannot unregister - no active session');
      _deviceToken = null;
      notifyListeners();
      return;
    }

    try {
      debugPrint('NotificationService: Unregistering token from backend...');

      await _httpClient.delete(
        Uri.parse('${ApiConfig.baseUrl}/device-tokens/'),
        headers: {
          ...ApiConfig.commonHeaders,
          'user-id': user.id,
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'token': _deviceToken,
        }),
      );

      debugPrint('NotificationService: Token unregistered');
    } catch (e) {
      debugPrint('NotificationService: Error unregistering token: $e');
    }

    _deviceToken = null;
    notifyListeners();
  }

  /// Setup handlers for foreground and background messages.
  void _setupMessageHandlers() {
    // Foreground messages (app is open and visible)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // User tapped notification (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  /// Check if app was opened from a terminated state via notification.
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('NotificationService: App opened from terminated via notification');
      _handleNotificationTap(initialMessage);
    }
  }

  /// Handle foreground message.
  ///
  /// When app is open, system doesn't show notification automatically.
  /// We can show an in-app banner, snackbar, or use flutter_local_notifications.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('NotificationService: Foreground message received');
    debugPrint('NotificationService: Title: ${message.notification?.title}');
    debugPrint('NotificationService: Body: ${message.notification?.body}');
    debugPrint('NotificationService: Data: ${message.data}');

    // Silent update - no in-app UI shown when app is in foreground
  }

  /// Handle notification tap.
  ///
  /// Navigate to appropriate screen based on notification payload.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('NotificationService: Notification tapped');
    debugPrint('NotificationService: Data: ${message.data}');

    final data = message.data;

    // Route based on notification type
    // Payload structure is defined by backend
    if (data.containsKey('type')) {
      switch (data['type']) {
        case 'new_post':
          final feedId = data['feed_id'];
          if (feedId != null) {
            debugPrint('NotificationService: New post in feed: $feedId');
          }
          NavigationService().navigateToHome();
          break;

        case 'chat_message':
          // Navigate to feed creator tab (chat functionality removed)
          debugPrint('NotificationService: Navigating to feed creator');
          NavigationService().navigateToFeedCreator();
          break;

        default:
          // Unknown type - go to home
          debugPrint('NotificationService: Unknown type, going to home');
          NavigationService().navigateToHome();
      }
    } else {
      // No type specified - go to home
      NavigationService().navigateToHome();
    }
  }

  /// Get or create a unique device identifier.
  ///
  /// Used to distinguish between multiple devices for the same user.
  /// Stored in SharedPreferences for persistence across app restarts.
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('notification_device_id');

    if (deviceId == null) {
      // Generate a simple UUID-like identifier
      deviceId = _generateUuid();
      await prefs.setString('notification_device_id', deviceId);
      debugPrint('NotificationService: Generated new device ID: $deviceId');
    }

    return deviceId;
  }

  /// Generate a simple UUID v4.
  String _generateUuid() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return '${random.toRadixString(16)}-${DateTime.now().microsecond.toRadixString(16)}-${Platform.operatingSystem}';
  }
}
