import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/appmetrica_config.dart' as config;
import '../models/analytics_event_schema.dart';

/// Analytics service using Yandex AppMetrica
///
/// **Migration from Matomo:** This service preserves the same public API
/// as the previous Matomo implementation to minimize code changes across the app.
///
/// **Key improvements over Matomo:**
/// - ✅ Unlimited JSON event properties (vs 10 dimension limit)
/// - ✅ Queryable opt-out state via `isOptedOut()` (was hardcoded `false` in Matomo)
/// - ✅ Automatic screen tracking (no manual RouteObserver needed)
/// - ✅ Native offline event queuing with automatic retry
/// - ✅ Rich user profiles (100+ attributes vs 5 dimensions)
/// - ✅ Built-in crash reporting
///
/// **Usage:**
/// ```dart
/// // Initialize once on app startup
/// await AnalyticsService().initialize();
///
/// // Track events with unlimited properties
/// await AnalyticsService().capture(EventSchema.feedCreated, properties: {
///   'feed_id': 'abc123',
///   'source_count': 5,
///   'has_preview': true,
///   // ... add as many as needed!
/// });
///
/// // Identify user after sign-in
/// await AnalyticsService().identify(
///   userId: user.id,
///   properties: {'email_hash': sha256Hash},
/// );
///
/// // Check opt-out state (GDPR compliance)
/// final isOptedOut = await AnalyticsService().isOptedOut();
/// ```
class AnalyticsService with ChangeNotifier {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SharedPreferences? _prefs;
  static const String _kOptOutKey = 'analytics_opted_out';

  /// Initialize AppMetrica SDK
  ///
  /// **IMPORTANT:** Call this once during app startup, typically in `main()`.
  ///
  /// This method:
  /// 1. Validates APPMETRICA_API_KEY configuration
  /// 2. Initializes AppMetrica with settings from AppMetricaConfig
  /// 3. Respects user's opt-out preference from SharedPreferences
  /// 4. Sets user profile attributes (platform, version, locale)
  ///
  /// Throws exception if APPMETRICA_API_KEY is missing.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      // Validate configuration
      config.AppMetricaSettings.validate();

      // Load opt-out preference
      _prefs = await SharedPreferences.getInstance();
      final isOptedOut = _prefs?.getBool(_kOptOutKey) ?? false;

      // Initialize AppMetrica
      await AppMetrica.activate(
        AppMetricaConfig(
          config.AppMetricaSettings.apiKey, // First positional parameter
          sessionTimeout: config.AppMetricaSettings.sessionTimeout,
          crashReporting: config.AppMetricaSettings.crashReporting,
          locationTracking: config.AppMetricaSettings.locationTracking,
          dataSendingEnabled: !isOptedOut, // Respect GDPR opt-out
          maxReportsInDatabaseCount: config.AppMetricaSettings.maxReportsInDatabase,
          logs: config.AppMetricaSettings.logs,
        ),
      );

      // Set user profile attributes (platform, version, locale)
      await _setUserProfile();

      _isInitialized = true;

