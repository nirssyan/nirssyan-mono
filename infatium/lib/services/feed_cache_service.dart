import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../models/feed_models.dart';
import '../models/paginated_posts_response.dart';

/// Cache state for posts within a single feed
class FeedPostsCache {
  List<Post> posts;
  String? nextCursor;
  bool hasMore;
  int totalCount;
  DateTime cachedAt;

  FeedPostsCache({
    required this.posts,
    this.nextCursor,
    required this.hasMore,
    required this.totalCount,
    required this.cachedAt,
  });

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > FeedCacheService.postsTTL;

  bool get isValid => !isExpired;
}

/// Service for smart feed and posts caching with TTL
class FeedCacheService extends ChangeNotifier {
  static final FeedCacheService _instance = FeedCacheService._internal();
  factory FeedCacheService() => _instance;
  FeedCacheService._internal();

  // TTL constants
  static const Duration feedsTTL = Duration(minutes: 5);
  static const Duration postsTTL = Duration(minutes: 15);

  // Feeds cache
  List<Feed>? _cachedFeeds;
  DateTime? _feedsCachedAt;

  // Posts cache per feed: feedId -> FeedPostsCache
  final Map<String, FeedPostsCache> _postsCache = {};

  // Offline state
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  // Loading states
  bool _isFeedsLoading = false;
  bool get isFeedsLoading => _isFeedsLoading;

  final Map<String, bool> _isLoadingPosts = {};

  // ============================================================
  // FEEDS CACHE
  // ============================================================

  /// Get cached feeds if valid, null otherwise
  List<Feed>? getCachedFeeds() {
    if (_cachedFeeds == null || _feedsCachedAt == null) {
      return null;
    }

    if (!isFeedsCacheValid()) {
      log('[FeedCacheService] Feeds cache expired');
      return null;
    }

    log('[FeedCacheService] Returning ${_cachedFeeds!.length} cached feeds');
    return _cachedFeeds;
  }

  /// Cache feeds list
  void cacheFeeds(List<Feed> feeds) {
    _cachedFeeds = List.from(feeds);
    _feedsCachedAt = DateTime.now();
    log('[FeedCacheService] Cached ${feeds.length} feeds');
    notifyListeners();
  }

  /// Check if feeds cache is valid (not expired)
  bool isFeedsCacheValid() {
    if (_feedsCachedAt == null) return false;
    return DateTime.now().difference(_feedsCachedAt!) < feedsTTL;
  }

  /// Get feeds cache age in seconds
  int? getFeedsCacheAgeSeconds() {
    if (_feedsCachedAt == null) return null;
    return DateTime.now().difference(_feedsCachedAt!).inSeconds;
  }

  // ============================================================
  // POSTS CACHE (per feed)
  // ============================================================

  /// Get cached posts for a feed (only if not expired)
  FeedPostsCache? getCachedPosts(String feedId) {
    final cached = _postsCache[feedId];
    if (cached == null) {
      return null;
    }

    if (cached.isExpired) {
      log('[FeedCacheService] Posts cache expired for feed $feedId');
      return null;
    }

    log('[FeedCacheService] Returning ${cached.posts.length} cached posts for feed $feedId');
    return cached;
  }

  /// Get cached posts even if expired (for showing stale data while loading)
  FeedPostsCache? getCachedPostsIgnoreExpiry(String feedId) {
    return _postsCache[feedId];
  }

  /// Check if posts cache exists (regardless of expiry)
  bool hasAnyPostsCache(String feedId) {
    final cached = _postsCache[feedId];
    return cached != null && cached.posts.isNotEmpty;
  }

  /// Get cached feeds even if expired (for showing stale data while loading)
  List<Feed>? getCachedFeedsIgnoreExpiry() {
    return _cachedFeeds;
  }

  /// Cache initial posts for a feed (replaces existing cache)
  void cacheInitialPosts(String feedId, PaginatedPostsResponse response) {
    _postsCache[feedId] = FeedPostsCache(
      posts: List.from(response.posts),
      nextCursor: response.nextCursor,
      hasMore: response.hasMore,
      totalCount: response.totalCount,
      cachedAt: DateTime.now(),
    );
    log('[FeedCacheService] Cached ${response.posts.length} initial posts for feed $feedId (hasMore: ${response.hasMore})');
    notifyListeners();
  }

  /// Append more posts to existing cache (pagination)
  void appendPosts(String feedId, PaginatedPostsResponse response) {
    final existing = _postsCache[feedId];
    if (existing == null) {
      // No existing cache, treat as initial
      cacheInitialPosts(feedId, response);
      return;
    }

    // Append new posts (avoid duplicates by ID)
    final existingIds = existing.posts.map((p) => p.id).toSet();
    final newPosts = response.posts.where((p) => !existingIds.contains(p.id)).toList();

    existing.posts.addAll(newPosts);
    existing.nextCursor = response.nextCursor;
    existing.hasMore = response.hasMore;
    existing.totalCount = response.totalCount;
    existing.cachedAt = DateTime.now();

    log('[FeedCacheService] Appended ${newPosts.length} posts to feed $feedId (total: ${existing.posts.length}, hasMore: ${existing.hasMore})');
    notifyListeners();
  }

