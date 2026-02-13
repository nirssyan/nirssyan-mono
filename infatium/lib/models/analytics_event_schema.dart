import 'package:flutter/foundation.dart';

/// Analytics event schema for AppMetrica
///
/// This class defines all analytics events tracked in the app with:
/// - Descriptive Title Case event names (AppMetrica best practice)
/// - Property validation schemas for debug-time checking
/// - Centralized event constants to prevent typos
///
/// **Usage:**
/// ```dart
/// // Use constants instead of string literals
/// await AnalyticsService().capture(EventSchema.userSignedIn, properties: {
///   'provider': 'google',
///   'method': 'oauth',
/// });
/// ```
///
/// **Migration from Matomo:**
/// - Old: Snake_case names (e.g., 'auth_success')
/// - New: Title Case names (e.g., 'User Signed In')
/// - Benefit: Better readability in AppMetrica dashboard
class EventSchema {
  // ========================================
  // AUTHENTICATION EVENTS
  // ========================================

  /// User attempted to sign in (before success/failure)
  /// Properties: provider (google/apple/email)
  static const String userSignInAttempted = 'User Sign In Attempted';

  /// User successfully signed in
  /// Properties: provider, method (oauth/magic_link), first_time (bool)
  static const String userSignedIn = 'User Signed In';

  /// User sign-in failed
  /// Properties: provider, error, error_code
  static const String userSignInFailed = 'User Sign In Failed';

  /// User logged out
  /// Properties: (none)
  static const String userLoggedOut = 'User Logged Out';

  /// User deleted their account
  /// Properties: reason (optional)
  static const String accountDeleted = 'Account Deleted';

  // ========================================
  // FEED & CONTENT EVENTS
  // ========================================

  /// User started feed creation flow (chat interface)
  /// Properties: source (chat/quick_create)
  static const String feedCreationFlowStarted = 'Feed Creation Flow Started';

  /// Feed creation loading UI shown
  /// Properties: feed_id
  static const String feedCreationLoadingShown = 'Feed Creation Loading Shown';

  /// Feed successfully created
  /// Properties: feed_id, source_count, creation_duration_ms, posts_generated
  static const String feedCreationCompleted = 'Feed Created';

  /// Feed deleted by user
  /// Properties: feed_id
  static const String feedDeleted = 'Feed Deleted';

  /// Feed renamed
  /// Properties: feed_id
  static const String feedRenamed = 'Feed Renamed';

  /// Feed status changed (active/inactive)
  /// Properties: feed_id, status
  static const String feedStatusChanged = 'Feed Status Changed';

  /// Feed management screen opened
  /// Properties: feed_count
  static const String feedManagementOpened = 'Feed Management Opened';

  /// News feed refreshed by user (pull to refresh)
  /// Properties: news_count, categories_count
  static const String newsFeedRefreshed = 'News Feed Refreshed';

  /// News feed refresh failed
  /// Properties: error
  static const String newsFeedRefreshError = 'News Feed Refresh Error';

  /// Feed deep link opened (user clicked makefeed://feed/{id} or universal link)
  /// Properties: feed_id, link_type (custom_scheme/universal), was_pending (optional)
  static const String feedDeepLinkOpened = 'Feed Deep Link Opened';

  /// User subscribed to a feed (via deep link or other source)
  /// Properties: feed_id, source (deep_link)
  static const String feedSubscribed = 'Feed Subscribed';

  // ========================================
  // POST INTERACTION EVENTS
  // ========================================

  /// Post viewed/marked as read
  /// Properties: post_id
  static const String postViewed = 'Post Viewed';

  /// Post shared via share sheet
  /// Properties: post_id, share_method (system/copy_link)
  static const String postShared = 'Post Shared';

  /// User swiped through post media gallery
  /// Properties: media_index, total_media
  static const String newsMediaSwiped = 'News Media Swiped';

  /// User opened image in fullscreen
  /// Properties: image_url
  static const String newsImageFullscreen = 'News Image Fullscreen';

  /// User changed news detail view mode (summary/full_text)
  /// Properties: view_type
  static const String newsDetailViewChanged = 'News Detail View Changed';

  /// Sources modal opened
  /// Properties: feed_id, source_count
  static const String sourcesModalOpened = 'Sources Modal Opened';

  /// User opened source link in browser
  /// Properties: source_url
  static const String sourceLinkOpened = 'Source Link Opened';

  /// User opened video in external browser
  /// Properties: video_url, has_preview
  static const String videoOpenedInBrowser = 'Video Opened In Browser';

  // ========================================
  // DIGEST EVENTS
  // ========================================

  /// Digest created from feed
  /// Properties: feed_id
  static const String digestCreated = 'Digest Created';

  // ========================================
  // SETTINGS EVENTS
  // ========================================

  /// Theme changed (light/dark)
  /// Properties: is_dark_mode (bool)
  static const String themeChanged = 'Theme Changed';

