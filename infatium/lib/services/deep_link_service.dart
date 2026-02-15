/// Service for handling deep links (magic link callbacks and feed subscriptions).
///
/// This service listens for deep links in the formats:
/// - makefeed://auth/callback?token=...&type=magiclink (auth)
/// - makefeed://feed/{feedId} (feed subscription via custom scheme)
/// - makefeed://marketplace/{slug} (marketplace feed via custom scheme)
/// - https://infatium.ru/feed/{feedId} (feed subscription via universal link)
/// - https://infatium.ru/marketplace/{slug} (marketplace feed via universal link)
///
/// Used by custom auth-service for passwordless authentication
/// and for feed subscription via deep links.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:app_links/app_links.dart';
import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import '../config/api_config.dart';
import '../config/auth_config.dart';
import '../app.dart';
import 'auth_service.dart';
import 'feed_builder_service.dart';
import 'news_service.dart';
import 'navigation_service.dart';
import 'locale_service.dart';
import 'analytics_service.dart';
import '../models/analytics_event_schema.dart';
import '../models/feed_builder_models.dart';
import '../widgets/feed_preview_modal.dart';

/// Manages deep link detection and handling.
///
/// Singleton service that listens for app opens via makefeed:// URLs
/// and https://infatium.ru/ universal links.
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late final AppLinks _appLinks;
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

    _appLinks = AppLinks();

    // Listen for all deep links (initial link from cold start + subsequent links)
    _sub = _appLinks.uriLinkStream.listen((Uri uri) {
      print('DeepLinkService: Received deep link: ${uri.toString()}');
      _handleDeepLink(uri);
    }, onError: (err) {
      print('DeepLinkService: Error listening to link stream: $err');
    });

    _isInitialized = true;
  }

  /// Handle incoming deep link.
  ///
  /// Parses the URI and routes to appropriate handler.
  /// Supports both custom scheme (makefeed://) and universal links (https://infatium.ru/).
  void _handleDeepLink(Uri uri) {
    print('DeepLinkService: Handling deep link - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}');
    print('DeepLinkService: Query parameters: ${uri.queryParameters}');

    // Report to AppMetrica for install attribution tracking
    AppMetrica.reportAppOpen(uri.toString());

    // Handle universal links (https://infatium.ru/... or https://dev.infatium.ru/...)
    if (uri.scheme == 'https' && uri.host.contains('infatium.ru')) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty && pathSegments.first == 'feed' && pathSegments.length >= 2) {
        _handleFeedDeepLink(uri, linkType: 'universal');
        return;
      }
      if (pathSegments.isNotEmpty && pathSegments.first == 'marketplace' && pathSegments.length >= 2) {
        _handleMarketplaceDeepLink(pathSegments[1], linkType: 'universal');
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
    } else if (uri.host == 'marketplace') {
      // makefeed://marketplace/{slug}
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        _handleMarketplaceDeepLink(pathSegments.first, linkType: 'custom_scheme');
      } else {
        print('DeepLinkService: Missing slug in marketplace deep link');
      }
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

  /// Handle marketplace deep link by resolving slug to feedId.
  ///
  /// Supported formats:
  /// - makefeed://marketplace/{slug} (custom scheme)
  /// - https://infatium.ru/marketplace/{slug} (universal link)
  void _handleMarketplaceDeepLink(String slug, {required String linkType}) {
    print('DeepLinkService: Marketplace deep link - slug: $slug, linkType: $linkType');

    // Track analytics
    AnalyticsService().capture(EventSchema.feedDeepLinkOpened, properties: {
      'slug': slug,
      'link_type': linkType,
      'source': 'marketplace',
    });

    // Check authentication
    if (!AuthService().isAuthenticated) {
      print('DeepLinkService: User not authenticated, saving pending marketplace link');
      // Store as makefeed://marketplace/{slug} for later processing
      _pendingFeedLink = Uri.parse('makefeed://marketplace/$slug');
      return;
    }

    _resolveMarketplaceSlug(slug);
  }

  /// Resolve marketplace slug via API, build preview from response, and show modal.
  Future<void> _resolveMarketplaceSlug(String slug) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/marketplace/$slug'),
        headers: ApiConfig.commonHeaders,
      );

      if (response.statusCode != 200) {
        print('DeepLinkService: Marketplace API returned ${response.statusCode} for slug: $slug');
        _showMarketplaceError();
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      print('DeepLinkService: Marketplace response for slug "$slug": ${data.keys}');

      final preview = _buildMarketplacePreview(data);
      _processMarketplaceFeedPreview(preview);
    } catch (e) {
      print('DeepLinkService: Error resolving marketplace slug: $e');
      _showMarketplaceError();
    }
  }

  /// Build a FeedPreview from marketplace API response data.
  FeedPreview _buildMarketplacePreview(Map<String, dynamic> data) {
    // Map marketplace sources to LocalizedItem list
    final sourcesJson = data['sources'] as List<dynamic>? ?? [];
    final sources = sourcesJson.map((s) {
      if (s is Map<String, dynamic>) {
        final name = (s['name'] as String?) ?? '';
        return LocalizedItem(
          en: name,
          ru: name,
          url: s['url'] as String?,
          type: s['type'] as String?,
        );
      }
      return LocalizedItem(en: s.toString(), ru: s.toString());
    }).toList();

    // Map views if present
    final viewsJson = data['views'] as List<dynamic>?;
    final views = viewsJson?.map((v) => LocalizedItem.fromJson(v)).toList();

    // Map filters if present
    final filtersJson = data['filters'] as List<dynamic>?;
    final filters = filtersJson?.map((f) => LocalizedItem.fromJson(f)).toList();

    return FeedPreview(
      name: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'SINGLE_POST',
      owner: FeedOwner(id: '', name: 'Infatium'),
      prompt: (data['story'] as String?) ?? '',
      sources: sources,
      views: views,
      filters: filters,
      digestIntervalHours: data['digest_interval_hours'] as int?,
    );
  }

  /// Show feed preview modal for a marketplace feed and handle subscription.
  Future<void> _processMarketplaceFeedPreview(FeedPreview preview) async {
    final navigatorState = MyApp.navigatorKey.currentState;
    if (navigatorState == null) {
      print('DeepLinkService: Navigator not available yet for marketplace preview');
      Future.delayed(const Duration(milliseconds: 500), () {
        _processMarketplaceFeedPreview(preview);
      });
      return;
    }

    final context = navigatorState.context;

    try {
      final result = await showCupertinoModalPopup<bool>(
        context: context,
        builder: (modalContext) => FeedPreviewModal(
          preview: preview,
          localeService: LocaleService(),
          isSubscriptionMode: true,
          onCreateFeed: () async {
            // Build SourceItem list from preview sources
            final sourceItems = preview.sources
                .where((s) => s.url != null && s.url!.isNotEmpty)
                .map((s) => SourceItem(
                      url: s.url!,
                      type: s.type ?? 'RSS',
                    ))
                .toList();

            if (sourceItems.isEmpty) {
              print('DeepLinkService: No valid sources in marketplace preview');
              return false;
            }

            // Determine feed type
            final feedType = preview.type.toUpperCase() == 'DIGEST'
                ? FeedType.DIGEST
                : FeedType.SINGLE_POST;

            // Create real feed via POST /feeds/create
            final response = await FeedBuilderService.createFeedDirect(
              name: preview.name,
              sources: sourceItems,
              feedType: feedType,
              digestIntervalHours: preview.digestIntervalHours,
            );

            if (response.success) {
              AnalyticsService().capture(EventSchema.feedSubscribed, properties: {
                'feed_id': response.feedId ?? '',
                'source': 'marketplace',
              });
            }

            return response.success;
          },
        ),
      );

      if (result == true) {
        NavigationService().navigateToHomeWithRefresh();
      }
    } catch (e) {
      print('DeepLinkService: Error processing marketplace feed preview: $e');

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

  /// Show error dialog for marketplace deep link failures.
  void _showMarketplaceError() {
    final navigatorState = MyApp.navigatorKey.currentState;
    if (navigatorState == null) return;

    showCupertinoDialog(
      context: navigatorState.context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: const Text('Could not find this feed. It may have been removed.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  /// Process pending feed deep link after authentication.
  ///
  /// Call this after user logs in and data is loaded.
  void processPendingFeedLink() {
    final uri = _pendingFeedLink;
    if (uri == null) return;

    _pendingFeedLink = null;
    print('DeepLinkService: Processing pending feed link: $uri');

    // Handle pending marketplace links (makefeed://marketplace/{slug})
    if (uri.host == 'marketplace' || (uri.scheme == 'https' && uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'marketplace')) {
      final slug = uri.host == 'marketplace'
          ? uri.pathSegments.firstOrNull
          : (uri.pathSegments.length >= 2 ? uri.pathSegments[1] : null);
      if (slug != null && slug.isNotEmpty) {
        AnalyticsService().capture(EventSchema.feedDeepLinkOpened, properties: {
          'slug': slug,
          'link_type': 'custom_scheme',
          'source': 'marketplace',
          'was_pending': true,
        });
        _resolveMarketplaceSlug(slug);
        return;
      }
      print('DeepLinkService: Invalid pending marketplace link');
      return;
    }

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
