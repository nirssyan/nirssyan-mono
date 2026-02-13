/// Service for handling deep links (magic link callbacks and feed subscriptions).
///
/// This service listens for deep links in the formats:
/// - makefeed://auth/callback?token=...&type=magiclink (auth)
/// - makefeed://feed/{feedId} (feed subscription via custom scheme)
/// - https://infatium.ru/feed/{feedId} (feed subscription via universal link)
///
/// Used by custom auth-service for passwordless authentication
/// and for feed subscription via deep links.
library;

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:uni_links/uni_links.dart';
import '../config/auth_config.dart';
import '../app.dart';
import 'auth_service.dart';
import 'feed_builder_service.dart';
import 'news_service.dart';
import 'navigation_service.dart';
import 'locale_service.dart';
import 'analytics_service.dart';
import '../models/analytics_event_schema.dart';
import '../widgets/feed_preview_modal.dart';

/// Manages deep link detection and handling.
///
/// Singleton service that listens for app opens via makefeed:// URLs
/// and https://infatium.ru/ universal links.
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  StreamSubscription? _sub;
  bool _isInitialized = false;

  /// Pending feed deep link to process after authentication
  Uri? _pendingFeedLink;

  /// Whether there is a pending feed link waiting for auth
  bool get hasPendingFeedLink => _pendingFeedLink != null;

  /// Initialize deep link handling.
  ///
  /// Call this in app initialization (e.g., in main.dart or app.dart).
  void initialize() {
    if (_isInitialized) {
      print('DeepLinkService: Already initialized');
      return;
    }

    print('DeepLinkService: Initializing');

    // Listen for deep links while app is running
    _sub = uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        print('DeepLinkService: Received deep link: ${uri.toString()}');
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      print('DeepLinkService: Error listening to link stream: $err');
    });

    // Check for initial deep link (app opened from link)
    _checkInitialLink();

    _isInitialized = true;
  }

  /// Check if app was opened from a deep link.
  Future<void> _checkInitialLink() async {
    try {
      final initialUri = await getInitialUri();
      if (initialUri != null) {
        print('DeepLinkService: App opened with initial link: ${initialUri.toString()}');
        _handleDeepLink(initialUri);
      } else {
        print('DeepLinkService: No initial link found');
      }
    } catch (e) {
      print('DeepLinkService: Failed to get initial link: $e');
    }
  }

  /// Handle incoming deep link.
  ///
  /// Parses the URI and routes to appropriate handler.
  /// Supports both custom scheme (makefeed://) and universal links (https://infatium.ru/).
  void _handleDeepLink(Uri uri) {
    print('DeepLinkService: Handling deep link - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}');
    print('DeepLinkService: Query parameters: ${uri.queryParameters}');

    // Handle universal links (https://infatium.ru/feed/{feedId} or https://dev.infatium.ru/feed/{feedId})
    if (uri.scheme == 'https' && uri.host.contains('infatium.ru')) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty && pathSegments.first == 'feed' && pathSegments.length >= 2) {
        _handleFeedDeepLink(uri, linkType: 'universal');
        return;
      }
      print('DeepLinkService: Unknown universal link path: ${uri.path}');
      return;
    }

    // Handle custom scheme (makefeed://)
    if (uri.scheme != AuthConfig.deepLinkScheme) {
      print('DeepLinkService: Invalid scheme: ${uri.scheme} (expected: ${AuthConfig.deepLinkScheme})');
      return;
    }

    // Route based on host
    if (uri.host == AuthConfig.deepLinkHost) {
      // makefeed://auth/...
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty && pathSegments.first == AuthConfig.deepLinkPath) {
        _handleAuthCallback(uri);
      } else {
        print('DeepLinkService: Unknown auth path: ${uri.path}');
      }
    } else if (uri.host == 'feed') {
      // makefeed://feed/{feedId}
      _handleFeedDeepLink(uri, linkType: 'custom_scheme');
    } else {
      print('DeepLinkService: Unknown host: ${uri.host}');
    }
  }

  /// Handle authentication callback from magic link.
  ///
  /// Expected format: makefeed://auth/callback?token=...&type=magiclink
  void _handleAuthCallback(Uri uri) {
    final token = uri.queryParameters['token'];
    final type = uri.queryParameters['type'];

    print('DeepLinkService: Auth callback - type: $type, token: ${token != null ? 'present' : 'missing'}');

    if (token == null || token.isEmpty) {
      print('DeepLinkService: Error - Missing token in auth callback');
      return;
    }

    if (type != 'magiclink') {
      print('DeepLinkService: Warning - Unexpected type: $type (expected: magiclink)');
      // Continue anyway - token is what matters
    }

    // Call AuthService to verify token
    print('DeepLinkService: Calling AuthService.handleMagicLinkCallback()');
    AuthService().handleMagicLinkCallback(token).then((result) {
      if (result.success) {
        print('DeepLinkService: Magic link verified successfully');
      } else {
        print('DeepLinkService: Magic link verification failed: ${result.errorCode}');
      }
    }).catchError((error) {
      print('DeepLinkService: Error verifying magic link: $error');
    });
  }

  /// Handle feed deep link for subscription.
  ///
  /// Supported formats:
  /// - makefeed://feed/{feedId} (custom scheme)
  /// - https://infatium.ru/feed/{feedId} (universal link)
  void _handleFeedDeepLink(Uri uri, {required String linkType}) {
    // Extract feedId from path segments
    final pathSegments = uri.pathSegments;
    String? feedId;

    if (uri.scheme == 'https') {
      // Universal link: https://infatium.ru/feed/{feedId}
      // pathSegments: ['feed', '{feedId}']
      if (pathSegments.length >= 2 && pathSegments[0] == 'feed') {
        feedId = pathSegments[1];
      }
    } else {
      // Custom scheme: makefeed://feed/{feedId}
      // host = 'feed', pathSegments: ['{feedId}']
      if (pathSegments.isNotEmpty) {
        feedId = pathSegments.first;
      }
    }

    if (feedId == null || feedId.isEmpty) {
      print('DeepLinkService: Missing feedId in feed deep link');
      return;
    }

    print('DeepLinkService: Feed deep link - feedId: $feedId, linkType: $linkType');

    // Track analytics
    AnalyticsService().capture(EventSchema.feedDeepLinkOpened, properties: {
      'feed_id': feedId,
      'link_type': linkType,
    });

    // Check authentication
    if (!AuthService().isAuthenticated) {
      print('DeepLinkService: User not authenticated, saving pending feed link');
      _pendingFeedLink = uri;
      return;
    }

    // Process the feed link
    _processFeedLink(feedId);
  }

  /// Process pending feed deep link after authentication.
  ///
  /// Call this after user logs in and data is loaded.
  void processPendingFeedLink() {
    final uri = _pendingFeedLink;
    if (uri == null) return;

    _pendingFeedLink = null;
    print('DeepLinkService: Processing pending feed link: $uri');

    // Determine link type
    final linkType = uri.scheme == 'https' ? 'universal' : 'custom_scheme';

    // Extract feedId
    String? feedId;
    if (uri.scheme == 'https') {
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2 && pathSegments[0] == 'feed') {
        feedId = pathSegments[1];
      }
    } else {
      if (uri.host == 'feed' && uri.pathSegments.isNotEmpty) {
        feedId = uri.pathSegments.first;
      }
    }

    if (feedId == null || feedId.isEmpty) {
      print('DeepLinkService: Invalid pending feed link');
      return;
    }

    // Track analytics for pending link processing
    AnalyticsService().capture(EventSchema.feedDeepLinkOpened, properties: {
      'feed_id': feedId,
      'link_type': linkType,
      'was_pending': true,
    });

    _processFeedLink(feedId);
  }

  /// Load feed preview and show subscription modal.
  Future<void> _processFeedLink(String feedId) async {
    final navigatorState = MyApp.navigatorKey.currentState;
    if (navigatorState == null) {
      print('DeepLinkService: Navigator not available yet');
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _processFeedLink(feedId);
      });
      return;
    }

    final context = navigatorState.context;

    try {
      // Load feed preview
      final preview = await FeedBuilderService.getFeedPreviewByFeedId(feedId);

      // Check if navigator is still available
      if (MyApp.navigatorKey.currentState == null) return;

      // Show feed preview modal with subscription mode
      final result = await showCupertinoModalPopup<bool>(
        context: context,
        builder: (modalContext) => FeedPreviewModal(
          preview: preview,
          localeService: LocaleService(),
          isSubscriptionMode: true,
          onCreateFeed: () async {
            final success = await NewsService.subscribeFeed(feedId);
            if (success) {
              AnalyticsService().capture(EventSchema.feedSubscribed, properties: {
                'feed_id': feedId,
                'source': 'deep_link',
              });
            }
            return success;
          },
        ),
      );

      // Navigate to home if subscription was successful
      if (result == true) {
        NavigationService().navigateToHomeWithRefresh();
      }
    } catch (e) {
      print('DeepLinkService: Error processing feed link: $e');

      // Show error dialog
      if (MyApp.navigatorKey.currentState != null) {
        showCupertinoDialog(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: const Text('Could not load feed preview. Please try again later.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Dispose the service and cancel subscriptions.
  ///
  /// Call this in app disposal (e.g., in app.dart dispose()).
  void dispose() {
    print('DeepLinkService: Disposing');
    _sub?.cancel();
    _sub = null;
    _isInitialized = false;
  }

  /// Check if the service is initialized.
  bool get isInitialized => _isInitialized;
}