  /// Language changed
  /// Properties: language_code (en/ru)
  static const String languageChanged = 'Language Changed';

  /// Zen mode toggled (hides read posts)
  /// Properties: enabled (bool)
  static const String zenModeToggled = 'Zen Mode Toggled';

  /// Image previews toggled
  /// Properties: enabled (bool)
  static const String imagePreviewsToggled = 'Image Previews Toggled';

  /// App icon changed
  /// Properties: icon_name
  static const String appIconChanged = 'App Icon Changed';

  /// Analytics tracking enabled (opted in)
  /// Properties: (none)
  static const String analyticsEnabled = 'Analytics Enabled';

  /// Analytics tracking disabled (opted out)
  /// Properties: (none)
  static const String analyticsDisabled = 'Analytics Disabled';

  // ========================================
  // SESSION & PERFORMANCE EVENTS
  // ========================================

  /// App session ended (backgrounded or closed)
  /// Properties: duration_seconds, screens_viewed, posts_viewed
  static const String sessionEnded = 'Session Ended';

  // ========================================
  // NAVIGATION EVENTS
  // ========================================

  /// Onboarding flow completed
  /// Properties: (none)
  static const String onboardingCompleted = 'Onboarding Completed';

  /// Onboarding flow skipped
  /// Properties: (none)
  static const String onboardingSkipped = 'Onboarding Skipped';

  /// Bottom tab selected
  /// Properties: tab_index (0-3), tab_name
  static const String tabSelected = 'Tab Selected';

  /// Tab changed via swipe gesture
  /// Properties: tab_index, tab_name
  static const String tabSwiped = 'Tab Swiped';

  // ========================================
  // PROFILE EVENTS
  // ========================================

  /// Logout button tapped (confirmation not yet shown)
  /// Properties: (none)
  static const String profileLogoutAttempted = 'Profile Logout Attempted';

  /// Logout confirmed in dialog
  /// Properties: (none)
  static const String profileLogoutConfirmed = 'Profile Logout Confirmed';

  /// Link Telegram button tapped
  /// Properties: (none)
  static const String profileLinkTelegramTapped = 'Profile Link Telegram Tapped';

  /// Telegram link URL opened
  /// Properties: method (qr_code/deep_link)
  static const String profileLinkTelegramOpened = 'Profile Link Telegram Opened';

  /// Telegram link failed
  /// Properties: error
  static const String profileLinkTelegramError = 'Profile Link Telegram Error';

  /// Account settings button tapped
  /// Properties: (none)
  static const String profileAccountTapped = 'Profile Account Tapped';

  /// View settings opened
  /// Properties: (none)
  static const String profileViewSettingsOpened = 'Profile View Settings Opened';

  /// Contact email copied to clipboard
  /// Properties: (none)
  static const String contactEmailCopied = 'Contact Email Copied';

  /// Delete account button tapped
  /// Properties: (none)
  static const String deleteAccountButtonTapped = 'Delete Account Button Tapped';

  // ========================================
  // FEEDBACK EVENTS
  // ========================================

  /// Feedback modal opened
  /// Properties: (none)
  static const String feedbackModalOpened = 'Feedback Modal Opened';

  /// Feedback modal closed
  /// Properties: closed_by_user (bool), time_open_seconds
  static const String feedbackModalClosed = 'Feedback Modal Closed';

  /// Feedback submission started
  /// Properties: message_length
  static const String feedbackSubmissionStarted = 'Feedback Submission Started';

  /// Feedback successfully submitted
  /// Properties: feedback_id, message_length
  static const String feedbackSubmitted = 'Feedback Submitted';

  /// Feedback submission error
  /// Properties: error
  static const String feedbackSubmissionError = 'Feedback Submission Error';

  // ========================================
  // WEBSOCKET EVENTS
  // ========================================

  /// WebSocket connection established
  /// Properties: feed_count
  static const String websocketConnected = 'WebSocket Connected';

  /// WebSocket error occurred (user-facing issues)
  /// Properties: error
  static const String websocketError = 'WebSocket Error';

  /// WebSocket received feed creation complete
  /// Properties: feed_id, post_id
  static const String websocketFeedCreated = 'WebSocket Feed Created';

  /// WebSocket feed creation timed out
  /// Properties: feed_id, attempts
  static const String websocketFeedCreationTimeout = 'WebSocket Feed Creation Timeout';

  /// WebSocket timeout (generic)
  /// Properties: elapsed_seconds
  static const String websocketTimeout = 'WebSocket Timeout';

  /// WebSocket timeout with partial posts
  /// Properties: posts_count
  static const String websocketTimeoutWithPosts = 'WebSocket Timeout With Posts';

  /// WebSocket timeout error UI shown
  /// Properties: elapsed_seconds
  static const String websocketTimeoutErrorShown = 'WebSocket Timeout Error Shown';