  /// Get next cursor for a feed
  String? getNextCursor(String feedId) {
    return _postsCache[feedId]?.nextCursor;
  }

  /// Check if feed has more posts to load
  bool hasMorePosts(String feedId) {
    return _postsCache[feedId]?.hasMore ?? true; // Default true for uncached feeds
  }

  /// Check if feed posts are being loaded
  bool isLoadingPosts(String feedId) {
    return _isLoadingPosts[feedId] ?? false;
  }

  /// Set loading state for feed posts
  void setLoadingPosts(String feedId, bool isLoading) {
    _isLoadingPosts[feedId] = isLoading;
    notifyListeners();
  }

  /// Get total count for a feed (from cache)
  int? getTotalCount(String feedId) {
    return _postsCache[feedId]?.totalCount;
  }

  // ============================================================
  // REAL-TIME UPDATES
  // ============================================================

  /// Insert a new post at the beginning of feed's post list (for real-time updates)
  void insertPost(String feedId, Post post) {
    final cache = _postsCache[feedId];
    if (cache != null) {
      // Check for duplicates
      if (!cache.posts.any((p) => p.id == post.id)) {
        cache.posts.insert(0, post);
        cache.totalCount++;
        log('[FeedCacheService] Inserted new post ${post.id} to feed $feedId (total: ${cache.posts.length})');
        notifyListeners();
      } else {
        log('[FeedCacheService] Post ${post.id} already exists in feed $feedId, skipping');
      }
    } else {
      // No cache for this feed yet - create one with this post
      _postsCache[feedId] = FeedPostsCache(
        posts: [post],
        nextCursor: null,
        hasMore: true, // Assume there may be more posts on server
        totalCount: 1,
        cachedAt: DateTime.now(),
      );
      log('[FeedCacheService] Created new cache for feed $feedId with post ${post.id}');
      notifyListeners();
    }
  }

  /// Update an existing post in cache
  void updatePost(String feedId, String postId, Post updatedPost) {
    final cache = _postsCache[feedId];
    if (cache != null) {
      final index = cache.posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        cache.posts[index] = updatedPost;
        log('[FeedCacheService] Updated post $postId in feed $feedId');
        notifyListeners();
      }
    }
  }

  /// Delete a post from cache
  void deletePost(String feedId, String postId) {
    final cache = _postsCache[feedId];
    if (cache != null) {
      cache.posts.removeWhere((p) => p.id == postId);
      if (cache.totalCount > 0) {
        cache.totalCount--;
      }
      log('[FeedCacheService] Deleted post $postId from feed $feedId');
      notifyListeners();
    }
  }

  // ============================================================
  // INVALIDATION
  // ============================================================

  /// Invalidate all caches
  void invalidateAll() {
    _cachedFeeds = null;
    _feedsCachedAt = null;
    _postsCache.clear();
    _isLoadingPosts.clear();
    log('[FeedCacheService] All caches invalidated');
    notifyListeners();
  }

  /// Invalidate specific feed's posts cache
  void invalidateFeedPosts(String feedId) {
    _postsCache.remove(feedId);
    _isLoadingPosts.remove(feedId);
    log('[FeedCacheService] Posts cache invalidated for feed $feedId');
    notifyListeners();
  }

  /// Invalidate feeds list cache only
  void invalidateFeedsList() {
    _cachedFeeds = null;
    _feedsCachedAt = null;
    log('[FeedCacheService] Feeds list cache invalidated');
    notifyListeners();
  }

  // ============================================================
  // OFFLINE STATE
  // ============================================================

  /// Set offline state
  void setOfflineState(bool isOffline) {
    if (_isOffline != isOffline) {
      _isOffline = isOffline;
      log('[FeedCacheService] Offline state changed: $isOffline');
      notifyListeners();
    }
  }

  /// Check if we have any cached data to show offline
  bool hasOfflineData() {
    return _cachedFeeds != null && _cachedFeeds!.isNotEmpty;
  }

  /// Check if we have cached posts for a specific feed
  bool hasOfflinePostsForFeed(String feedId) {
    final cached = _postsCache[feedId];
    return cached != null && cached.posts.isNotEmpty;
  }

  // ============================================================
  // STATS & DEBUG
  // ============================================================

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'feeds_cached': _cachedFeeds?.length ?? 0,
      'feeds_cache_valid': isFeedsCacheValid(),
      'feeds_cache_age_seconds': getFeedsCacheAgeSeconds(),
      'posts_cache_entries': _postsCache.length,
      'posts_cache_feeds': _postsCache.keys.toList(),
      'is_offline': _isOffline,
      'loading_posts_feeds': _isLoadingPosts.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList(),
    };
  }

  /// Clear all data (for logout)
  void clearCache() {
    invalidateAll();
    _isOffline = false;
    log('[FeedCacheService] Cache cleared');
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}