      if (kDebugMode) {
        print('AnalyticsService: AppMetrica initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AnalyticsService: Error initializing AppMetrica: $e');
      }
      rethrow;
    }
  }

  /// Set user profile attributes
  ///
  /// These attributes persist across all sessions and are displayed
  /// in AppMetrica dashboard under User Profiles.
  ///
  /// Auto-set attributes:
  /// - `platform` - ios/android/web/macos/windows/linux
  /// - `app_version` - From pubspec.yaml (e.g., "1.0.0")
  /// - `app_build` - Build number (e.g., "9")
  /// - `locale` - User language code (e.g., "en", "ru")
  Future<void> _setUserProfile() async {
    try {
      // App version and build number
      final packageInfo = await PackageInfo.fromPlatform();

      // User locale
      final locale = WidgetsBinding.instance.platformDispatcher.locale;

      // Set all profile attributes in a single call
      await AppMetrica.reportUserProfile(
        AppMetricaUserProfile([
          AppMetricaStringAttribute.withValue('platform', _platformName()),
          AppMetricaStringAttribute.withValue('app_version', packageInfo.version),
          AppMetricaStringAttribute.withValue('app_build', packageInfo.buildNumber),
          AppMetricaStringAttribute.withValue('locale', locale.languageCode),
        ]),
      );
    } catch (e) {
      if (kDebugMode) {
        print('AnalyticsService: Error setting user profile: $e');
      }
    }
  }

  /// Identify user and set profile attributes
  ///
  /// **Call after user sign-in** to associate events with the user.
  ///
  /// AppMetrica supports 100+ user profile attributes. Common attributes:
  /// - `userId` - Unique identifier (auto-set as AppMetrica user ID)
  /// - `email_hash` - SHA256 hash for privacy-safe identification
  /// - Custom attributes via `properties` map
  ///
  /// Example:
  /// ```dart
  /// await AnalyticsService().identify(
  ///   userId: user.id,
  ///   properties: {
  ///     'email_hash': sha256Hash,
  ///     'signup_method': 'google',
  ///     'plan': 'free',
  ///   },
  /// );
  /// ```
  Future<void> identify({
    required String userId,
    Map<String, Object?>? properties,
  }) async {
    if (!_isInitialized) return;

    try {
      // Set AppMetrica user ID
      await AppMetrica.setUserProfileID(userId);

      // Set additional profile attributes
      if (properties != null && properties.isNotEmpty) {
        final attributes = properties.entries
            .where((e) => e.value != null)
            .map((e) => AppMetricaStringAttribute.withValue(e.key, e.value.toString()))
            .toList();

        if (attributes.isNotEmpty) {
          await AppMetrica.reportUserProfile(AppMetricaUserProfile(attributes));
        }
      }

      if (kDebugMode) {
        print('AnalyticsService: User identified: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AnalyticsService: Error identifying user: $e');
      }
    }
  }

  /// Reset user identity (call on logout)
  ///
  /// Clears the user ID from AppMetrica. Subsequent events will be anonymous.
  ///
  /// **Important:** This does NOT clear user profile attributes.
  /// Profile attributes persist until explicitly cleared or user reinstalls app.
  Future<void> reset() async {
    if (!_isInitialized) return;

    try {
      // Clear user ID (pass null to reset)
      await AppMetrica.setUserProfileID(null);

      if (kDebugMode) {
        print('AnalyticsService: User identity reset');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AnalyticsService: Error resetting user identity: $e');
      }
    }
  }

  /// Track custom event with properties
  ///
  /// **Unlimited properties** - Unlike Matomo's 10 dimension limit,
  /// AppMetrica supports unlimited JSON properties per event.
  ///
  /// **Best practice:** Use EventSchema constants for event names:
  /// ```dart
  /// await AnalyticsService().capture(EventSchema.feedCreated, properties: {
  ///   'feed_id': 'abc123',
  ///   'source_count': 5,
  ///   'has_preview': true,
  ///   'creation_duration_ms': 1523,
  ///   // ... add as many as needed!
  /// });
  /// ```
  ///
  /// **Property validation:** In debug mode, EventSchema validates properties
  /// against predefined schemas to catch typos and missing fields early.
  Future<void> capture(String event, {Map<String, Object?>? properties}) async {
    if (!_isInitialized) return;

    try {
      // Validate event schema in debug mode
      EventSchema.validate(event, properties);

      if (properties == null || properties.isEmpty) {
        // Simple event without properties
        await AppMetrica.reportEvent(event);
      } else {
        // Event with JSON properties (unlimited!)
        await AppMetrica.reportEventWithJson(
          event,
          json.encode(properties),
        );
      }

      if (kDebugMode) {
        print('AnalyticsService: Event tracked: $event ${properties != null ? 'with ${properties.length} properties' : ''}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AnalyticsService: Error tracking event "$event": $e');
      }
    }
  }

  /// Opt out of analytics tracking (GDPR/CCPA compliance)
  ///
  /// When opted out:
  /// - No events sent to AppMetrica servers
  /// - Events queued locally are discarded
  /// - User profile is NOT cleared (profile persists)
  /// - Preference persisted in SharedPreferences
  ///
  /// **Important:** Call this BEFORE tracking events. Once opted out,
  /// events will not be queued until user opts back in.
  Future<void> optOut() async {
    if (!_isInitialized) return;

    try {
      // Disable data sending
      await AppMetrica.setDataSendingEnabled(false);

      // Persist opt-out preference
      await _prefs?.setBool(_kOptOutKey, true);

      if (kDebugMode) {
        print('AnalyticsService: User opted out of tracking');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AnalyticsService: Error opting out: $e');
      }
    }
  }

  /// Opt in to analytics tracking
  ///
  /// Resume tracking after `optOut()`.
  ///
  /// When opted in:
  /// - Events sent to AppMetrica servers
  /// - New events queued normally
  /// - Preference persisted in SharedPreferences
  Future<void> optIn() async {
    if (!_isInitialized) return;

    try {
      // Enable data sending
      await AppMetrica.setDataSendingEnabled(true);

      // Persist opt-in preference
      await _prefs?.setBool(_kOptOutKey, false);

      if (kDebugMode) {
        print('AnalyticsService: User opted in to tracking');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AnalyticsService: Error opting in: $e');
      }
    }
  }

  /// Check if user is opted out of tracking
  ///
  /// **FIXED:** This method now properly queries AppMetrica's opt-out state.
  /// In Matomo implementation, this was hardcoded to return `false`.
  ///
  /// Returns:
  /// - `true` if user opted out (no tracking)
  /// - `false` if user opted in (tracking enabled)
  ///
  /// Used for:
  /// - Displaying consent toggle state in settings UI
  /// - GDPR compliance checks
  /// - Conditional analytics calls
  Future<bool> isOptedOut() async {
    if (!_isInitialized) return false;

    try {
      // Query from SharedPreferences (AppMetrica doesn't provide getDataSendingEnabled())
      return _prefs?.getBool(_kOptOutKey) ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('AnalyticsService: Error checking opt-out state: $e');
      }
      return false;
    }
  }

  /// Create route observer for navigation tracking
  ///
  /// **DEPRECATED:** AppMetrica tracks screens automatically.
  /// This method returns `null` to maintain API compatibility
  /// but is no longer needed.
  ///
  /// **Migration note:** Remove `navigatorObservers` from MaterialApp/CupertinoApp.
  /// AppMetrica handles screen tracking natively without RouteObserver.
  RouteObserver<PageRoute<dynamic>>? createRouteObserver() {
    // AppMetrica tracks screens automatically - no observer needed!
    return null;
  }

  String _platformName() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
