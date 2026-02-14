import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../models/news_item.dart';
import '../models/feed_models.dart';
import '../models/feed_builder_models.dart'; // For FeedType enum
import 'news_detail_page.dart';
import '../services/locale_service.dart';
import '../services/news_service.dart';
import '../services/feed_management_service.dart';
import '../widgets/feed_management_overlay.dart';
import '../widgets/confirmation_modal.dart';
import '../widgets/glass_page_toggle.dart'; // For feed type tabs
import '../widgets/telegram_folder_tabs.dart'; // Telegram-style feed tabs
import '../l10n/generated/app_localizations.dart';

import '../services/analytics_service.dart';
import '../models/analytics_event_schema.dart';
import '../services/navigation_service.dart';
import 'package:flutter/services.dart';
import '../services/seen_posts_service.dart';
import '../services/zen_mode_service.dart';
import '../services/image_preview_service.dart';
import '../services/websocket_service.dart';
import '../services/feed_cache_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../widgets/funnel_animation_overlay.dart';
import '../widgets/particle_animation_overlay.dart';

// Modern refresh states for AAA-level UX
enum RefreshState {
  inactive,     // Not pulling
  pulling,      // User is pulling down
  ready,        // Pulled enough to trigger refresh
  refreshing,   // Currently refreshing data
  success,      // Refresh completed successfully
  error,        // Refresh failed
}

class MyHomePage extends StatefulWidget {
  final String title;
  final LocaleService localeService;
  final VoidCallback? onNavigateToChat;

  const MyHomePage({
    super.key,
    required this.title,
    required this.localeService,
    this.onNavigateToChat,
  });

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  late PageController _categoryPageController;
  late AnimationController _shimmerController;
  late AnimationController _refreshController;
  late AnimationController _refreshIconController;
  late AnimationController _refreshSuccessController;
  late AnimationController _stripeGlowController;
  late AnimationController _stripeFlickerController;

  // Feed type tabs state (Digests | Feeds)
  late PageController _feedTypePageController;
  int _currentFeedTypeTab = 0; // 0 = Feeds (regular), 1 = Digests
  late PageController _digestPageController;
  late PageController _regularFeedPageController;

  List<NewsItem> _allNewsItems = [];
  List<NewsItem> _filteredNewsItems = [];
  List<Feed> _categories = [];
  String? _selectedCategoryId; // null означает "Все"
  bool _isLoading = false;
  bool _hasError = false;

  // WebSocket feed creation tracking
  final WebSocketService _wsService = WebSocketService();
  String? _pendingFeedId;              // Feed ID waiting for first post
  String? _pendingFeedType;            // Feed type being created ("DIGEST" or "SINGLE_POST")
  bool _isWaitingForFeedCreation = false;  // Show loading overlay
  bool _isSelectingFeed = false;       // Prevent concurrent feed selections
  bool _feedCreationTimedOut = false;  // Show timeout error in post area
  bool _isBatchingUpdates = false;     // Suppress _onCacheChanged during feed creation
  bool _isHandlingRealtimePost = false; // Prevents _onFeedCreationComplete from doing setState while post is being fetched
  DateTime? _feedCreationStartTime;    // Track feed creation duration for analytics

  // Unread counts cache (feedId -> unread count)
  Map<String, int> _unreadCounts = {};

  // Getters for feeds filtered by type
  List<Feed> get _digestFeeds => _categories.where((f) => f.type == FeedType.DIGEST).toList();
  List<Feed> get _regularFeeds => _categories.where((f) => f.type == FeedType.SINGLE_POST).toList();
  List<Feed> get _currentTabFeeds => _currentFeedTypeTab == 0 ? _regularFeeds : _digestFeeds;
  
  // Modern refresh state management
  RefreshState _refreshState = RefreshState.inactive;
  bool _hasTriggeredPulling = false;
  bool _hasTriggeredReady = false;
  bool _hasTriggeredRefresh = false;

  // Map to store GlobalKeys for each feed tag
  final Map<String, GlobalKey> _feedTagKeys = {};

  // SeenPostsService instance
  final SeenPostsService _seenPostsService = SeenPostsService();

  // ZenModeService instance
  final ZenModeService _zenModeService = ZenModeService();

  // ImagePreviewService instance
  final ImagePreviewService _imagePreviewService = ImagePreviewService();

  // Timer for polling empty feeds
  Timer? _feedPollingTimer;

  // Summarize unseen posts feature
  bool _isSummarizingUnseen = false;
  final Map<String, GlobalKey> _postCardKeys = {};
  int _summarizeProcessedCount = 0;
  int _summarizeTotalCount = 0;
  String _summarizeStatusText = '';
  Set<String> _animatingPostIds = {};  // Posts currently animating (hidden from list)
  String? _summarizingFeedId;  // Feed currently being summarized (animation scoped to this feed)

  // Infinite scroll state for pagination
  final Map<String, bool> _isLoadingMorePosts = {};
  final Map<String, bool> _hasMorePosts = {};
  final Map<String, ScrollController> _feedScrollControllers = {};
  final Map<String, bool> _isInitialPostsLoading = {};  // Track initial posts loading per feed
  final Map<String, bool> _hasPostLoadError = {};  // Track per-feed errors
  final Map<String, DateTime> _postAppearTimes = {};  // Track when each post appeared for animation
  final Map<String, bool> _isLoadingPosts = {};  // Guard against double initial post loading
  bool _isOfflineMode = false;

  // Local particle animation widgets (replaces global Overlay)
  final List<Widget> _particleAnimations = [];

  @override
  void initState() {
    super.initState();

    // Initialize PageController for category swiping
    _categoryPageController = PageController(initialPage: 0);

    // Initialize feed type page controllers
    _feedTypePageController = PageController(initialPage: 0);
    _digestPageController = PageController(initialPage: 0);
    _regularFeedPageController = PageController(initialPage: 0);

    // Initialize animation controllers
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _refreshIconController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _refreshSuccessController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _stripeGlowController = AnimationController(
      duration: const Duration(milliseconds: 4500),
      vsync: this,
    )..repeat(reverse: true);

    _stripeFlickerController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    // Add listener for seen posts changes
    _seenPostsService.addListener(_onSeenPostsChanged);

    // Add listener for image preview settings changes
    _imagePreviewService.addListener(_onImagePreviewChanged);

    // Listen to WebSocket state changes
    _wsService.addListener(_onWebSocketStateChanged);

    // Listen to FeedCacheService for real-time post updates
    FeedCacheService().addListener(_onCacheChanged);

    // Pre-populate from cache immediately to avoid flash of empty state
    _loadFromCacheIfAvailable();

    _loadNews();
  }

  /// Handle cache changes (real-time post updates via WebSocket)
  void _onCacheChanged() {
    if (!mounted || _isBatchingUpdates) return;

    // Refresh current feed's posts from cache
    final currentFeedId = _selectedCategoryId;
    if (currentFeedId != null) {
      final cache = FeedCacheService();
      final cachedPosts = cache.getCachedPostsIgnoreExpiry(currentFeedId);
      if (cachedPosts != null) {
        // Find current feed
        final currentFeed = _categories.firstWhere(
          (f) => f.id == currentFeedId,
          orElse: () => _categories.first,
        );

        // Convert posts to NewsItems
        final newsItems = cachedPosts.posts
            .map((post) => NewsService.convertPostToNewsItem(post, currentFeed))
            .toList();

        setState(() {
          // Update allNewsItems for current feed
          _allNewsItems.removeWhere((item) => item.feedId == currentFeedId);
          _allNewsItems.addAll(newsItems);

          // Update filtered items
          _filteredNewsItems = _sortNewsBySeenStatus(
            newsItems.where((news) => news.feedId == currentFeedId).toList(),
          );

          _hasMorePosts[currentFeedId] = cachedPosts.hasMore;
        });
      }
    }
  }

  /// Initialize persistent WebSocket for real-time post updates
  void _initPersistentWebSocket(List<Feed> feeds) {
    if (feeds.isEmpty) return;

    final feedIds = feeds.map((f) => f.id).toSet();

    _wsService.connectPersistent(
      feedIds: feedIds,
      onPostCreated: _handleRealtimePostCreated,
    );
  }

  /// Handle new post received via WebSocket
  Future<void> _handleRealtimePostCreated(String feedId, String postId) async {
    print('[HomePage] Real-time post received: feedId=$feedId, postId=$postId');
    print('[HomePage] _pendingFeedId=$_pendingFeedId, _isWaitingForFeedCreation=$_isWaitingForFeedCreation');

    // Check if this is for a pending feed creation BEFORE await
    final isPendingFeedBefore = _pendingFeedId == feedId;
    if (isPendingFeedBefore) {
      print('[HomePage] This is for pending feed, setting _isHandlingRealtimePost flag');
      _isHandlingRealtimePost = true;  // Prevent _onFeedCreationComplete from doing setState
    }

    // Invalidate cache to ensure fresh data on next load
    FeedCacheService().invalidateFeedPosts(feedId);

    // Fetch full post data
    var post = await NewsService.fetchPostById(postId);

    // Retry once if views are empty (backend may still be generating them)
    if (post != null && post.views.isEmpty) {
      print('[HomePage] Views empty for post $postId, retrying in 2s...');
      await Future.delayed(const Duration(seconds: 2));
      final retryPost = await NewsService.fetchPostById(postId);
      if (retryPost != null && retryPost.views.isNotEmpty) {
        post = retryPost;
      }
    }

    if (post != null && mounted) {
      // Find feed for conversion
      final feed = _categories.firstWhere(
        (f) => f.id == feedId,
        orElse: () => Feed(id: feedId, name: 'Unknown', posts: [], createdAt: DateTime.now()),
      );
      final newsItem = NewsService.convertPostToNewsItem(post, feed);

      // Check CURRENT value after await (might have changed)
      final isPendingFeedNow = _pendingFeedId == feedId;
      print('[HomePage] After fetch: isPendingFeedBefore=$isPendingFeedBefore, isPendingFeedNow=$isPendingFeedNow');

      // Directly append to UI (no full reload)
      setState(() {
        if (!_allNewsItems.any((n) => n.id == newsItem.id)) {
          _allNewsItems.add(newsItem);
          if (_selectedCategoryId == feedId) {
            _filteredNewsItems = _sortNewsBySeenStatus(
              _allNewsItems.where((n) => n.feedId == feedId).toList(),
            );
          }
          if (newsItem.id != null) {
            _postAppearTimes[newsItem.id!] = DateTime.now();
          }
        }
        _unreadCounts[feedId] = (_unreadCounts[feedId] ?? 0) + 1;

        // Reset creation flags if this was the pending feed (check both before AND current)
        // Also reset if _isWaitingForFeedCreation is active - safety fallback
        final shouldResetFlags = isPendingFeedBefore || isPendingFeedNow || _isWaitingForFeedCreation;
        if (shouldResetFlags) {
          print('[HomePage] Resetting creation flags for feedId=$feedId (before=$isPendingFeedBefore, now=$isPendingFeedNow, waiting=$_isWaitingForFeedCreation)');
          _isWaitingForFeedCreation = false;
          _pendingFeedId = null;
          _pendingFeedType = null;
          _isInitialPostsLoading[feedId] = false;
        }
      });

      // Reset flags
      _isBatchingUpdates = false;
      _isHandlingRealtimePost = false;

      // Update cache (notifyListeners will be suppressed by _isBatchingUpdates check in _onCacheChanged)
      FeedCacheService().insertPost(feedId, post);

      print('[HomePage] Post appended to UI: ${post.title}');
    } else {
      // Fetch failed - reset flag so _onFeedCreationComplete can handle cleanup
      if (isPendingFeedBefore) {
        print('[HomePage] Fetch failed for pending feed, letting _onFeedCreationComplete handle cleanup');
        _isHandlingRealtimePost = false;
      }
      print('[HomePage] Failed to fetch post $postId');
    }
  }

  /// Load cached data immediately on init to avoid empty state flash
  void _loadFromCacheIfAvailable() {
    final cache = FeedCacheService();
    // Use IgnoreExpiry to get data even if TTL expired (stale-while-revalidate)
    final cachedFeeds = cache.getCachedFeedsIgnoreExpiry();

    if (cachedFeeds != null && cachedFeeds.isNotEmpty) {
      _categories = cachedFeeds;

      // Try to load cached posts for the first feed
      final firstFeed = cachedFeeds.first;
      _selectedCategoryId = firstFeed.id;

      final cachedPosts = cache.getCachedPostsIgnoreExpiry(firstFeed.id);
      if (cachedPosts != null && cachedPosts.posts.isNotEmpty) {
        final newsItems = cachedPosts.posts
            .map((post) => NewsService.convertPostToNewsItem(post, firstFeed))
            .toList();
        _allNewsItems = newsItems;
        _filteredNewsItems = _sortNewsBySeenStatus(newsItems);
        _hasMorePosts[firstFeed.id] = cachedPosts.hasMore;
      }
    }
  }

  void _onSeenPostsChanged() {
    // Refresh UI when seen posts change
    if (mounted) {
      setState(() {
        // Update unread counts for feeds with loaded posts
        // This ensures badges update in real-time as user views posts
        for (final feedId in _unreadCounts.keys.toList()) {
          final loadedCount = _allNewsItems
              .where((news) =>
                  news.feedId == feedId &&
                  !news.seen &&
                  !_seenPostsService.isPostSeen(news.id))
              .length;

          // Only update if we have loaded posts for this feed
          if (_allNewsItems.any((news) => news.feedId == feedId)) {
            _unreadCounts[feedId] = loadedCount;
          }
        }
      });
    }
  }

  void _onImagePreviewChanged() {
    // Refresh UI when image preview setting changes
    if (mounted) {
      setState(() {
        // The setState will trigger a rebuild with updated image preview visibility
      });
    }
  }

  void _onWebSocketStateChanged() {
    // WebSocket state changes don't require UI rebuild
    // Posts are already updated via _onCacheChanged listener
  }