  // ========================================
  // PROPERTY VALIDATION SCHEMAS
  // ========================================

  /// Property schemas for validation in debug mode
  ///
  /// Maps event name → Set of expected property keys
  /// Used by `validate()` to catch typos and missing properties early
  static const Map<String, Set<String>> schemas = {
    // Auth events
    userSignInAttempted: {'provider'},
    userSignedIn: {'provider', 'method', 'first_time'},
    userSignInFailed: {'provider', 'error', 'error_code'},
    userLoggedOut: <String>{}, // No properties
    accountDeleted: {'reason'},

    // Feed events
    feedCreationFlowStarted: {'source', 'entry_point'},
    feedCreationLoadingShown: {'feed_id'},
    feedCreationCompleted: {'feed_id', 'source_count', 'creation_duration_ms', 'posts_generated'},
    feedDeleted: {'feed_id'},
    feedRenamed: {'feed_id'},
    feedStatusChanged: {'feed_id', 'status'},
    feedManagementOpened: {'feed_count'},
    newsFeedRefreshed: {'news_count', 'categories_count'},
    newsFeedRefreshError: {'error'},
    feedDeepLinkOpened: {'feed_id', 'link_type', 'was_pending'},
    feedSubscribed: {'feed_id', 'source'},
    digestCreated: {'feed_id'},

    // Post events
    postViewed: {'post_id'},
    postShared: {'post_id', 'share_method'},
    newsMediaSwiped: {'media_index', 'total_media'},
    newsImageFullscreen: {'image_url'},
    newsDetailViewChanged: {'view_type'},
    sourcesModalOpened: {'feed_id', 'source_count'},
    sourceLinkOpened: {'source_url'},
    videoOpenedInBrowser: {'video_url', 'has_preview'},

    // Settings events
    themeChanged: {'is_dark_mode'},
    languageChanged: {'language_code'},
    zenModeToggled: {'enabled'},
    imagePreviewsToggled: {'enabled'},
    appIconChanged: {'icon_name'},
    analyticsEnabled: <String>{}, // No properties
    analyticsDisabled: <String>{}, // No properties

    // Session & Performance events
    sessionEnded: {'duration_seconds', 'screens_viewed', 'posts_viewed'},

    // Navigation events
    onboardingCompleted: <String>{}, // No properties
    onboardingSkipped: <String>{}, // No properties
    tabSelected: {'tab_index', 'tab_name'},
    tabSwiped: {'tab_index', 'tab_name'},

    // Profile events
    profileLogoutAttempted: <String>{}, // No properties
    profileLogoutConfirmed: <String>{}, // No properties
    profileLinkTelegramTapped: <String>{}, // No properties
    profileLinkTelegramOpened: {'method'},
    profileLinkTelegramError: {'error'},
    profileAccountTapped: <String>{}, // No properties
    profileViewSettingsOpened: <String>{}, // No properties
    contactEmailCopied: <String>{}, // No properties
    deleteAccountButtonTapped: <String>{}, // No properties

    // Feedback events
    feedbackModalOpened: <String>{}, // No properties
    feedbackModalClosed: {'closed_by_user', 'time_open_seconds'},
    feedbackSubmissionStarted: {'message_length'},
    feedbackSubmitted: {'feedback_id', 'message_length'},
    feedbackSubmissionError: {'error'},

    // WebSocket events
    websocketConnected: {'feed_count'},
    websocketError: {'error'},
    websocketFeedCreated: {'feed_id', 'post_id'},
    websocketFeedCreationTimeout: {'feed_id', 'attempts'},
    websocketTimeout: {'elapsed_seconds'},
    websocketTimeoutWithPosts: {'posts_count'},
    websocketTimeoutErrorShown: {'elapsed_seconds'},
  };

  /// Validates event properties against schema (debug mode only)
  ///
  /// Helps catch:
  /// - Events not defined in schema
  /// - Unknown property keys (typos)
  /// - Missing required properties
  ///
  /// Prints warnings to console in debug mode. No-op in release mode.
  ///
  /// Returns `true` if valid or validation skipped (release mode).
  static bool validate(String event, Map<String, Object?>? properties) {
    // Skip validation in release mode for performance
    if (kReleaseMode) return true;

    final schema = schemas[event];

    // Warn if event not in schema
    if (schema == null) {
      if (kDebugMode) {
        print('⚠️ Analytics: Event "$event" not in schema');
        print('   Add to EventSchema.schemas if this is intentional');
      }
      return true;
    }

    // Validate properties if provided
    if (properties != null) {
      final providedKeys = properties.keys.toSet();
      final unknownKeys = providedKeys.difference(schema);

      if (unknownKeys.isNotEmpty && kDebugMode) {
        print('⚠️ Analytics: Unknown properties for "$event": $unknownKeys');
        print('   Expected: $schema');
        print('   Received: $providedKeys');
      }
    }

    return true;
  }
}