  /// Show loading overlay immediately when user clicks "Create feed" (before API responds)
  /// This gives instant visual feedback that feed creation has started
  void showFeedCreationLoading({String? feedName, String? feedType}) {
    setState(() {
      _isWaitingForFeedCreation = true;
      _pendingFeedId = null; // feedId not yet known
      _pendingFeedType = feedType; // Store feed type to show correct loading UI
    });

    // If creating a digest, switch to Digests tab so user sees loading overlay
    if (feedType == 'DIGEST') {
      _feedTypePageController.animateToPage(
        1, // Tab 1 = Digests
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // Analytics (feedId not yet known at this stage)
    AnalyticsService().capture(EventSchema.feedCreationLoadingShown, properties: {
      'feed_id': '', // Will be tracked in updatePendingFeedId when API responds
    });
  }

  /// Update pending feed ID after API response and start WebSocket waiting
  /// Called after createFeedDirect() returns with the feedId
  Future<void> updatePendingFeedId(String feedId, {String? feedName, String? feedType}) async {
    print('[HomePage] updatePendingFeedId called with feedId: $feedId, feedType: $feedType');

    // Suppress _onCacheChanged during feed creation flow to avoid duplicate rebuilds
    _isBatchingUpdates = true;

    setState(() {
      _pendingFeedId = feedId;
    });

    try {
      // IMPORTANT: Start WebSocket waiting FIRST, before any async operations
      // This ensures the feedId is in _subscribedFeedIds when post_created arrives
      print('[HomePage] updatePendingFeedId: Starting WebSocket wait...');
      _wsService.waitForFeedCreation(
        feedId: feedId,
        onComplete: _onFeedCreationComplete,
        onTimeout: _onFeedCreationTimeout,
      );
      print('[HomePage] updatePendingFeedId: WebSocket wait started');

      // Refresh feeds to include the new one
      print('[HomePage] updatePendingFeedId: Refreshing feeds...');
      await _refreshFeeds(forceBackendRefresh: true, keepSelection: true);
      print('[HomePage] updatePendingFeedId: Feeds refreshed');

      if (!mounted) {
        print('[HomePage] updatePendingFeedId: NOT MOUNTED after refresh');
        return;
      }

      // Select the new feed
      print('[HomePage] updatePendingFeedId: Selecting feed...');
      await _selectFeedSafely(feedId);
      print('[HomePage] updatePendingFeedId: Feed selected');

      if (!mounted) {
        print('[HomePage] updatePendingFeedId: NOT MOUNTED after select');
        return;
      }

      // Load initial posts
      print('[HomePage] updatePendingFeedId: Loading initial posts...');
      if (_isLoadingPosts[feedId] != true) {
        await _loadInitialPosts(feedId);
      }
      print('[HomePage] updatePendingFeedId: Initial posts loaded');

    } catch (e) {
      print('[HomePage] updatePendingFeedId: ERROR: $e');
      _isBatchingUpdates = false;  // Reset flag on error
      setState(() {
        _isWaitingForFeedCreation = false;
        _pendingFeedId = null;
      });

      _onFeedCreationError(e.toString());
    }
    // NOTE: Don't reset _isBatchingUpdates here - it will be reset in _onFeedCreationComplete()
  }

  /// Wait for feed creation to complete via WebSocket
  Future<void> waitForFeedCreation(String feedId, {String? feedName, String? feedType}) async {
    // STEP 1: Set waiting state
    setState(() {
      _isWaitingForFeedCreation = true;
      _pendingFeedId = feedId;
    });

    try {
      // STEP 2: Start WebSocket waiting FIRST (before any async operations)
      // This ensures feedId is in _subscribedFeedIds when post_created arrives
      _wsService.waitForFeedCreation(
        feedId: feedId,
        onComplete: _onFeedCreationComplete,
        onTimeout: _onFeedCreationTimeout,
      );

      // STEP 3: Refresh feeds (with keepSelection to avoid interference)
      await _refreshFeeds(forceBackendRefresh: true, keepSelection: true);

      if (!mounted) return;

      // Verify feed was loaded
      final newFeed = _categories.firstWhere(
        (f) => f.id == feedId,
        orElse: () => throw Exception('Feed $feedId not found in backend response'),
      );

      // STEP 4: Select feed safely (with proper tab switching)
      await _selectFeedSafely(feedId);

      if (!mounted) return;

      // STEP 5: Load initial posts (with guard against double loading)
      // Initialize loading state if not present
      if (!_isLoadingPosts.containsKey(feedId)) {
        _isLoadingPosts[feedId] = false;
      }

      // Load posts if not already loading
      if (_isLoadingPosts[feedId] != true) {
        await _loadInitialPosts(feedId);
      }

      // Track feed creation start time for duration metrics
      _feedCreationStartTime = DateTime.now();

      // Analytics
      AnalyticsService().capture(EventSchema.feedCreationFlowStarted, properties: {
        'source': 'chat',
        'entry_point': 'home_fab', // FAB = Floating Action Button on home
      });

    } catch (e) {
      setState(() {
        _isWaitingForFeedCreation = false;
        _pendingFeedId = null;
      });

      _onFeedCreationError(e.toString());
      rethrow;
    }
  }

  /// Safely select a feed with proper tab switching and pageIndex calculation
  /// This method fixes race conditions by ensuring tab switch completes before calculating pageIndex
  Future<void> _selectFeedSafely(String feedId) async {
    // Guard: Prevent multiple simultaneous selections
    if (_isSelectingFeed) {
      return;
    }

    _isSelectingFeed = true;

    try {
      // STEP 1: Find feed in _categories
      final feed = _categories.firstWhere(
        (f) => f.id == feedId,
        orElse: () => throw Exception('Feed $feedId not found in categories'),
      );

      // STEP 2: Switch tab if needed
      final targetTab = feed.type == FeedType.DIGEST ? 1 : 0;
      if (_currentFeedTypeTab != targetTab) {
        setState(() {
          _currentFeedTypeTab = targetTab;
        });

        // Move the outer PageView to the correct tab (Feeds ↔ Digests)
        if (_feedTypePageController.hasClients) {
          _feedTypePageController.jumpToPage(targetTab);
        }

        // CRITICAL: Wait for setState() to complete
        await Future.delayed(Duration.zero);

        // Wait one more frame for _currentTabFeeds getter to update
        await WidgetsBinding.instance.endOfFrame;
      }

      // STEP 3: Calculate pageIndex AFTER tab switch
      final currentFeeds = _currentTabFeeds;
      final pageIndex = currentFeeds.indexWhere((f) => f.id == feedId);

      if (pageIndex < 0) {
        throw Exception('Feed $feedId not found in current tab after switch');
      }

      // STEP 4: Jump to page
      final controller = _currentFeedTypeTab == 0
          ? _regularFeedPageController
          : _digestPageController;

      if (controller.hasClients) {
        controller.jumpToPage(pageIndex);
      }

      // STEP 5: Update selected feed
      setState(() {
        _selectedCategoryId = feedId;
      });

      // Scroll tab bar to show selected feed
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToSelectedCategory();
        }
      });

    } catch (e) {
      rethrow;
    } finally {
      _isSelectingFeed = false;
    }
  }

  Future<void> _onFeedCreationComplete(String feedId) async {
    print('[HomePage] _onFeedCreationComplete called with feedId: $feedId');
    print('[HomePage] _isHandlingRealtimePost: $_isHandlingRealtimePost, _pendingFeedId: $_pendingFeedId');

    final existingPosts = _allNewsItems.where((n) => n.feedId == feedId).toList();
    print('[HomePage] Feed creation complete, posts in UI: ${existingPosts.length}');

    // If _handleRealtimePostCreated is currently fetching the post, let it handle the setState
    if (_isHandlingRealtimePost) {
      print('[HomePage] Skipping setState - _handleRealtimePostCreated is handling it');
      // Analytics only - track feed creation completion with metrics
      final durationMs = _feedCreationStartTime != null
          ? DateTime.now().difference(_feedCreationStartTime!).inMilliseconds
          : 0;
      AnalyticsService().capture(EventSchema.feedCreationCompleted, properties: {
        'feed_id': feedId,
        'source_count': 0,
        'creation_duration_ms': durationMs,
        'posts_generated': existingPosts.length,
      });
      _feedCreationStartTime = null; // Reset timer
      return;
    }

    // Fallback: reset flags if _handleRealtimePostCreated didn't handle it
    // (e.g., post fetch failed or no post_created event received)
    if (_pendingFeedId == feedId && mounted) {
      print('[HomePage] Fallback: resetting flags in _onFeedCreationComplete');
      setState(() {
        _isWaitingForFeedCreation = false;
        _pendingFeedId = null;
        _pendingFeedType = null;
        _isInitialPostsLoading[feedId] = false;
      });
      _isBatchingUpdates = false;
    } else {
      print('[HomePage] Skipping setState - flags already reset');
    }

    // Analytics - track feed creation completion with metrics
    final durationMs = _feedCreationStartTime != null
        ? DateTime.now().difference(_feedCreationStartTime!).inMilliseconds
        : 0;
    AnalyticsService().capture(EventSchema.feedCreationCompleted, properties: {
      'feed_id': feedId,
      'source_count': 0,
      'creation_duration_ms': durationMs,
      'posts_generated': existingPosts.length,
    });
    _feedCreationStartTime = null; // Reset timer
  }

  void _onFeedCreationError(String error) {
    _isBatchingUpdates = false;  // Reset flag on error
    if (!mounted) return;

    // Remove placeholder feed on error
    final feedIdToRemove = _pendingFeedId;
    setState(() {
      _isWaitingForFeedCreation = false;
      if (feedIdToRemove != null) {
        _categories = _categories.where((f) => f.id != feedIdToRemove).toList();
        // Select first feed if available
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id;
        }
      }
      _pendingFeedId = null;
      _pendingFeedType = null;
    });

    // Show error dialog with retry
    _showFeedCreationErrorDialog(error);
  }

  void _onFeedCreationTimeout() async {
    _isBatchingUpdates = false;  // Reset flag on timeout
    if (!mounted) return;

    // Track timeout event
    await AnalyticsService().capture(EventSchema.websocketTimeout, properties: {
      'elapsed_seconds': 60,
    });

    final feedId = _pendingFeedId;
    if (feedId == null) return;

    // Check if we already have posts for this feed
    final existingPosts = _allNewsItems.where((n) => n.feedId == feedId).toList();

    if (existingPosts.isNotEmpty) {
      // Timeout is OK - we already have posts loaded, backend is still generating more
      await AnalyticsService().capture(EventSchema.websocketTimeoutWithPosts, properties: {
        'posts_count': existingPosts.length,
      });

      // Just clear waiting state, no error shown
      setState(() {
        _isWaitingForFeedCreation = false;
        _pendingFeedId = null;
        _pendingFeedType = null;
      });
      return;
    }

    // No posts yet - this is a real timeout error
    await AnalyticsService().capture(EventSchema.websocketTimeoutErrorShown, properties: {
      'elapsed_seconds': 60,
    });

    // Show timeout error state (with refresh button in UI)
    setState(() {
      _isWaitingForFeedCreation = false;
      _pendingFeedId = null;
      _pendingFeedType = null;
      _feedCreationTimedOut = true;
    });
  }

  void _showFeedCreationErrorDialog(String error) {
    final l10n = AppLocalizations.of(context);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n?.error ?? 'Error'),
        content: Text(
          l10n?.connectionError ?? 'Could not connect to server. Check your internet connection.',
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(l10n?.cancel ?? 'Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _pendingFeedId = null;
              });
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(l10n?.retry ?? 'Retry'),
            onPressed: () {
              Navigator.of(context).pop();
              if (_pendingFeedId != null) {
                waitForFeedCreation(_pendingFeedId!);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showFeedCreationTimeoutDialog() {
    final l10n = AppLocalizations.of(context);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n?.timeout ?? 'Timeout'),
        content: Text(
          l10n?.feedCreationSlow ?? 'Feed creation is taking longer than usual. Try refreshing later.',
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(l10n?.cancel ?? 'Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _pendingFeedId = null;
              });
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(l10n?.retry ?? 'Retry'),
            onPressed: () {
              Navigator.of(context).pop();
              if (_pendingFeedId != null) {
                waitForFeedCreation(_pendingFeedId!);
              }
            },
          ),
        ],
      ),
    );
  }

  /// Sorts news items by seen status: unseen first, seen last
  /// Sorts by date (newest first) within each group
  List<NewsItem> _sortNewsBySeenStatus(List<NewsItem> newsItems) {
    final unseenNews = newsItems.where((news) {
      final isPostSeen = news.seen || _seenPostsService.isPostSeen(news.id);
      return !isPostSeen;
    }).toList();

    final seenNews = newsItems.where((news) {
      final isPostSeen = news.seen || _seenPostsService.isPostSeen(news.id);
      return isPostSeen;
    }).toList();

    // Sort both lists by publishedAt descending (newest first)
    unseenNews.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    seenNews.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return [...unseenNews, ...seenNews];
  }

  /// Sorts categories by unseen status: categories with unseen posts first, without unseen posts last
  /// Preserves original order within each group
  List<Feed> _sortCategoriesByUnseenStatus(List<Feed> categories) {
    // ✅ SIMPLE SORTING: Sort by created_at DESC (newest first)
    // No grouping by unseen status - newest feeds always appear first
    final sorted = List<Feed>.from(categories);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  // ============================================================
  // INFINITE SCROLL FOR POSTS PAGINATION
  // ============================================================

  /// Get or create scroll controller for a specific feed
  ScrollController _getOrCreateScrollController(String feedId) {
    if (!_feedScrollControllers.containsKey(feedId)) {
      final controller = ScrollController();
      _setupScrollListener(feedId, controller);
      _feedScrollControllers[feedId] = controller;
    }
    return _feedScrollControllers[feedId]!;
  }

  /// Setup scroll listener for infinite scroll
  void _setupScrollListener(String feedId, ScrollController controller) {
    controller.addListener(() {
      // Skip if already loading
      if (_isLoadingMorePosts[feedId] == true) return;
      // Skip if no more posts
      if (_hasMorePosts[feedId] == false) return;

      // Trigger load when 80% scrolled
      if (controller.position.pixels >= controller.position.maxScrollExtent * 0.8) {
        _loadMorePosts(feedId);
      }
    });
  }

  /// Load more posts for a specific feed using pagination
  Future<void> _loadMorePosts(String feedId) async {
    if (_isLoadingMorePosts[feedId] == true) return;

    final cache = FeedCacheService();
    final cursor = cache.getNextCursor(feedId);

    // If no cursor, we either haven't loaded yet or there's no more data
    if (cursor == null) {
      setState(() {
        _hasMorePosts[feedId] = false;
      });
      return;
    }

    setState(() {
      _isLoadingMorePosts[feedId] = true;
    });

    try {
      final response = await NewsService.fetchPostsPage(
        feedId: feedId,
        cursor: cursor,
      );

      if (response != null && mounted) {
        // Find the feed to get feed metadata for conversion
        final feed = _categories.firstWhere(
          (f) => f.id == feedId,
          orElse: () => Feed(
            id: feedId,
            name: 'Unknown',
            posts: [],
            createdAt: DateTime.now(),
          ),
        );

        // Convert new posts to NewsItems
        final newNewsItems = response.posts
            .map((post) => NewsService.convertPostToNewsItem(post, feed))
            .toList();

        setState(() {
          // Add new posts to allNewsItems (avoid duplicates)
          final existingIds = _allNewsItems.map((n) => n.id).toSet();
          for (final news in newNewsItems) {
            if (!existingIds.contains(news.id)) {
              _allNewsItems.add(news);
            }
          }

          // If this is the selected feed, update filtered items too
          if (feedId == _selectedCategoryId) {
            final existingFilteredIds = _filteredNewsItems.map((n) => n.id).toSet();
            for (final news in newNewsItems) {
              if (!existingFilteredIds.contains(news.id)) {
                _filteredNewsItems.add(news);
              }
            }
            // Re-sort by seen status
            _filteredNewsItems = _sortNewsBySeenStatus(_filteredNewsItems);
          }

          _hasMorePosts[feedId] = response.hasMore;
          _isLoadingMorePosts[feedId] = false;
        });
      } else {
        setState(() {
          _isLoadingMorePosts[feedId] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMorePosts[feedId] = false;
        });
      }
    }
  }

  /// Load initial posts for a feed (first page, no cursor)
  Future<void> _loadInitialPosts(String feedId, {bool forceRefresh = false}) async {
    // NEW GUARD: Prevent double loading
    if (_isLoadingPosts[feedId] == true && !forceRefresh) {
      return;
    }

    if (_isLoadingMorePosts[feedId] == true) return;

    // Set guard flag
    _isLoadingPosts[feedId] = true;

    try {
      final cache = FeedCacheService();

      // Check if we already have posts in UI state (unless forceRefresh)
      final existingPosts = _allNewsItems.where((n) => n.feedId == feedId).toList();

      // Check if we have stale posts in cache (even expired)
      final staleCache = cache.getCachedPostsIgnoreExpiry(feedId);
      final hasStalePosts = staleCache != null && staleCache.posts.isNotEmpty;

      // If we already have posts displayed and not forcing refresh, no need to load again
      if (existingPosts.isNotEmpty && !forceRefresh) {
        _isLoadingPosts[feedId] = false; // Clear guard flag on early exit
        return;
      }

      // If we have stale posts but not in UI, use them immediately (unless forcing refresh)
      if (hasStalePosts && !forceRefresh && existingPosts.isEmpty) {
        final feed = _categories.firstWhere(
          (f) => f.id == feedId,
          orElse: () => Feed(id: feedId, name: 'Unknown', posts: [], createdAt: DateTime.now()),
        );

        final newsItems = staleCache.posts
            .map((post) => NewsService.convertPostToNewsItem(post, feed))
            .toList();

        if (mounted) {
          setState(() {
            final existingIds = _allNewsItems.map((n) => n.id).toSet();
            for (final news in newsItems) {
              if (!existingIds.contains(news.id)) {
                _allNewsItems.add(news);
              }
            }

            if (feedId == _selectedCategoryId) {
              _filteredNewsItems = _sortNewsBySeenStatus(
                _allNewsItems.where((n) => n.feedId == feedId).toList(),
              );
            }

            _hasMorePosts[feedId] = staleCache.hasMore;
          });
        }
        _isLoadingPosts[feedId] = false; // Clear guard flag on early exit
        return;
      }

      // No posts anywhere (or forcing refresh) - need to load from API, show skeleton
      if (mounted) {
        setState(() {
          _isInitialPostsLoading[feedId] = true;
          _isLoadingMorePosts[feedId] = true;
          _hasPostLoadError[feedId] = false;  // Clear error on retry
        });
      }

      final response = await NewsService.fetchPostsPage(
        feedId: feedId,
        cursor: null, // null = first page
        forceRefresh: forceRefresh, // Pass forceRefresh to bypass cache
      );

      if (response != null && mounted) {
        // Find the feed to get feed metadata for conversion
        final feed = _categories.firstWhere(
          (f) => f.id == feedId,
          orElse: () => Feed(
            id: feedId,
            name: 'Unknown',
            posts: [],
            createdAt: DateTime.now(),
          ),
        );

        // Convert posts to NewsItems
        final newNewsItems = response.posts
            .map((post) => NewsService.convertPostToNewsItem(post, feed))
            .toList();

        setState(() {
          // If forcing refresh, replace existing posts for this feed
          if (forceRefresh) {
            _allNewsItems.removeWhere((n) => n.feedId == feedId);
          }

          // Add posts to allNewsItems and track appearance time for animation
          final existingIds = _allNewsItems.map((n) => n.id).toSet();
          final now = DateTime.now();
          for (final news in newNewsItems) {
            if (!existingIds.contains(news.id)) {
              _allNewsItems.add(news);
              final postId = news.id;
              if (postId != null) {
                _postAppearTimes[postId] = now; // Track when post appeared
              }
            }
          }

          // If this is the selected feed, update filtered items too
          if (feedId == _selectedCategoryId) {
            _filteredNewsItems = _sortNewsBySeenStatus(
              _allNewsItems.where((n) => n.feedId == feedId).toList(),
            );
          }

          _hasMorePosts[feedId] = response.hasMore;
          _isLoadingMorePosts[feedId] = false;
          _isInitialPostsLoading[feedId] = false;

          // ✅ If we were waiting for WebSocket (showing overlay) and got first post(s), hide overlay
          // BUT keep WebSocket connected to receive more posts as they're generated
          if (_isWaitingForFeedCreation && _pendingFeedId == feedId && newNewsItems.isNotEmpty) {
            _isWaitingForFeedCreation = false;
            // NOTE: Keep _pendingFeedId set and WebSocket connected for more posts!
          }
        });
      } else if (mounted) {
        setState(() {
          _isLoadingMorePosts[feedId] = false;
          _isInitialPostsLoading[feedId] = false;
          _hasPostLoadError[feedId] = true;  // Mark error when response is null
        });
      }
    } catch (e) {
      print('[HomePage] _loadInitialPosts: Error: $e');
      if (mounted) {
        setState(() {
          _isLoadingMorePosts[feedId] = false;
          _isInitialPostsLoading[feedId] = false;
          _hasPostLoadError[feedId] = true;  // Mark error on exception
        });
      }
    } finally {
      // Clear guard flag
      _isLoadingPosts[feedId] = false;
    }
  }

  /// Load posts for all digest feeds (for flat digest list view)
  Future<void> _loadDigestPosts() async {
    final feedsToLoad = _digestFeeds.where((feed) {
      // Skip if already loaded or loading
      if (_allNewsItems.any((item) => item.feedId == feed.id)) return false;
      if (_isInitialPostsLoading[feed.id] == true) return false;
      return true;
    }).toList();

    // Load all digest feeds IN PARALLEL (not sequentially)
    await Future.wait(
      feedsToLoad.map((feed) => _loadInitialPosts(feed.id)),
    );
  }

  /// Build loading indicator for infinite scroll
  Widget _buildLoadMoreIndicator(String feedId, bool isDark) {
    final isLoading = _isLoadingMorePosts[feedId] == true;
    final hasMore = _hasMorePosts[feedId] != false;

    if (!hasMore) {
      // No more posts indicator
      final l10n = AppLocalizations.of(context);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            l10n?.noMorePosts ?? 'No more posts',
            style: TextStyle(
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    if (!isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: LoadingAnimationWidget.threeArchedCircle(
          color: isDark ? AppColors.accent : AppColors.lightAccent,
          size: 32,
        ),
      ),
    );
  }

  /// Build offline banner when showing cached data
  Widget _buildOfflineBanner(bool isDark) {
    if (!_isOfflineMode) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: isDark ? Colors.orange.shade900 : Colors.orange.shade100,
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.wifi_slash,
              size: 16,
              color: isDark ? Colors.white : Colors.orange.shade900,
            ),
            const SizedBox(width: 8),
            Text(
              l10n?.offlineMode ?? 'Offline - showing cached data',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.orange.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Update offline mode state from cache service
  void _updateOfflineState() {
    final cache = FeedCacheService();
    if (_isOfflineMode != cache.isOffline) {
      setState(() {
        _isOfflineMode = cache.isOffline;
      });
    }
  }

  Future<void> _loadNews() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      // Загружаем новости и извлекаем категории
      final newsItems = await NewsService.fetchUserFeedsHTTP();

      // Fetch feeds data
      final categoriesRaw = await NewsService.getUserFeeds().catchError((e) {
        throw e;
      });

      // Extract unread counts from the same data (no additional API call needed!)
      final unreadCounts = NewsService.getUnreadCountsFromCache();

      // Устраняем дубликаты по id (показываем все ленты, даже пустые)
      final Map<String, Feed> unique = {};
      for (final c in categoriesRaw) {
        unique[c.id] = c;
      }
      final categories = _sortCategoriesByUnseenStatus(unique.values.toList());
      // Analytics: загрузка новостей (internal event - not in schema)
      AnalyticsService().capture(
        'news_loaded',
        properties: {
          'news_count': newsItems.length,
          'categories_count': categories.length,
        },
      );

      if (mounted) {
        setState(() {
          // Don't clear _allNewsItems - posts are loaded via _loadInitialPosts
          // Only update if we actually have new items (which we don't from fetchUserFeedsHTTP)
          if (newsItems.isNotEmpty) {
            _allNewsItems = newsItems;
          }
          _categories = categories;
          _unreadCounts = unreadCounts;
          // Автоматически выбираем первую категорию из текущего таба
          final currentFeeds = _currentTabFeeds;
          if (currentFeeds.isNotEmpty) {
            _selectedCategoryId = currentFeeds.first.id;
            // Use _allNewsItems (may have posts from previous load or cache)
            _filteredNewsItems = _sortNewsBySeenStatus(
              _allNewsItems
                  .where((news) => news.feedId == _selectedCategoryId)
                  .toList(),
            );

            // Sync appropriate PageController to first page and scroll to tag
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final controller = _currentFeedTypeTab == 0
                  ? _regularFeedPageController
                  : _digestPageController;
              if (controller.hasClients && mounted) {
                controller.jumpToPage(0);
              }
              if (mounted) {
                _scrollToSelectedCategory();
              }
            });
          } else if (categories.isNotEmpty) {
            // Если текущий таб пуст, но есть ленты в другом табе
            _selectedCategoryId = categories.first.id;
            _filteredNewsItems = _sortNewsBySeenStatus(
              _allNewsItems
                  .where((news) => news.feedId == _selectedCategoryId)
                  .toList(),
            );
          } else {
            _filteredNewsItems =
                _sortNewsBySeenStatus(_allNewsItems); // Если нет категорий, показываем все
          }
          // Don't clear _isLoading yet - posts still need to load
        });

        // Update offline state from cache
        _updateOfflineState();

        // Initialize persistent WebSocket for real-time post updates
        _initPersistentWebSocket(categories);

        // Start polling if there are empty feeds
        if (_hasEmptyFeeds()) {
          _startFeedPolling();
        }

        // Load initial posts for the selected feed (AWAIT to ensure posts load before clearing loading flag)
        if (_selectedCategoryId != null) {
          await _loadInitialPosts(_selectedCategoryId!);
        }

        // If starting on Digests tab, load all digest posts
        if (_currentFeedTypeTab == 1) {
          _loadDigestPosts();
        }

        // Only clear loading after posts are loaded
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e, stackTrace) {
      AnalyticsService().capture(
        'news_load_error',
        properties: {'error': e.toString()},
      );
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        // Update offline state from cache
        _updateOfflineState();
      }
    }
  }

  /// Modern refresh with AAA-level UX and smooth animations
  /// If selectCreatingFeed is true, automatically selects the feed being created
  Future<void> _refreshNews({bool selectCreatingFeed = false}) async {
    if (_refreshState == RefreshState.refreshing) return;

    // Set refreshing state and trigger animations
    setState(() {
      _refreshState = RefreshState.refreshing;
    });

    // Start refresh animation
    _refreshIconController.repeat();

    // Reset haptic triggers
    _hasTriggeredPulling = false;
    _hasTriggeredReady = false;
    _hasTriggeredRefresh = false;

    try {
      // Отладка: проверяем user ID
      NewsService.getCurrentUserId();

      final newsItems = await NewsService.fetchUserFeedsHTTP(forceRefresh: true);
      final categoriesRaw = await NewsService.getUserFeeds();

      final Map<String, Feed> unique = {};
      for (final c in categoriesRaw) {
        unique[c.id] = c;
      }
      final categories = _sortCategoriesByUnseenStatus(unique.values.toList());

      // Сохраняем выбранную категорию, если она существует и всё ещё актуальна
      String? nextSelectedCategoryId = _selectedCategoryId;

      // Если запрошен автовыбор создающегося фида, ищем его
      if (selectCreatingFeed) {
        final creatingFeed = categories.cast<Feed?>().firstWhere(
          (f) => f?.isCreatingFinished == false,
          orElse: () => null,
        );
        if (creatingFeed != null) {
          nextSelectedCategoryId = creatingFeed.id;
        }
      }

      if (nextSelectedCategoryId != null &&
          !categories.any((c) => c.id == nextSelectedCategoryId)) {
        nextSelectedCategoryId = categories.isNotEmpty
            ? categories.first.id
            : null;
      }
      if (nextSelectedCategoryId == null && categories.isNotEmpty) {
        nextSelectedCategoryId = categories.first.id;
      }

      // HOTFIX: Don't overwrite _allNewsItems with empty newsItems
      // fetchUserFeedsHTTP returns [] because posts are loaded separately via fetchPostsPage
      // Use _allNewsItems for filtering if newsItems is empty
      final itemsForFiltering = newsItems.isNotEmpty ? newsItems : _allNewsItems;

      List<NewsItem> nextFiltered;
      if (nextSelectedCategoryId != null) {
        nextFiltered = _sortNewsBySeenStatus(
          itemsForFiltering
              .where((news) => news.feedId == nextSelectedCategoryId)
              .toList(),
        );
      } else if (categories.isNotEmpty) {
        // Если выбранной нет, но есть непустые категории — выбираем первую
        nextSelectedCategoryId = categories.first.id;
        nextFiltered = _sortNewsBySeenStatus(
          itemsForFiltering
              .where((news) => news.feedId == nextSelectedCategoryId)
              .toList(),
        );
      } else {
        nextFiltered = _sortNewsBySeenStatus(itemsForFiltering);
      }

      if (mounted) {
        setState(() {
          // Only update _allNewsItems if we got new data
          if (newsItems.isNotEmpty) {
            _allNewsItems = newsItems;
          }
          _categories = categories;
          _selectedCategoryId = nextSelectedCategoryId;
          _filteredNewsItems = nextFiltered;
          _hasError = false;
          _refreshState = RefreshState.success;

          // Sync PageController to current selected category and scroll to tag
          if (nextSelectedCategoryId != null) {
            final currentFeeds = _currentTabFeeds;
            final pageIndex = currentFeeds.indexWhere((c) => c.id == nextSelectedCategoryId);
            if (pageIndex != -1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final controller = _currentFeedTypeTab == 0
                    ? _regularFeedPageController
                    : _digestPageController;
                if (controller.hasClients && mounted) {
                  controller.jumpToPage(pageIndex);
                }
                if (mounted) {
                  _scrollToSelectedCategory();
                }
              });
            }
          }
        });

        // Manage polling based on feed status
        if (_hasEmptyFeeds()) {
          _startFeedPolling();
        } else {
          _stopFeedPolling();
        }

        // Refresh posts for current feed (since fetchUserFeedsHTTP doesn't return posts)
        if (nextSelectedCategoryId != null) {
          _loadInitialPosts(nextSelectedCategoryId, forceRefresh: true);
        }
      }

      // Success animation
      _refreshIconController.stop();
      _refreshSuccessController.forward().then((_) {
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _refreshState = RefreshState.inactive;
              });
              _refreshSuccessController.reset();
            }
          });
        }
      });

      // Analytics: track successful refresh with business metrics
      AnalyticsService().capture(
        EventSchema.newsFeedRefreshed,
        properties: {
          'news_count': newsItems.length,
          'categories_count': categories.length,
        },
      );
    } catch (e) {
      // Analytics: track refresh errors for UX monitoring
      AnalyticsService().capture(
        EventSchema.newsFeedRefreshError,
        properties: {'error': e.toString()},
      );
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _refreshState = RefreshState.error;
        });
      }
      
      // Error animation and reset
      _refreshIconController.stop();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _refreshState = RefreshState.inactive;
          });
        }
      });
    }
  }

  /// Public method to refresh feeds from outside (e.g., after feed creation)
  /// If selectCreatingFeed is true, automatically selects the feed being created
  void refreshFeeds({bool selectCreatingFeed = false}) {
    _refreshNews(selectCreatingFeed: selectCreatingFeed);
  }

  void _filterNewsByCategory(String categoryId) {
    HapticFeedback.selectionClick();

    // Find the index of the selected category within the current tab's feeds
    final currentFeeds = _currentTabFeeds;
    final categoryIndex = currentFeeds.indexWhere((cat) => cat.id == categoryId);
    if (categoryIndex == -1) return;

    // Если та же категория выбрана - скроллим наверх текущей страницы
    if (_selectedCategoryId == categoryId) {
      _scrollToTop();
      return;
    }

    // Use the appropriate page controller based on current tab (0 = Feeds, 1 = Digests)
    final controller = _currentFeedTypeTab == 0 ? _regularFeedPageController : _digestPageController;

    // Animate to the selected page
    if (controller.hasClients) {
      controller.animateToPage(
        categoryIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }

    // Update selected category
    setState(() {
      _selectedCategoryId = categoryId;
      _feedCreationTimedOut = false; // Reset timeout flag when switching feeds
      _filteredNewsItems = _sortNewsBySeenStatus(
        _allNewsItems
            .where((news) => news.feedId == categoryId)
            .toList(),
      );
    });

    // Scroll to selected category tag after UI updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToSelectedCategory();
      }
    });

    // Load initial posts for selected category
    _loadInitialPosts(categoryId);

    // Analytics: выбор категории (internal event - not in schema)
    final selectedCategory = currentFeeds[categoryIndex];
    AnalyticsService().capture(
      'category_selected',
      properties: {
        'category_id': selectedCategory.id,
        'category_name': selectedCategory.name,
        'news_count': _filteredNewsItems.length,
        'tab': _currentFeedTypeTab == 0 ? 'digests' : 'feeds',
      },
    );
  }

  /// Обработчик свайпа между категориями
  void _onCategoryPageChanged(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _categories.length) return;

    final category = _categories[pageIndex];
    HapticFeedback.selectionClick();

    setState(() {
      _selectedCategoryId = category.id;
      _filteredNewsItems = _sortNewsBySeenStatus(
        _allNewsItems
            .where((news) => news.feedId == category.id)
            .toList(),
      );
    });

    // Scroll to selected category tag after UI updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToSelectedCategory();
      }
    });

    // Load initial posts for selected category
    _loadInitialPosts(category.id);

    // Analytics: свайп категории (internal event - not in schema)
    AnalyticsService().capture(
      'category_swiped',
      properties: {
        'category_id': category.id,
        'category_name': category.name,
        'news_count': _filteredNewsItems.length,
      },
    );
  }

  /// Плавно скроллит наверх списка
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Умно скроллит горизонтальный список тегов к текущему выбранному тегу
  /// Центрирует тег если он не крайний, иначе показывает у края
  void _scrollToSelectedCategory() {
    if (!_categoryScrollController.hasClients || _selectedCategoryId == null) {
      return;
    }

    // Находим индекс выбранной категории в текущем табе
    final currentFeeds = _currentTabFeeds;
    final selectedIndex = currentFeeds.indexWhere((c) => c.id == _selectedCategoryId);
    if (selectedIndex == -1) return;

    // Получаем GlobalKey выбранного тега
    final tagKey = _feedTagKeys[_selectedCategoryId];
    if (tagKey == null || tagKey.currentContext == null) return;

    // Получаем RenderBox для вычисления позиции и размера
    final RenderBox? renderBox = tagKey.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Получаем позицию тега относительно родительского ScrollView
    final tagPosition = renderBox.localToGlobal(Offset.zero).dx;
    final tagWidth = renderBox.size.width;
    final screenWidth = MediaQuery.of(context).size.width;

    // Вычисляем текущий offset скролла
    final currentScrollOffset = _categoryScrollController.offset;

    // Вычисляем желаемый offset для центрирования
    // offset = (позиция тега + текущий скролл) - (половина экрана) + (половина тега)
    final targetOffset = (tagPosition + currentScrollOffset) - (screenWidth / 2) + (tagWidth / 2);

    // Ограничиваем offset границами скролла
    final minScrollExtent = _categoryScrollController.position.minScrollExtent;
    final maxScrollExtent = _categoryScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(minScrollExtent, maxScrollExtent);

    // Плавно скроллим к нужной позиции
    _categoryScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Показывает кастомный оверлей для управления лентой
  void _showFeedManagementOverlay(Feed feed, GlobalKey tagKey) {
    // Analytics: feed management overlay opened
    AnalyticsService().capture(EventSchema.feedManagementOpened, properties: {
      'feed_count': _categories.length,
    });

    FeedManagementOverlay.show(
      context: context,
      sessionItemKey: tagKey,
      sessionTitle: feed.name,
      onDelete: () => _showDeleteFeedDialog(feed),
      onRename: () => _showRenameFeedDialog(feed),
      onReadAll: () => _markAllPostsAsRead(feed),
    );
  }

  /// Показывает диалог переименования ленты
  Future<void> _showRenameFeedDialog(Feed feed) async {
    final l10n = AppLocalizations.of(context)!;
    final newName = await ConfirmationModal.showTextInput(
      context: context,
      icon: CupertinoIcons.pencil,
      title: l10n.renameFeed,
      placeholder: l10n.enterNewName,
      confirmText: l10n.save,
      cancelText: l10n.cancel,
      initialText: feed.name,
      validator: (text) {
        if (text.isEmpty) {
          return l10n.feedNameRequired;
        }
        return null;
      },
    );

    if (newName != null) {
      await _performRenameFeed(feed, newName);
    }
  }

  /// Показывает диалог удаления ленты
  Future<void> _showDeleteFeedDialog(Feed feed) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await ConfirmationModal.showConfirmation(
      context: context,
      icon: CupertinoIcons.delete,
      title: l10n.confirmDeleteFeed,
      message: l10n.confirmDeleteFeedMessage,
      confirmText: l10n.delete,
      cancelText: l10n.cancel,
      isDestructive: true,
    );

    if (confirmed == true) {
      await _performDeleteFeed(feed);
    }
  }

  /// Отмечает все посты в ленте как прочитанные
  Future<void> _markAllPostsAsRead(Feed feed) async {
    final l10n = AppLocalizations.of(context)!;

    // Instantly mark all posts as read in UI (optimistic update)
    final markedPostIds = _markAllPostsAsReadOptimistically(feed.id);
    HapticFeedback.lightImpact();

    // Show instant feedback
    if (markedPostIds.isNotEmpty && mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.postsMarkedAsRead(markedPostIds.length)),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        // Silently fail snackbar display
      }
    }

    // Make API call in background
    try {
      final result = await NewsService.markAllPostsAsRead(feed.id);

      if (!mounted) return;

      final success = result['success'] ?? false;
      final markedCount = result['marked_count'] ?? 0;

      if (success && markedCount > 0) {
        // Analytics: track read all action (internal event - not in schema)
        AnalyticsService().capture(
          'feed_read_all',
          properties: {
            'feed_id': feed.id,
            'feed_name': feed.name,
            'marked_count': markedCount,
          },
        );
      } else if (!success) {
        // API failed - revert optimistic update
        _revertMarkAllPostsAsRead(feed.id, markedPostIds);
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorMarkingPostsAsRead),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Error - revert optimistic update
      if (mounted) {
        _revertMarkAllPostsAsRead(feed.id, markedPostIds);
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorMarkingPostsAsRead),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Instantly marks all posts in feed as read (optimistic update)
  /// Returns list of post IDs that were marked
  List<String> _markAllPostsAsReadOptimistically(String feedId) {
    final List<String> markedPostIds = [];

    setState(() {
      // Mark all news items in this feed as seen
      for (int i = 0; i < _allNewsItems.length; i++) {
        if (_allNewsItems[i].feedId == feedId && !_allNewsItems[i].seen) {
          final postId = _allNewsItems[i].id;
          if (postId != null) {
            markedPostIds.add(postId);
          }
          _allNewsItems[i] = NewsItem(
            feedId: _allNewsItems[i].feedId,
            id: _allNewsItems[i].id,
            title: _allNewsItems[i].title,
            subtitle: _allNewsItems[i].subtitle,
            content: _allNewsItems[i].content,
            imageUrl: _allNewsItems[i].imageUrl,
            mediaUrls: _allNewsItems[i].mediaUrls,
            mediaObjects: _allNewsItems[i].mediaObjects,
            source: _allNewsItems[i].source,
            publishedAt: _allNewsItems[i].publishedAt,
            category: _allNewsItems[i].category,
            link: _allNewsItems[i].link,
            sources: _allNewsItems[i].sources,
            seen: true, // Mark as seen
          );
        }
      }

      // Update filtered items if they match current category
      if (_selectedCategoryId == feedId) {
        for (int i = 0; i < _filteredNewsItems.length; i++) {
          if (_filteredNewsItems[i].feedId == feedId && !_filteredNewsItems[i].seen) {
            _filteredNewsItems[i] = NewsItem(
              feedId: _filteredNewsItems[i].feedId,
              id: _filteredNewsItems[i].id,
              title: _filteredNewsItems[i].title,
              subtitle: _filteredNewsItems[i].subtitle,
              content: _filteredNewsItems[i].content,
              imageUrl: _filteredNewsItems[i].imageUrl,
              mediaUrls: _filteredNewsItems[i].mediaUrls,
              mediaObjects: _filteredNewsItems[i].mediaObjects,
              source: _filteredNewsItems[i].source,
              publishedAt: _filteredNewsItems[i].publishedAt,
              category: _filteredNewsItems[i].category,
              link: _filteredNewsItems[i].link,
              sources: _filteredNewsItems[i].sources,
              seen: true, // Mark as seen
            );
          }
        }
      }

      // Reset unread count for this feed (optimistic update)
      _unreadCounts[feedId] = 0;
    });

    return markedPostIds;
  }

  /// Reverts optimistic update if API call fails
  void _revertMarkAllPostsAsRead(String feedId, List<String> postIds) {
    setState(() {
      // Revert all news items
      for (int i = 0; i < _allNewsItems.length; i++) {
        if (postIds.contains(_allNewsItems[i].id)) {
          _allNewsItems[i] = NewsItem(
            feedId: _allNewsItems[i].feedId,
            id: _allNewsItems[i].id,
            title: _allNewsItems[i].title,
            subtitle: _allNewsItems[i].subtitle,
            content: _allNewsItems[i].content,
            imageUrl: _allNewsItems[i].imageUrl,
            mediaUrls: _allNewsItems[i].mediaUrls,
            mediaObjects: _allNewsItems[i].mediaObjects,
            source: _allNewsItems[i].source,
            publishedAt: _allNewsItems[i].publishedAt,
            category: _allNewsItems[i].category,
            link: _allNewsItems[i].link,
            sources: _allNewsItems[i].sources,
            seen: false, // Revert to unseen
          );
        }
      }

      // Revert filtered items
      if (_selectedCategoryId == feedId) {
        for (int i = 0; i < _filteredNewsItems.length; i++) {
          if (postIds.contains(_filteredNewsItems[i].id)) {
            _filteredNewsItems[i] = NewsItem(
              feedId: _filteredNewsItems[i].feedId,
              id: _filteredNewsItems[i].id,
              title: _filteredNewsItems[i].title,
              subtitle: _filteredNewsItems[i].subtitle,
              content: _filteredNewsItems[i].content,
              imageUrl: _filteredNewsItems[i].imageUrl,
              mediaUrls: _filteredNewsItems[i].mediaUrls,
              mediaObjects: _filteredNewsItems[i].mediaObjects,
              source: _filteredNewsItems[i].source,
              publishedAt: _filteredNewsItems[i].publishedAt,
              category: _filteredNewsItems[i].category,
              link: _filteredNewsItems[i].link,
              sources: _filteredNewsItems[i].sources,
              seen: false, // Revert to unseen
            );
          }
        }
      }

      // Restore unread count for this feed
      _unreadCounts[feedId] = postIds.length;
    });
  }

  Future<void> _performRenameFeed(Feed feed, String newName) async {
    final originalName = feed.name; // Store original name for potential revert

    // Мгновенное обновление UI (optimistic update)
    _updateFeedNameOptimistically(feed.id, newName);
    HapticFeedback.lightImpact();

    // Параллельно отправляем запрос на бек
    final success = await NewsService.renameFeed(feed.id, newName);

    // Track analytics
    if (success) {
      AnalyticsService().capture(EventSchema.feedRenamed, properties: {
        'feed_id': feed.id,
      });
    }

    // Обрабатываем результат
    if (!mounted) return;
    if (success) {
      // Успешно - показываем уведомление, но НЕ обновляем весь список
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feed renamed successfully'),
          duration: const Duration(seconds: 2),
        ),
      );
      // НЕ вызываем _refreshNews() - UI уже обновлен оптимистично
    } else {
      // Ошибка - откатываем изменения
      _updateFeedNameOptimistically(feed.id, originalName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error renaming feed'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Instantly updates feed name in UI (optimistic update)
  void _updateFeedNameOptimistically(String feedId, String newName) {
    setState(() {
      // Update in categories list - это обновит sticky header теги
      for (int i = 0; i < _categories.length; i++) {
        if (_categories[i].id == feedId) {
          _categories[i] = Feed(
            id: _categories[i].id,
            name: newName,
            posts: _categories[i].posts,
            createdAt: _categories[i].createdAt,
            isCreatingFinished: _categories[i].isCreatingFinished,
          );
          break;
        }
      }

      // Update in news items
      for (int i = 0; i < _allNewsItems.length; i++) {
        if (_allNewsItems[i].feedId == feedId) {
          _allNewsItems[i] = NewsItem(
            feedId: _allNewsItems[i].feedId,
            id: _allNewsItems[i].id,
            title: _allNewsItems[i].title,
            subtitle: _allNewsItems[i].subtitle,
            content: _allNewsItems[i].content,
            imageUrl: _allNewsItems[i].imageUrl,
            mediaUrls: _allNewsItems[i].mediaUrls,
            source: newName, // Update source to new name
            publishedAt: _allNewsItems[i].publishedAt,
            category: newName, // Update category to new name
            link: _allNewsItems[i].link,
            sources: _allNewsItems[i].sources,
          );
        }
      }

      // Update filtered items if they match current category
      if (_selectedCategoryId == feedId) {
        for (int i = 0; i < _filteredNewsItems.length; i++) {
          if (_filteredNewsItems[i].feedId == feedId) {
            _filteredNewsItems[i] = NewsItem(
              feedId: _filteredNewsItems[i].feedId,
              id: _filteredNewsItems[i].id,
              title: _filteredNewsItems[i].title,
              subtitle: _filteredNewsItems[i].subtitle,
              content: _filteredNewsItems[i].content,
              imageUrl: _filteredNewsItems[i].imageUrl,
              mediaUrls: _filteredNewsItems[i].mediaUrls,
              source: newName,
              publishedAt: _filteredNewsItems[i].publishedAt,
              category: newName,
              link: _filteredNewsItems[i].link,
              sources: _filteredNewsItems[i].sources,
            );
          }
        }
      }
    });
    
    // Принудительно обновляем sticky header
    if (mounted) {
      setState(() {
        // Пустой setState для принудительного обновления sticky header
      });
    }
  }

  Future<void> _performDeleteFeed(Feed feed) async {
    // Optimistic update - instantly remove feed from UI
    _removeFeedOptimistically(feed.id);
    HapticFeedback.lightImpact();

    // Direct API call with proper await and error handling
    try {
      final success = await NewsService.deleteFeedSubscription(feed.id);
      if (success) {
        // Track analytics
        AnalyticsService().capture(EventSchema.feedDeleted, properties: {
          'feed_id': feed.id,
        });
        await _refreshFeeds();
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (error) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Instantly removes feed from UI (optimistic update)
  void _removeFeedOptimistically(String feedId) {
    // 1. Find index of deleted feed BEFORE removal
    final deletedIndex = _categories.indexWhere((c) => c.id == feedId);
    if (deletedIndex == -1) return;

    // 2. Calculate new selected feed and page index
    String? newSelectedId;
    int newPageIndex = 0;

    if (_categories.length > 1) {
      if (_selectedCategoryId == feedId) {
        // Deleting currently selected feed
        if (deletedIndex < _categories.length - 1) {
          // Not last - select next (it will take the same visual position)
          newSelectedId = _categories[deletedIndex + 1].id;
          newPageIndex = deletedIndex;
        } else {
          // Last - select previous
          newSelectedId = _categories[deletedIndex - 1].id;
          newPageIndex = deletedIndex - 1;
        }
      } else {
        // Deleting non-selected feed - keep current selection
        newSelectedId = _selectedCategoryId;
        final currentIndex = _categories.indexWhere((c) => c.id == _selectedCategoryId);
        // Adjust index if deleted feed was before current
        newPageIndex = deletedIndex < currentIndex ? currentIndex - 1 : currentIndex;
      }
    }

    // 3. Sync PageController BEFORE setState to prevent indicator jump
    if (newSelectedId != null && _categoryPageController.hasClients) {
      _categoryPageController.jumpToPage(newPageIndex);
    }

    setState(() {
      // Remove stale GlobalKey to prevent underline indicator issues
      _feedTagKeys.remove(feedId);

      // Remove from categories
      _categories.removeWhere((category) => category.id == feedId);

      // Remove from all news items
      _allNewsItems.removeWhere((news) => news.feedId == feedId);

      // Remove from filtered news items
      _filteredNewsItems.removeWhere((news) => news.feedId == feedId);

      // Update selected category
      if (_categories.isEmpty) {
        _selectedCategoryId = null;
        _filteredNewsItems = [];
      } else {
        _selectedCategoryId = newSelectedId;
        _filteredNewsItems = _sortNewsBySeenStatus(
          _allNewsItems.where((news) => news.feedId == _selectedCategoryId).toList(),
        );
      }
    });
  }

  /// Silently refreshes feeds without showing loading UI
  Future<void> _refreshFeeds({bool forceBackendRefresh = false, bool keepSelection = false}) async {
    try {
      // Step 1: Fetch feeds from HTTP (updates _lastFetchedData)
      // This MUST complete before getUserFeeds() to avoid race condition
      final newsItems = await NewsService.fetchUserFeedsHTTP(forceRefresh: forceBackendRefresh);

      // Step 2: Get feeds data
      // NOW getUserFeeds() will read from the updated _lastFetchedData
      final categoriesRaw = await NewsService.getUserFeeds();

      // Extract unread counts from the same data (no additional API call needed!)
      final unreadCounts = NewsService.getUnreadCountsFromCache();

      final Map<String, Feed> unique = {};
      for (final c in categoriesRaw) {
        unique[c.id] = c;
      }
      final categories = _sortCategoriesByUnseenStatus(unique.values.toList());

      // Сохраняем выбранную категорию, если она существует и всё ещё актуальна
      String? nextSelectedCategoryId = _selectedCategoryId;
      if (nextSelectedCategoryId != null &&
          !categories.any((c) => c.id == nextSelectedCategoryId)) {
        nextSelectedCategoryId = categories.isNotEmpty
            ? categories.first.id
            : null;
      }
      if (nextSelectedCategoryId == null && categories.isNotEmpty) {
        nextSelectedCategoryId = categories.first.id;
      }

      List<NewsItem> nextFiltered;
      if (nextSelectedCategoryId != null) {
        nextFiltered = _sortNewsBySeenStatus(
          newsItems
              .where((news) => news.feedId == nextSelectedCategoryId)
              .toList(),
        );
      } else if (categories.isNotEmpty) {
        nextSelectedCategoryId = categories.first.id;
        nextFiltered = _sortNewsBySeenStatus(
          newsItems
              .where((news) => news.feedId == nextSelectedCategoryId)
              .toList(),
        );
      } else {
        nextFiltered = _sortNewsBySeenStatus(newsItems);
      }

      if (mounted) {
        setState(() {
          // Only replace _allNewsItems if we got actual posts
          // fetchUserFeedsHTTP() returns [] (posts loaded via fetchPostsPage)
          // Don't clear existing posts!
          if (newsItems.isNotEmpty) {
            _allNewsItems = newsItems;
          }
          _categories = categories;
          _unreadCounts = unreadCounts;
          _hasError = false;

          // Cache already updated in NewsService.fetchUserFeedsHTTP()
          // No need to cache again here (would be redundant)

          // NEW: Only update selection if keepSelection is false
          if (!keepSelection) {
            _selectedCategoryId = nextSelectedCategoryId;
            _filteredNewsItems = nextFiltered;

            // Sync PageController to current selected category and scroll to tag
            if (nextSelectedCategoryId != null) {
              final currentFeeds = _currentTabFeeds;
              final pageIndex = currentFeeds.indexWhere((c) => c.id == nextSelectedCategoryId);
              if (pageIndex != -1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final controller = _currentFeedTypeTab == 0
                      ? _regularFeedPageController
                      : _digestPageController;
                  if (controller.hasClients && mounted) {
                    controller.jumpToPage(pageIndex);
                  }
                  if (mounted) {
                    _scrollToSelectedCategory();
                  }
                });
              }
            }
          }
        });

        // Update WebSocket subscription with current feeds
        final feedIds = categories.map((f) => f.id).toSet();
        _wsService.updateSubscribedFeeds(feedIds);
      }
    } catch (e) {
      // Silently fail - no UI feedback for errors
    }
  }

  @override
  void dispose() {
    _seenPostsService.removeListener(_onSeenPostsChanged);
    _imagePreviewService.removeListener(_onImagePreviewChanged);
    _wsService.removeListener(_onWebSocketStateChanged);
    FeedCacheService().removeListener(_onCacheChanged);
    // Note: Don't disconnect WebSocket here - it's managed at app level
    _feedPollingTimer?.cancel();
    _categoryPageController.dispose();
    _categoryScrollController.dispose();
    _feedTypePageController.dispose();
    _digestPageController.dispose();
    _regularFeedPageController.dispose();
    _shimmerController.dispose();
    _refreshController.dispose();
    _refreshIconController.dispose();
    _refreshSuccessController.dispose();
    _stripeGlowController.dispose();
    _stripeFlickerController.dispose();
    _scrollController.dispose();
    // Dispose all feed scroll controllers
    for (final controller in _feedScrollControllers.values) {
      controller.dispose();
    }
    _feedScrollControllers.clear();
    super.dispose();
  }

  String _getTimeAgo(DateTime dateTime, BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final l10n = AppLocalizations.of(context)!;

    if (difference.inHours < 1) {
      return l10n.minutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.hoursAgo(difference.inHours);
    } else {
      return l10n.daysAgo(difference.inDays);
    }
  }


  /// Get count of unseen posts for a specific feed
  int _getUnseenPostCountForFeed(String feedId) {
    // First, check if we have a cached count from backend
    if (_unreadCounts.containsKey(feedId)) {
      return _unreadCounts[feedId]!;
    }

    // Fallback: count from loaded posts (for currently selected feed)
    return _allNewsItems
        .where((news) =>
            news.feedId == feedId &&
            !news.seen &&
            !_seenPostsService.isPostSeen(news.id))
        .length;
  }


  void _openNewsDetail(NewsItem news) {
    // Analytics: открытие карточки новости (internal event - not in schema)
    AnalyticsService().capture(
      'news_opened',
      properties: {
        'news_id': news.id,
        'source': news.source,
        'category': news.category,
        'has_image': news.imageUrl.startsWith('http'),
      },
    );
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (context) => NewsDetailPage(news: news)),
    );
  }


  Widget _buildNewsCard(NewsItem news, int index, bool isDark, {String? feedId}) {
    // Hide card if it's currently animating (flying to placeholder)
    // Only hide in the feed being summarized, not all feeds
    if (news.id != null &&
        _animatingPostIds.contains(news.id) &&
        feedId == _summarizingFeedId) {
      return const SizedBox.shrink();
    }

    // Assign GlobalKey for animation tracking (summarize feature)
    if (news.id != null && !_postCardKeys.containsKey(news.id)) {
      _postCardKeys[news.id!] = GlobalKey();
    }
    final cardKey = news.id != null ? _postCardKeys[news.id] : null;

    final primaryTextColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
    final cardBackground = isDark ? AppColors.surface : AppColors.lightSurface;

    // Check if post is seen (combine server status with local cache)
    final bool isPostSeen = news.seen || _seenPostsService.isPostSeen(news.id);

    // Subtle opacity for seen posts
    final double cardOpacity = isPostSeen ? 0.88 : 1.0;
    final Color accentColor = isDark ? AppColors.accent : AppColors.lightAccent;

    // Проверяем, есть ли реальная картинка (с приоритетом mediaObjects)
    String? previewImageUrl;

    if (news.mediaObjects.isNotEmpty) {
      // Используем новый контракт с MediaObjects
      final firstMedia = news.mediaObjects.first;

      if (firstMedia.isVideo) {
        // Для видео показываем превью, если есть
        previewImageUrl = firstMedia.effectivePreviewUrl;
      } else if (firstMedia.isPhoto) {
        // Для фото показываем само фото
        previewImageUrl = firstMedia.url;
      }
    } else {
      // Fallback на старые поля для обратной совместимости
      final List<String> httpImages =
          (news.mediaUrls.isNotEmpty
                  ? news.mediaUrls
                  : (news.imageUrl.isNotEmpty ? [news.imageUrl] : <String>[]))
              .where((url) => url.startsWith('http'))
              .toList();

      if (httpImages.isNotEmpty) {
        previewImageUrl = httpImages.first;
      }
    }

    final bool hasRealImage = previewImageUrl != null && previewImageUrl.startsWith('http');

    Widget newsCard = RepaintBoundary(
      key: cardKey,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: cardOpacity,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Stack(
          children: [
            // Glow effect for unseen posts
            if (!isPostSeen)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.1),
                      blurRadius: isPostSeen ? 20 : 28,
                      offset: Offset(0, isPostSeen ? 8 : 10),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openNewsDetail(news),
                  child: Stack(
                    children: [
                        // Main content
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Изображение сверху (превью для фото и видео)
                            if (hasRealImage && _imagePreviewService.showImagePreviews)
                    Stack(
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                            child: Image.network(
                              previewImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                 return const SizedBox.shrink();
                               },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return _buildImageShimmerLoader(isDark);
                                  },
                            ),
                          ),
                        ),
                        // Градиентный оверлей для лучшей читаемости
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha:0.3),
                              ],
                            ),
                          ),
                        ),

                        // Индикатор видео (если это видео)
                        if (news.mediaObjects.isNotEmpty && news.mediaObjects.first.isVideo)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.play_fill,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),

                  // Контент карточки
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Заголовок
                        Text(
                          news.title,
                          style: TextStyle(
                            color: isPostSeen
                                ? primaryTextColor.withValues(alpha: 0.7)
                                : primaryTextColor,
                            fontSize: 18,
                            fontWeight: isPostSeen ? FontWeight.w600 : FontWeight.bold,
                            height: 1.3,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 12),

                        // Источник, превью-тег и время в одной строке
                        Row(
                          children: [
                            if (news.sources.isNotEmpty ||
                                (news.link != null &&
                                    news.link!.isNotEmpty)) ...[
                              _buildSourcePreviewChip(context, news, isDark),
                              const SizedBox(width: 8),
                            ],
                            const Spacer(),
                            // Индикатор непрочитанности (точка) + дата
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isPostSeen) ...[
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.8),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  _getTimeAgo(news.publishedAt, context),
                                  style: TextStyle(
                                    color: secondaryTextColor.withValues(alpha:0.7),
                                    fontSize: 12,
                                    fontWeight: isPostSeen ? FontWeight.normal : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Нижняя панель с действиями
                        Row(
                          children: [],
                        ),
                      ],
                    ),
                  ),
                          ],
                        ),

                        // Accent stripe for unseen posts with fire-like glow (positioned on the left)
                        if (!isPostSeen)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_stripeGlowController, _stripeFlickerController]),
                              builder: (context, child) {
                                // Combine breathing and flickering animations for fire-like effect
                                final breathe = _stripeGlowController.value; // Slow breathing (4500ms)
                                final flicker = _stripeFlickerController.value; // Flickering (1800ms)

                                // Create chaotic wave patterns with different phases
                                final wave1 = math.sin(flicker * math.pi * 2.3 + 0.5);
                                final wave2 = math.cos(breathe * math.pi * 1.7 + 1.2);
                                final wave3 = math.sin((breathe + flicker) * math.pi * 1.3 + 2.1);

                                // Base chaos values
                                final flickerChaos = math.sin(flicker * math.pi * 2) * 0.5 + 0.5;
                                final breatheChaos = math.cos(breathe * math.pi * 2) * 0.5 + 0.5;

                                // Multi-layered glow parameters with chaotic wave forms
                                // Layer 1: Intense inner core - fast chaotic movement
                                final innerIntensity = 0.4 + (flickerChaos * 0.15); // 0.4 to 0.55
                                final innerBlur = 6.0 + (flickerChaos * 3.0); // 6 to 9
                                final innerSpread = 0.3 + (flickerChaos * 0.4); // 0.3 to 0.7
                                final innerOffsetX = -2.0 + (flickerChaos * -0.5); // -2 to -2.5
                                final innerOffsetY = wave1 * 2.0; // Chaotic wave

                                // Layer 2: Middle diffusion - different frequency
                                final middleIntensity = 0.25 + (breatheChaos * 0.15); // 0.25 to 0.4
                                final middleBlur = 10.0 + (breatheChaos * 4.0); // 10 to 14
                                final middleSpread = 0.8 + (breatheChaos * 0.8); // 0.8 to 1.6
                                final middleOffsetX = -2.5 + (breatheChaos * -0.8); // -2.5 to -3.3
                                final middleOffsetY = wave2 * 2.5; // Different wave pattern

                                // Layer 3: Outer soft glow - slowest, most spread
                                final outerIntensity = 0.15 + (breatheChaos * 0.1); // 0.15 to 0.25
                                final outerBlur = 14.0 + (breatheChaos * 4.0); // 14 to 18
                                final outerSpread = 1.2 + (breatheChaos * 0.8); // 1.2 to 2.0
                                final outerOffsetX = -3.0 + (flickerChaos * -1.0); // -3 to -4
                                final outerOffsetY = wave3 * 3.0; // Combined chaotic wave

                                return Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        accentColor.withValues(alpha: 0.2),
                                        accentColor.withValues(alpha: 0.85),
                                        accentColor.withValues(alpha: 0.3),
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(24),
                                      bottomLeft: Radius.circular(24),
                                    ),
                                    boxShadow: [
                                      // Layer 3: Outer soft glow (furthest spread)
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: outerIntensity),
                                        blurRadius: outerBlur,
                                        spreadRadius: outerSpread,
                                        offset: Offset(outerOffsetX, outerOffsetY),
                                      ),
                                      // Layer 2: Middle diffusion
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: middleIntensity),
                                        blurRadius: middleBlur,
                                        spreadRadius: middleSpread,
                                        offset: Offset(middleOffsetX, middleOffsetY),
                                      ),
                                      // Layer 1: Inner core (brightest, tightest)
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: innerIntensity),
                                        blurRadius: innerBlur,
                                        spreadRadius: innerSpread,
                                        offset: Offset(innerOffsetX, innerOffsetY),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return newsCard;
  }


  // Строит компактный чип источника для строки метаданных (справа от имени)
 Widget _buildSourcePreviewChip(BuildContext context, NewsItem news, bool isDark) {
   final secondaryTextColor =
       isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

   final urls = news.sources.isNotEmpty
       ? news.sources
           .map((s) => s.sourceUrl)
           .whereType<String>()
           .where((u) => u.isNotEmpty)
           .toList()
       : (news.link != null && news.link!.isNotEmpty ? [news.link!] : <String>[]);

   final int sourceCount = urls.length;

   if (sourceCount == 0) {
     return const SizedBox.shrink();
   }

   final l10n = AppLocalizations.of(context)!;
   final String label = l10n.sourceCount(sourceCount);

   return Text(
     label,
     style: TextStyle(
       fontSize: 12,
       fontWeight: FontWeight.w500,
       color: secondaryTextColor.withValues(alpha:0.7),
     ),
   );
 }

  /// Builds a page for a specific category with its news
  Widget _buildCategoryPage(Feed category, List<NewsItem> categoryNews, bool isDark) {
    // Get or create scroll controller for this feed
    final scrollController = _getOrCreateScrollController(category.id);

    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // Modern AAA-level refresh indicator
        CupertinoSliverRefreshControl(
          onRefresh: _refreshNews,
          refreshTriggerPullDistance: 100.0,
          refreshIndicatorExtent: 80.0,
          builder: (context, refreshState, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
            return _buildModernRefreshIndicator(
              context,
              refreshState,
              pulledExtent,
              refreshTriggerPullDistance,
              refreshIndicatorExtent
            );
          },
        ),

        // WebSocket waiting state - show full-screen loading
        if (_isWaitingForFeedCreation && _pendingFeedId == category.id)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LoadingAnimationWidget.threeArchedCircle(
                    color: isDark ? AppColors.accent : AppColors.lightAccent,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _pendingFeedType == 'DIGEST'
                        ? (AppLocalizations.of(context)?.creatingDigest ?? 'Creating your digest...')
                        : (AppLocalizations.of(context)?.creatingFeed ?? 'Creating your feed...'),
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)?.waitingForFirstPost ?? 'Waiting for first post',
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        // 1. Feed creation TIMED OUT - show timeout error with refresh button
        else if (_feedCreationTimedOut && category.id == _selectedCategoryId)
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      size: 48,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Feed creation is taking longer than expected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please refresh to check status',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    CupertinoButton.filled(
                      child: const Text('Refresh'),
                      onPressed: () async {
                        setState(() {
                          _feedCreationTimedOut = false;
                        });

                        // Retry loading posts
                        final selectedId = _selectedCategoryId;
                        if (selectedId == null) return;

                        await _loadInitialPosts(selectedId, forceRefresh: true);
                      },
                    ),
                  ],
                ),
              ),
            ),
          )
        // 2. General error state (network error during regular load)
        else if (_hasError && categoryNews.isEmpty && !(_isInitialPostsLoading[category.id] ?? false))
          SliverPadding(
            padding: const EdgeInsets.only(top: 16),
            sliver: SliverToBoxAdapter(
              child: _buildErrorState(isDark)
            ),
          )
        // 3. Post loading error - show error state with retry button
        else if (categoryNews.isEmpty && (_hasPostLoadError[category.id] ?? false))
          SliverPadding(
            padding: const EdgeInsets.only(top: 16),
            sliver: SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      size: 48,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)?.errorLoadingPosts ?? 'Failed to load posts',
                      style: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CupertinoButton(
                      onPressed: () => _loadInitialPosts(category.id, forceRefresh: true),
                      child: Text(AppLocalizations.of(context)?.tapToRetry ?? 'Tap to retry'),
                    ),
                  ],
                ),
              ),
            ),
          )
        // 4. Posts LOADING - show skeleton loader (while WebSocket waits or posts fetch)
        else if (categoryNews.isEmpty && (_isInitialPostsLoading[category.id] ?? false))
          SliverPadding(
            padding: const EdgeInsets.only(top: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildPulseSkeletonCard(isDark, index);
                },
                childCount: 4,
              ),
            ),
          )
        // 5. News list (with optional digest placeholder at top)
        else if (categoryNews.isNotEmpty) ...[
          // Digest placeholder (accordion animation) - only show for the feed being summarized
          if (_isSummarizingUnseen && category.id == _summarizingFeedId)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                child: _buildDigestPlaceholder(isDark),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(top: _isSummarizingUnseen && category.id == _selectedCategoryId ? 8 : 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Last item: show loading indicator for infinite scroll
                  if (index == categoryNews.length) {
                    return _buildLoadMoreIndicator(category.id, isDark);
                  }

                  final news = categoryNews[index];

                  // Check if this post is new (appeared in last 2 seconds)
                  final appearTime = _postAppearTimes[news.id];
                  final isNewPost = appearTime != null &&
                      DateTime.now().difference(appearTime).inSeconds < 2;

                  // AAA-level animation: Staggered fade-in + slide-up (only for new posts)
                  if (isNewPost) {
                    return TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 30 * (1 - value)), // Slide up from 30px below
                            child: Transform.scale(
                              scale: 0.95 + (0.05 * value), // Subtle scale from 95% to 100%
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: _buildNewsCard(news, index, isDark, feedId: category.id),
                    );
                  }

                  // No animation for existing posts
                  return _buildNewsCard(news, index, isDark, feedId: category.id);
                },
                // Add 1 for loading indicator slot
                childCount: categoryNews.length + 1,
              ),
            ),
          ),
        ]
        // 6. Feed has no posts - show skeleton loader (user can pull-to-refresh)
        else
          SliverPadding(
            padding: const EdgeInsets.only(top: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildPulseSkeletonCard(isDark, index);
                },
                childCount: 4,
              ),
            ),
          ),

        // Fill remaining space for pull-to-refresh
        const SliverFillRemaining(
          hasScrollBody: false,
          child: SizedBox.shrink(),
        ),

        // Bottom padding for tab bar
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  /// Builds a beautiful shimmer loading placeholder for news images
  /// Modern AAA-level loading state like Instagram/LinkedIn
  Widget _buildImageShimmerLoader(bool isDark) {
    final baseColor = isDark 
        ? AppColors.surface.withValues(alpha: 0.3)
        : AppColors.lightSurface.withValues(alpha: 0.5);
    final highlightColor = isDark
        ? AppColors.accent.withValues(alpha: 0.1)
        : AppColors.lightAccent.withValues(alpha: 0.15);
    final shimmerColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.4);

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        // Calculate shimmer position (moves from -1 to 2 for smooth infinite loop)
        final shimmerValue = (_shimmerController.value * 3) - 1;
        
        return Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Animated shimmer effect
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: Transform.translate(
                    offset: Offset(shimmerValue * 400, 0),
                    child: Container(
                      width: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            shimmerColor,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Subtle loading indicator in corner
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          isDark ? AppColors.accent : AppColors.lightAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============= SUMMARIZE UNSEEN POSTS FEATURE =============

  /// Check if summarize FAB should be visible
  bool _shouldShowSummarizeFab() {
    if (_currentFeedTypeTab != 0) return false; // Только на табе Feeds
    if (_selectedCategoryId == null) return false;
    if (_isSummarizingUnseen) return false;
    final unseenCount = _getUnseenPostCountForFeed(_selectedCategoryId!);
    return unseenCount > 0;
  }

  /// Get unseen posts for the currently selected feed
  List<NewsItem> _getUnseenPostsForCurrentFeed() {
    if (_selectedCategoryId == null) return [];
    return _allNewsItems.where((news) {
      if (news.feedId != _selectedCategoryId) return false;
      final isPostSeen = news.seen || _seenPostsService.isPostSeen(news.id);
      return !isPostSeen;
    }).toList();
  }

  /// Build the floating summarize button
  Widget _buildSummarizeFab(bool isDark) {
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;

    return Positioned(
      bottom: 100,
      right: 24,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _shouldShowSummarizeFab() ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_shouldShowSummarizeFab(),
          child: GestureDetector(
            onTap: _showSummarizeConfirmation,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor,
                    accentColor.withOpacity(0.8),
                  ],
                ),
                boxShadow: [
                  // Accent glow - only for dark theme
                  if (isDark)
                    BoxShadow(
                      color: accentColor.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  // Regular shadow - for both themes
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                CupertinoIcons.sparkles,
                size: 28,
                color: isDark ? CupertinoColors.black : CupertinoColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show confirmation modal for summarization
  Future<void> _showSummarizeConfirmation() async {
    if (_selectedCategoryId == null) return;

    final unseenCount = _getUnseenPostCountForFeed(_selectedCategoryId!);
    if (unseenCount == 0) return;

    // Check limit: max 20 unread posts for digest
    const maxUnseenForDigest = 20;
    final isOverLimit = unseenCount > maxUnseenForDigest;

    final feed = _categories.firstWhere(
      (f) => f.id == _selectedCategoryId,
      orElse: () => _categories.first,
    );
    final feedName = feed.name;

    final l10n = AppLocalizations.of(context)!;

    // Different message if over limit
    final message = isOverLimit
        ? l10n.summarizeUnseenOverLimit(unseenCount, maxUnseenForDigest)
        : l10n.summarizeUnseenMessage(unseenCount, feedName);

    final confirmed = await ConfirmationModal.showConfirmation(
      context: context,
      icon: CupertinoIcons.sparkles,
      title: l10n.summarizeUnseenTitle,
      message: message,
      confirmText: l10n.summarizeUnseenConfirm,
      cancelText: l10n.summarizeUnseenCancel,
      isDestructive: false,
      isConfirmEnabled: !isOverLimit,
    );

    if (confirmed == true) {
      HapticFeedback.selectionClick(); // Confirm tap
      _startSummarizeAnimation();
    }
  }

  /// Main animation orchestrator
  Future<void> _startSummarizeAnimation() async {
    if (_selectedCategoryId == null) return;

    final unseenPosts = _getUnseenPostsForCurrentFeed();
    if (unseenPosts.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final feed = _categories.firstWhere(
      (f) => f.id == _selectedCategoryId,
      orElse: () => _categories.first,
    );

    // Phase 1: Show placeholder (embedded in list)
    setState(() {
      _isSummarizingUnseen = true;
      _summarizingFeedId = _selectedCategoryId;  // Scope animation to this feed only
      _summarizeTotalCount = unseenPosts.length;
      _summarizeProcessedCount = 0;
      _summarizeStatusText = l10n.summarizeStatusPreparing;
    });
    HapticFeedback.lightImpact(); // Process started

    // Brief delay for placeholder to appear
    await Future.delayed(const Duration(milliseconds: 200));

    // Phase 2+3: Run animation and API in parallel for faster response
    setState(() {
      _summarizeStatusText = l10n.summarizeStatusCollecting;
    });

    // Start both concurrently - API is the main blocker, animation is just UX
    final apiFuture = NewsService.summarizeUnseenPosts(_selectedCategoryId!);
    final animationFuture = _animateCardsAccordion(unseenPosts);

    // Update status text when animation completes (non-blocking)
    animationFuture.then((_) {
      if (mounted) {
        setState(() {
          _summarizeStatusText = l10n.summarizeStatusGenerating;
        });
      }
    });

    // Wait for API result - show content as soon as it's ready
    final digest = await apiFuture;

    if (digest != null) {
      // Fetch full post data via GET /posts/{id}
      final post = await NewsService.fetchPostById(digest.id);

      if (post != null && mounted) {
        // Phase 4: Show digest IMMEDIATELY when API returns
        // Don't wait for animation - just hide placeholder and show result
        setState(() {
          _isSummarizingUnseen = false;
          _summarizingFeedId = null;
          _animatingPostIds.clear();
          _summarizeStatusText = l10n.summarizeStatusReady;
          _summarizeProcessedCount = _summarizeTotalCount;
        });
        HapticFeedback.mediumImpact(); // Success!

        // Navigate to digest detail immediately
        final newsItem = NewsService.convertPostToNewsItem(post, feed);

        // Mark digest as read immediately (fire-and-forget)
        NewsService.markPostsAsSeen([digest.id]);

        // Mark all original unseen posts as seen locally
        final unseenPostIds = unseenPosts.map((post) => post.id).whereType<String>().toList();
        _seenPostsService.markPostsAsSeen(unseenPostIds);

        // Also notify backend (fire-and-forget)
        NewsService.markPostsAsSeen(unseenPostIds);

        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => NewsDetailPage(news: newsItem),
          ),
        );

        // Insert digest into cache - triggers _onCacheChanged() for minimal UI update
        // No need for full _refreshFeeds() - just append like a regular WebSocket post
        FeedCacheService().insertPost(_selectedCategoryId!, post);

        // Track analytics
        AnalyticsService().capture(EventSchema.digestCreated, properties: {
          'feed_id': _selectedCategoryId,
        });
      } else {
        // Failed to fetch post
        setState(() {
          _summarizeStatusText = l10n.summarizeStatusFailed;
        });
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 1500));
        setState(() {
          _isSummarizingUnseen = false;
          _summarizingFeedId = null;
          _animatingPostIds.clear();
        });
      }
    } else {
      // Error handling
      setState(() {
        _summarizeStatusText = l10n.summarizeStatusFailed;
      });
      HapticFeedback.heavyImpact(); // Error

      await Future.delayed(const Duration(milliseconds: 1500));

      // Clear animation state on error too
      setState(() {
        _isSummarizingUnseen = false;
        _summarizingFeedId = null;
        _animatingPostIds.clear();
      });
    }
  }

  /// Build the digest placeholder widget for embedding in the list
  Widget _buildDigestPlaceholder(bool isDark) {
    return FunnelAnimationOverlay(
      totalPosts: _summarizeTotalCount,
      processedPosts: _summarizeProcessedCount,
      statusText: _summarizeStatusText,
      isComplete: _summarizeProcessedCount >= _summarizeTotalCount &&
          _summarizeStatusText.contains('Ready'),
    );
  }

  /// Build floating digest placeholder with unique key for dynamic updates
  Widget _buildFloatingDigestPlaceholder(BuildContext context, double targetY) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Positioned(
      key: ValueKey('placeholder_$_summarizeProcessedCount'), // Forces rebuild
      left: 16,
      right: 16,
      top: targetY,
      child: Material(
        color: Colors.transparent,
        child: _buildDigestPlaceholder(isDark),
      ),
    );
  }

  /// Capture a screenshot of the card widget for animation
  Future<ui.Image?> _captureCardImage(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      return await boundary.toImage(pixelRatio: 2.0);
    } catch (e) {
      return null;
    }
  }

  /// Animate cards sliding up toward the placeholder with AAA-quality sequential funnel effect
  /// Cards are processed one-by-one with 70% overlap - next card starts when previous is 70% done
  Future<void> _animateCardsAccordion(List<NewsItem> unseenPosts) async {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    // Calculate target Y position (where placeholder appears)
    final targetY = MediaQuery.of(context).padding.top +
        kMinInteractiveDimensionCupertino +  // nav bar height
        48 +  // feed tabs approximate height
        16;   // padding

    // Adaptive timing based on post count
    // More posts = faster animation to avoid long waits
    final postCount = unseenPosts.length;
    final int particleDuration; // Total particle flight time
    final int cardDelay;        // Delay before hiding card from list
    final int overlapDelay;     // Delay between starting animations for each card
    final int finalWait;        // Wait after last card starts

    if (postCount <= 3) {
      // Few posts: comfortable slow animation (1.8s per card)
      particleDuration = 1800;
      cardDelay = 300;
      overlapDelay = 1080; // 60% overlap
      finalWait = 720;
    } else if (postCount <= 10) {
      // Medium batch: moderate speed (1.2s per card)
      particleDuration = 1200;
      cardDelay = 200;
      overlapDelay = 720; // 60% overlap
      finalWait = 480;
    } else {
      // Large batch: fast animation (0.8s per card)
      particleDuration = 800;
      cardDelay = 150;
      overlapDelay = 480; // 60% overlap
      finalWait = 320;
    }

    // Process cards sequentially with adaptive overlap
    // Each card is captured at its CURRENT position (after previous cards removed)
    for (int i = 0; i < unseenPosts.length; i++) {
      final post = unseenPosts[i];
      final key = _postCardKeys[post.id];

      // Skip if card not visible/rendered yet (off-screen)
      if (key?.currentContext == null) continue;

      // Capture CURRENT position (may have shifted from previous cards being removed)
      final cardImage = await _captureCardImage(key!);
      final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      final cardPosition = renderBox.localToGlobal(Offset.zero);
      final cardSize = renderBox.size;

      // Create animation widget for THIS card
      final animationWidget = ParticleAnimationOverlay(
        cardPosition: cardPosition,
        cardSize: cardSize,
        targetCenter: Offset(
          MediaQuery.of(context).size.width / 2,  // Center X
          targetY + 60,  // Center Y (placeholder center, ~60px from top)
        ),
        durationMs: particleDuration, // Adaptive duration based on post count
        onComplete: () {
          // Remove this animation widget when complete
          if (mounted) {
            setState(() {
              _particleAnimations.removeWhere((widget) {
                return widget is ParticleAnimationOverlay &&
                    widget.cardPosition == cardPosition;
              });
            });
          }
        },
      );

      // Add animation to local list AND update progress counter immediately
      final postId = post.id;
      if (mounted) {
        setState(() {
          _particleAnimations.add(animationWidget);
          _summarizeProcessedCount = i + 1;  // Update progress counter immediately
        });
      }

      // DELAY hiding card from list - let overlay get a head start
      // Wait before list scrolls (adaptive based on post count)
      // This prevents new card from clashing with ongoing animation
      Future.delayed(Duration(milliseconds: cardDelay), () {
        if (mounted && postId != null) {
          setState(() {
            _animatingPostIds.add(postId);
          });
          HapticFeedback.selectionClick(); // Card dissolves
        }
      });

      // Schedule animation widget removal after full animation (adaptive duration)
      Future.delayed(Duration(milliseconds: particleDuration), () {
        if (mounted) {
          setState(() {
            _particleAnimations.removeWhere((widget) {
              return widget is ParticleAnimationOverlay &&
                  widget.cardPosition == cardPosition;
            });
          });
        }
      });

      // Wait before starting next card (adaptive overlap)
      // Creates continuous particle flow where cards follow each other smoothly
      await Future.delayed(Duration(milliseconds: overlapDelay));
    }

    // Wait for last card's particles to finish arriving (adaptive)
    await Future.delayed(Duration(milliseconds: finalWait));
  }

  // ============= END SUMMARIZE FEATURE =============

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.background
        : AppColors.lightBackground;
    final primaryTextColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;

    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      child: Stack(
        children: [
          Column(
        children: [
          // Offline banner
          _buildOfflineBanner(isDark),

          // Feed type toggle (Digests | Feeds) - only show when feeds exist
          if (!_isLoading && _categories.isNotEmpty)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: GlassPageToggle(
                  currentPage: _currentFeedTypeTab,
                  icons: const [
                    CupertinoIcons.square_stack_fill, // Feeds
                    CupertinoIcons.doc_text_fill, // Digests
                  ],
                  labels: [
                    l10n.feedsTab,
                    l10n.digestsTab,
                  ],
                  onPageChanged: (page) {
                    _feedTypePageController.animateToPage(
                      page,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),

          // Fixed sticky header с категориями (Telegram-style) - только для Feeds (таб 0)
          if (!_isLoading && _currentFeedTypeTab == 0 && _regularFeeds.isNotEmpty)
            TelegramFolderTabs(
              feeds: _currentTabFeeds,
              selectedFeedId: _selectedCategoryId,
              onFeedSelected: _filterNewsByCategory,
              onFeedLongPress: _showFeedManagementOverlay,
              getUnseenCount: _getUnseenPostCountForFeed,
              zenModeEnabled: _zenModeService.isZenMode,
              isDark: isDark,
              scrollController: _categoryScrollController,
              feedTagKeys: _feedTagKeys,
            ),

          // PageView с типами лент (Digests | Feeds)
          Expanded(
            child: _isLoading
                ? _buildSkeletonList(
                    isDark,
                    topPadding: MediaQuery.of(context).padding.top + 8,
                  )
                : _categories.isEmpty
                    ? _buildNoFeedsEmptyState(isDark)
                    : PageView(
                        controller: _feedTypePageController,
                        onPageChanged: _onFeedTypeTabChanged,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildFeedTypeContent(0, _regularFeeds, isDark),
                          _buildDigestsListContent(isDark),
                        ],
                      ),
          ),
        ],
      ),
      // Floating Summarize Button
      _buildSummarizeFab(isDark),

      // Particle animations layer (local, non-blocking)
      ..._particleAnimations,

      // Floating placeholder widget (appears above particles, rebuilt on counter updates)
      // Only show for the feed being summarized
      if (_isSummarizingUnseen && _selectedCategoryId == _summarizingFeedId)
        _buildFloatingDigestPlaceholder(
          context,
          MediaQuery.of(context).padding.top +
              kMinInteractiveDimensionCupertino + // nav bar
              48 + // feed tabs
              16, // padding
        ),
        ],
      ),
    );
  }

  /// Handler for feed type tab change (Digests <-> Feeds)
  void _onFeedTypeTabChanged(int page) {
    setState(() {
      _currentFeedTypeTab = page;

      // Reset to first feed in the new tab
      final currentFeeds = _currentTabFeeds;
      if (currentFeeds.isNotEmpty) {
        _selectedCategoryId = currentFeeds.first.id;

        // Reset the appropriate page controller
        if (page == 0 && _regularFeedPageController.hasClients) {
          _regularFeedPageController.jumpToPage(0);
        } else if (page == 1 && _digestPageController.hasClients) {
          _digestPageController.jumpToPage(0);
        }
      } else {
        _selectedCategoryId = null;
      }
    });

    // Load posts for digest feeds when switching to Digests tab
    if (page == 1) {
      _loadDigestPosts();
    }

    HapticFeedback.selectionClick();

    // Analytics (internal event - not in schema)
    AnalyticsService().capture(
      'feed_type_tab_switched',
      properties: {
        'tab': page == 0 ? 'digests' : 'feeds',
        'feed_count': _currentTabFeeds.length,
      },
    );
  }

  /// Build content for each feed type tab
  Widget _buildFeedTypeContent(int tabIndex, List<Feed> feeds, bool isDark) {
    // Show empty state if no feeds of this type
    if (feeds.isEmpty) {
      return _buildEmptyTabState(tabIndex, isDark);
    }

    // Use appropriate page controller (0 = Feeds, 1 = Digests)
    final controller = tabIndex == 0 ? _regularFeedPageController : _digestPageController;

    return PageView.builder(
      controller: controller,
      onPageChanged: (pageIndex) => _onCategoryPageChangedForTab(tabIndex, pageIndex, feeds),
      itemCount: feeds.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, pageIndex) {
        final category = feeds[pageIndex];
        final categoryNews = _sortNewsBySeenStatus(
          _allNewsItems.where((news) => news.feedId == category.id).toList(),
        );
        return _buildCategoryPage(category, categoryNews, isDark);
      },
    );
  }

  /// Build digests content as a single flat list (no folders)
  /// All digest posts sorted by date, newest first
  Widget _buildDigestsListContent(bool isDark) {
    // Check if creating a new digest
    // All flags are reset together in _handleRealtimePostCreated's setState
    final isCreatingDigest = _isWaitingForFeedCreation && _pendingFeedType == 'DIGEST';

    // Check if any digest feed is loading or waiting for creation
    final isAnyDigestLoading = _digestFeeds.any((feed) =>
      _isInitialPostsLoading[feed.id] == true ||
      (_isWaitingForFeedCreation && _pendingFeedId == feed.id)
    );

    // Show skeleton loader while loading existing digests (but not when creating new)
    if (isAnyDigestLoading && !isCreatingDigest) {
      return _buildSkeletonList(
        isDark,
        topPadding: 8,
      );
    }

    // Collect all posts from all digest feeds
    final allDigestPosts = <NewsItem>[];
    for (final feed in _digestFeeds) {
      allDigestPosts.addAll(
        _allNewsItems.where((item) => item.feedId == feed.id),
      );
    }

    // Sort by date (newest first)
    allDigestPosts.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    // Show empty state only if not creating and no posts
    if (allDigestPosts.isEmpty && !isCreatingDigest) {
      return _buildEmptyTabState(1, isDark);
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Show beautiful loader at top when creating new digest
        if (isCreatingDigest)
          SliverToBoxAdapter(
            child: _buildDigestCreationLoader(isDark),
          ),
        // Show skeleton loaders for other digests loading below "Creating feed"
        if (isCreatingDigest && isAnyDigestLoading)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildPulseSkeletonCard(isDark, index),
              childCount: 3,
            ),
          ),
        // Show existing digest posts
        if (allDigestPosts.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.only(top: isCreatingDigest ? 0 : 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildNewsCard(allDigestPosts[index], index, isDark),
                childCount: allDigestPosts.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  /// Build beautiful loader card shown at top when creating a new digest
  Widget _buildDigestCreationLoader(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingAnimationWidget.staggeredDotsWave(
            color: isDark ? AppColors.accent : AppColors.lightAccent,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)?.creatingDigest ?? 'Creating your digest...',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Handler for category page change within a specific tab
  void _onCategoryPageChangedForTab(int tabIndex, int pageIndex, List<Feed> feeds) {
    if (pageIndex < 0 || pageIndex >= feeds.length) return;

    final category = feeds[pageIndex];
    HapticFeedback.selectionClick();

    setState(() {
      _selectedCategoryId = category.id;
      _filteredNewsItems = _sortNewsBySeenStatus(
        _allNewsItems.where((news) => news.feedId == category.id).toList(),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSelectedCategory();
    });

    // Load initial posts for selected category
    _loadInitialPosts(category.id);

    // Internal event - not in schema
    AnalyticsService().capture(
      'category_swiped',
      properties: {
        'tab': tabIndex == 0 ? 'digests' : 'feeds',
        'category_id': category.id,
        'category_name': category.name,
      },
    );
  }

  /// Build empty state for each tab (digests or feeds)
  Widget _buildEmptyTabState(int tabIndex, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final isDigestTab = tabIndex == 0;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDigestTab ? CupertinoIcons.doc_text : CupertinoIcons.square_stack,
              size: 64,
              color: secondaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              isDigestTab ? l10n.noDigestsTitle : l10n.noFeedsTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isDigestTab ? l10n.noDigestsHint : l10n.noRegularFeedsHint,
              style: TextStyle(
                fontSize: 14,
                color: secondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              onPressed: widget.onNavigateToChat,
              child: Text(
                l10n.goToChat,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Красивый skeleton список с pulse анимацией (вместо центрального спиннера)
  Widget _buildSkeletonList(bool isDark, {double topPadding = 8}) {
    return ListView.builder(
      itemCount: 4,
      padding: EdgeInsets.only(top: topPadding, bottom: 100),
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => _buildPulseSkeletonCard(isDark, index),
    );
  }

  /// Skeleton карточка с pulse (breathing) анимацией
  Widget _buildPulseSkeletonCard(bool isDark, int index) {
    final cardBackground = isDark ? AppColors.surface : AppColors.lightSurface;
    final placeholderColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12);

    // Staggered offset для волнового эффекта (каждая карточка с задержкой)
    final staggerOffset = index * 0.15;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        // Pulse formula с offset для волнового эффекта
        final adjustedValue = (_shimmerController.value + staggerOffset) % 1.0;
        final opacity = 0.35 + 0.35 * math.sin(adjustedValue * 2 * math.pi);

        return Opacity(
          opacity: opacity,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image placeholder (200px как в реальной карточке)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                ),

                // Content area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title line 1 (85% width)
                      Container(
                        width: MediaQuery.of(context).size.width * 0.7,
                        height: 18,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title line 2 (55% width)
                      Container(
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: 18,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Source row: chip + spacer + time
                      Row(
                        children: [
                          // Source chip placeholder
                          Container(
                            width: 80,
                            height: 24,
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const Spacer(),
                          // Time placeholder
                          Container(
                            width: 50,
                            height: 14,
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final primaryTextColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('⚠️', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            l10n.couldNotLoadNews,
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.checkInternetConnection,
            style: TextStyle(color: secondaryTextColor, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          CupertinoButton(
            onPressed: _loadNews,
            child: Text(
              l10n.tryAgainButton,
              style: TextStyle(
                color: isDark ? AppColors.accent : AppColors.lightAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds modern AAA-level refresh indicator with smooth animations
  Widget _buildModernRefreshIndicator(
    BuildContext context,
    RefreshIndicatorMode refreshState,
    double pulledExtent,
    double refreshTriggerPullDistance,
    double refreshIndicatorExtent,
  ) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.accent : AppColors.lightAccent;
    final secondaryColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final backgroundColor = isDark ? AppColors.background : AppColors.lightBackground;
    
    // Calculate progress and determine local visual state
    final progress = (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
    final isOverTrigger = pulledExtent >= refreshTriggerPullDistance;
    
    // Determine current visual state based on CupertinoRefreshIndicatorMode
    RefreshState currentVisualState;
    if (refreshState == RefreshIndicatorMode.refresh || _refreshState == RefreshState.refreshing) {
      currentVisualState = _refreshState == RefreshState.success ? RefreshState.success : RefreshState.refreshing;
    } else if (refreshState == RefreshIndicatorMode.armed || isOverTrigger) {
      currentVisualState = RefreshState.ready;
    } else if (refreshState == RefreshIndicatorMode.drag && progress > 0.1) {
      currentVisualState = RefreshState.pulling;
    } else {
      currentVisualState = RefreshState.inactive;
    }
    
    // Handle haptics without setState to avoid rebuild loops
    if (refreshState == RefreshIndicatorMode.drag) {
      if (progress > 0.2 && !_hasTriggeredPulling) {
        HapticFeedback.selectionClick();
        _hasTriggeredPulling = true;
      }
      if (isOverTrigger && !_hasTriggeredReady) {
        HapticFeedback.lightImpact();
        _hasTriggeredReady = true;
      }
    } else if (refreshState == RefreshIndicatorMode.refresh && !_hasTriggeredRefresh) {
      HapticFeedback.mediumImpact();
      _hasTriggeredRefresh = true;
    } else if (refreshState == RefreshIndicatorMode.done || refreshState == RefreshIndicatorMode.inactive) {
      _hasTriggeredPulling = false;
      _hasTriggeredReady = false;
      _hasTriggeredRefresh = false;
    }

    return Container(
      height: pulledExtent,
      width: double.infinity,
      child: Stack(
        children: [
          // Background blur effect
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor.withValues(alpha:0.8),
                    backgroundColor.withValues(alpha:0.95),
                  ],
                ),
              ),
            ),
          ),
          
          // Main refresh indicator
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..scale(0.8 + (progress * 0.4))
                ..translate(0.0, -10 + (progress * 10)),
              child: _buildRefreshIcon(isDark, primaryColor, secondaryColor, progress, currentVisualState),
            ),
          ),
          
          // Bottom indicator line
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    primaryColor.withValues(alpha:progress * 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the animated refresh icon based on current state
  Widget _buildRefreshIcon(bool isDark, Color primaryColor, Color secondaryColor, double progress, RefreshState currentVisualState) {
    switch (currentVisualState) {
      case RefreshState.inactive:
      case RefreshState.pulling:
        return _buildPullingIcon(primaryColor, secondaryColor, progress);
      case RefreshState.ready:
        return _buildReadyIcon(primaryColor, progress);
      case RefreshState.refreshing:
        return _buildRefreshingIcon(primaryColor);
      case RefreshState.success:
        return _buildSuccessIcon(primaryColor);
      case RefreshState.error:
        return _buildErrorIcon(isDark);
    }
  }

  /// Pulling state icon with progress indication
  Widget _buildPullingIcon(Color primaryColor, Color secondaryColor, double progress) {
    return Container(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer progress ring
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(primaryColor.withValues(alpha:0.3)),
              backgroundColor: secondaryColor.withValues(alpha:0.1),
            ),
          ),
          // Center pull icon
          AnimatedRotation(
            turns: progress * 0.5,
            duration: const Duration(milliseconds: 100),
            child: Icon(
              CupertinoIcons.arrow_down,
              size: 24,
              color: primaryColor.withValues(alpha:0.6 + (progress * 0.4)),
            ),
          ),
        ],
      ),
    );
  }

  /// Ready state icon with bounce animation
  Widget _buildReadyIcon(Color primaryColor, double progress) {
    return AnimatedBuilder(
      animation: _refreshController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (0.1 * progress),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha:0.1),
              border: Border.all(
                color: primaryColor,
                width: 2,
              ),
            ),
            child: Icon(
              CupertinoIcons.arrow_up,
              size: 24,
              color: primaryColor,
            ),
          ),
        );
      },
    );
  }

  /// Refreshing state with smooth rotation
  Widget _buildRefreshingIcon(Color primaryColor) {
    return AnimatedBuilder(
      animation: _refreshIconController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _refreshIconController.value * 2 * 3.14159,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryColor.withValues(alpha:0.1),
                  primaryColor.withValues(alpha:0.05),
                ],
              ),
              border: Border.all(
                color: primaryColor,
                width: 2,
              ),
            ),
            child: Icon(
              CupertinoIcons.refresh,
              size: 24,
              color: primaryColor,
            ),
          ),
        );
      },
    );
  }

  /// Success state with checkmark animation
  Widget _buildSuccessIcon(Color primaryColor) {
    return AnimatedBuilder(
      animation: _refreshSuccessController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_refreshSuccessController.value * 0.4),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha:0.1),
              border: Border.all(
                color: primaryColor,
                width: 2,
              ),
            ),
            child: Icon(
              CupertinoIcons.checkmark,
              size: 24,
              color: primaryColor,
            ),
          ),
        );
      },
    );
  }

  /// Error state icon
  Widget _buildErrorIcon(bool isDark) {
    final errorColor = isDark ? Colors.red.shade400 : Colors.red.shade600;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: errorColor.withValues(alpha:0.1),
        border: Border.all(
          color: errorColor,
          width: 2,
        ),
      ),
      child: Icon(
        CupertinoIcons.exclamationmark,
        size: 24,
        color: errorColor,
      ),
    );
  }

  /// Modern empty state widget when no feeds are available
  Widget _buildNoFeedsEmptyState(bool isDark) {
    final primaryTextColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;
    final l10n = AppLocalizations.of(context)!;

    // Wrap in CustomScrollView with pull-to-refresh
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _refreshNews,
          refreshTriggerPullDistance: 100.0,
          refreshIndicatorExtent: 80.0,
          builder: (context, refreshState, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
            return _buildModernRefreshIndicator(
              context,
              refreshState,
              pulledExtent,
              refreshTriggerPullDistance,
              refreshIndicatorExtent,
            );
          },
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Modern animated icon with entrance animation
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) => Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          CupertinoIcons.news,
                          size: 44,
                          color: accentColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  l10n.noFeedsTitle,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Description
                Text(
                  l10n.noFeedsDescription,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 16,
                    height: 1.5,
                    letterSpacing: -0.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Modern CTA button
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: CupertinoButton(
                    onPressed: () {
                      // Analytics: navigate to chat from empty state (internal event - not in schema)
                      AnalyticsService().capture(
                        'empty_state_navigate_to_chat',
                        properties: {
                          'source': 'no_feeds_empty_state',
                        },
                      );
                      // Navigate to feed creator using NavigationService
                      NavigationService().navigateToFeedCreator();
                    },
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: accentColor,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.plus,
                          size: 20,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.goToChat,
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Checks if there are any feeds currently being created (isCreatingFinished == false)
  bool _hasEmptyFeeds() {
    final creatingFeeds = _categories.where((feed) => feed.isCreatingFinished == false).toList();
    return creatingFeeds.isNotEmpty;
  }

  /// Starts polling for new posts in empty feeds
  void _startFeedPolling() {
    _stopFeedPolling(); // Stop existing timer first
    _feedPollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkForNewPosts();
    });
  }

  /// Stops polling for new posts
  void _stopFeedPolling() {
    _feedPollingTimer?.cancel();
    _feedPollingTimer = null;
  }

  /// Checks for feed creation status changes and updates UI
  Future<void> _checkForNewPosts() async {
    if (!mounted) return;

    try {
      final categoriesRaw = await NewsService.getUserFeeds();

      // Check if any feeds changed their creation status or if category list changed
      bool hasCreationStatusChange = false;
      bool hasCategoryListChange = false;

      // Check for new categories or removed categories
      final oldCategoryIds = _categories.map((c) => c.id).toSet();
      final newCategoryIds = categoriesRaw.map((c) => c.id).toSet();
      hasCategoryListChange = !oldCategoryIds.containsAll(newCategoryIds) ||
                              !newCategoryIds.containsAll(oldCategoryIds);

      // Only check creation status if category list is the same
      if (!hasCategoryListChange) {
        for (final category in categoriesRaw) {
          try {
            final oldCategory = _categories.firstWhere((c) => c.id == category.id);

            // Only check if isCreatingFinished changed (this is what triggers feed ready)
            if (oldCategory.isCreatingFinished != category.isCreatingFinished) {
              hasCreationStatusChange = true;
              break;
            }
          } catch (e) {
            // Category not found - shouldn't happen since we checked IDs
          }
        }
      }

      // Only update if there's a meaningful change
      if ((hasCreationStatusChange || hasCategoryListChange) && mounted) {
        // Update UI dynamically with smooth transition
        final Map<String, Feed> unique = {};
        for (final c in categoriesRaw) {
          unique[c.id] = c;
        }
        final categories = _sortCategoriesByUnseenStatus(unique.values.toList());

        // Find the new index of the currently selected category to prevent unexpected switching
        int? newSelectedIndex;
        if (_selectedCategoryId != null) {
          newSelectedIndex = categories.indexWhere((cat) => cat.id == _selectedCategoryId);
          if (newSelectedIndex == -1) newSelectedIndex = null;
        }

        setState(() {
          // Update categories with new creation status
          _categories = categories;
          // DON'T update _filteredNewsItems here - posts are managed separately
          // This prevents flickering when only category metadata changed
        });

        // Sync PageController to maintain the currently viewed feed after reordering
        if (newSelectedIndex != null && _categoryPageController.hasClients) {
          final indexToJumpTo = newSelectedIndex; // Capture non-null value for closure
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _categoryPageController.hasClients && indexToJumpTo < categories.length) {
              _categoryPageController.jumpToPage(indexToJumpTo);
            }
          });
        }

        // Stop polling if no more feeds being created
        if (!_hasEmptyFeeds()) {
          _stopFeedPolling();
        }

        // Analytics: feed status changed
        AnalyticsService().capture(EventSchema.feedStatusChanged, properties: {
          'feed_id': '', // Feed-specific tracking not available in polling context
          'status': hasCreationStatusChange ? 'creation_status' : 'updated',
        });
      }
    } catch (e) {
      // Silently fail - no UI feedback for polling errors
    }
  }
}
