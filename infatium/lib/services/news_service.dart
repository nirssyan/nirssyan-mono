import '../models/news_item.dart';
import '../models/feed_models.dart';
import '../models/digest_models.dart';
import '../models/source_validation_models.dart';
import '../models/paginated_posts_response.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'analytics_service.dart';
import 'feed_cache_service.dart';
import 'authenticated_http_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NewsService {
  // Authenticated HTTP client for automatic 401 retry
  static final AuthenticatedHttpClient _httpClient = AuthenticatedHttpClient();

  // Структура для возвращения новостей и категорий
  static Map<String, dynamic>? _lastFetchedData;

  // Raw feed data from API (includes unread_count field)
  static List<dynamic>? _lastRawFeedData;

  /// Очищает статические кэши лент
  static void clearCache() {
    _lastFetchedData = null;
    _lastRawFeedData = null;
  }

  /// Update isCreatingFinished status for a specific feed in cache
  /// Called when first post is created via WebSocket
  static void markFeedAsCreated(String feedId) {
    final cache = FeedCacheService();

    // Update cached feeds
    final cachedFeeds = cache.getCachedFeeds();
    if (cachedFeeds != null) {
      final updatedFeeds = cachedFeeds.map((feed) {
        if (feed.id == feedId && feed.isCreatingFinished != true) {
          print('[NewsService] Marking feed as created: $feedId');
          return feed.copyWith(isCreatingFinished: true);
        }
        return feed;
      }).toList();
      cache.cacheFeeds(updatedFeeds);
    }

    // Update _lastFetchedData if present
    if (_lastFetchedData != null && _lastFetchedData!.containsKey('feeds')) {
      final feeds = _lastFetchedData!['feeds'] as List<Feed>;
      _lastFetchedData!['feeds'] = feeds.map((feed) {
        if (feed.id == feedId && feed.isCreatingFinished != true) {
          return feed.copyWith(isCreatingFinished: true);
        }
        return feed;
      }).toList();
    }
  }

  /// Метод для отладки - показывает текущий user ID
  static String? getCurrentUserId() {
    final user = AuthService().currentUser;
    return user?.id;
  }

  /// Получает все новости пользователя из его лент через HTTP API
  static Future<List<NewsItem>> fetchUserFeeds() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        // User not authenticated
        return [];
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/feeds');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': ApiConfig.apiKey,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final response = await _httpClient.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;

        if (data.isEmpty) {
          return [];
        }

        // /feeds now returns only metadata, no posts
        // Posts are fetched via /posts/feed/{feed_id}
        return [];
      } else {
        return [];
      }
    } catch (e) {
      print('NewsService: Error fetching all feeds: $e');
      return [];
    }
  }

  /// Получает новости конкретной ленты через HTTP API
  static Future<List<NewsItem>> fetchFeedNews(String feedId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        // User not authenticated
        return [];
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/feeds?feed_id=$feedId');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': ApiConfig.apiKey,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final response = await _httpClient.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;

        if (data.isEmpty) {
          return [];
        }

        List<NewsItem> news = [];
        for (final feedData in data) {
          if (feedData is! Map<String, dynamic>) continue;

          // API теперь возвращает ленты напрямую, а не через users_feeds
          final feed = Feed.fromJson(feedData);

          for (final post in feed.posts) {
            final newsItem = _convertPostToNewsItem(post, feed);
            news.add(newsItem);
          }
        }

        news.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        return news;
      } else {
        return [];
      }
    } catch (e) {
      print('NewsService: Error fetching feed news: $e');
      return [];
    }
  }

  /// Fetches paginated posts for a specific feed
  /// GET /posts/feed/{feed_id}?cursor=&limit=20
  /// Returns PaginatedPostsResponse or null on error
  static Future<PaginatedPostsResponse?> fetchPostsPage({
    required String feedId,
    String? cursor,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cache = FeedCacheService();

    try {
      final user = AuthService().currentUser;
      if (user == null) {
        return null;
      }

      // For initial load (no cursor), check cache first
      if (cursor == null && !forceRefresh) {
        // Return valid cache immediately
        final cached = cache.getCachedPosts(feedId);
        if (cached != null && cached.isValid) {
          return PaginatedPostsResponse(
            posts: cached.posts,
            nextCursor: cached.nextCursor,
            hasMore: cached.hasMore,
            totalCount: cached.totalCount,
          );
        }

        // Stale-while-revalidate: return expired cache while refreshing in background
        final staleCache = cache.getCachedPostsIgnoreExpiry(feedId);
        if (staleCache != null && staleCache.posts.isNotEmpty) {
          // Start background refresh (don't await)
          _refreshPostsInBackground(feedId, limit);
          return PaginatedPostsResponse(
            posts: staleCache.posts,
            nextCursor: staleCache.nextCursor,
            hasMore: staleCache.hasMore,
            totalCount: staleCache.totalCount,
          );
        }
      }

      // Set loading state
      cache.setLoadingPosts(feedId, true);

      // Build URL with query params
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/posts/feed/$feedId')
          .replace(queryParameters: queryParams);

      final headers = {
        ...ApiConfig.commonHeaders,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final response = await _httpClient.get(
        uri,
        headers: headers,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // DEBUG: Log first post's media fields for comparison with fetchPostById
        final posts = data['posts'] as List<dynamic>?;
        if (posts != null && posts.isNotEmpty) {
          final firstPost = posts[0] as Map<String, dynamic>;
          print('[NewsService] fetchPostsPage first post media fields:');
          print('  media_objects: ${firstPost['media_objects']}');
          print('  media_urls: ${firstPost['media_urls']}');
          print('  image_url: ${firstPost['image_url']}');
        }

        final result = PaginatedPostsResponse.fromJson(data);

        // Update cache
        if (cursor == null) {
          // Initial load - replace cache
          cache.cacheInitialPosts(feedId, result);
        } else {
          // Pagination - append to cache
          cache.appendPosts(feedId, result);
        }

        return result;
      } else {
        // If offline, try to return cached data
        if (cache.isOffline) {
          final cached = cache.getCachedPosts(feedId);
          if (cached != null) {
            return PaginatedPostsResponse(
              posts: cached.posts,
              nextCursor: cached.nextCursor,
              hasMore: cached.hasMore,
              totalCount: cached.totalCount,
            );
          }
        }

        return null;
      }
    } catch (e) {
      print('[NewsService] fetchPostsPage: Exception: $e');

      // On network error, mark as offline and return cached data if available
      cache.setOfflineState(true);

      final cached = cache.getCachedPosts(feedId);
      if (cached != null) {
        print('[NewsService] fetchPostsPage: Returning cached data due to exception');
        return PaginatedPostsResponse(
          posts: cached.posts,
          nextCursor: cached.nextCursor,
          hasMore: cached.hasMore,
          totalCount: cached.totalCount,
        );
      }

      return null;
    } finally {
      cache.setLoadingPosts(feedId, false);
    }
  }

  /// Refresh posts in background and update cache (stale-while-revalidate)
  static void _refreshPostsInBackground(String feedId, int limit) async {
    final cache = FeedCacheService();

    try {
      final user = AuthService().currentUser;
      if (user == null) return;

      final uri = Uri.parse('${ApiConfig.baseUrl}/posts/feed/$feedId')
          .replace(queryParameters: {'limit': limit.toString()});

      final headers = {
        ...ApiConfig.commonHeaders,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final response = await _httpClient.get(
        uri,
        headers: headers,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final result = PaginatedPostsResponse.fromJson(data);
        cache.cacheInitialPosts(feedId, result);
      }
    } catch (e) {
      print('[NewsService] Background refresh failed for feed $feedId: $e');
    }
  }

  /// Convert Post to NewsItem (public version for external use)
  static NewsItem convertPostToNewsItem(Post post, Feed feed) {
    return _convertPostToNewsItem(post, feed);
  }

  /// Конвертирует Post в NewsItem для совместимости с UI
  static NewsItem _convertPostToNewsItem(Post post, Feed feed) {
    final List<String> normalizedMediaUrls = (post.mediaUrls.isNotEmpty)
        ? post.mediaUrls
        : (post.imageUrl != null && post.imageUrl!.isNotEmpty)
        ? [post.imageUrl!]
        : const [];

    // Берем первую непустую ссылку источника, если есть
    String? firstValidLink;
    for (final source in post.sources) {
      final url = source.sourceUrl;
      if (url != null && url.isNotEmpty) {
        firstValidLink = url;
        break;
      }
    }

    return NewsItem(
      feedId: post.feedId, // Use post.feedId for correct feed assignment
      id: post.id,
      title: post.title,
      subtitle: post.views.values.isNotEmpty ? post.views.values.first : '',
      content: post.views.values.length > 1 ? post.views.values.last : (post.views.values.isNotEmpty ? post.views.values.first : ''),
      imageUrl: (normalizedMediaUrls.isNotEmpty)
          ? normalizedMediaUrls.first
          : _getEmojiForCategory(feed.name),
      mediaUrls: normalizedMediaUrls,
      mediaObjects: post.mediaObjects,
      source: feed.name,
      publishedAt: post.createdAt,
      category: feed.name,
      link: firstValidLink,
      // Views field no longer displayed in UI (was showing content variation count)
      contentViews: post.views, // Full map used for content switching in detail page
      sources: post.sources,
      seen: post.seen,
      feedType: feed.type,
    );
  }

  static String _getEmojiForCategory(String category) {
    String lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('политика') ||
        lowerCategory.contains('политик')) {
      return '🏛️';
    } else if (lowerCategory.contains('котик') ||
        lowerCategory.contains('кошк')) {
      return '🐱';
    } else if (lowerCategory.contains('техник') ||
        lowerCategory.contains('технолог')) {
      return '💻';
    } else if (lowerCategory.contains('спорт')) {
      return '⚽';
    } else if (lowerCategory.contains('финанс') ||
        lowerCategory.contains('экономик')) {
      return '💰';
    } else if (lowerCategory.contains('наука')) {
      return '🔬';
    } else if (lowerCategory.contains('развлечен') ||
        lowerCategory.contains('кино')) {
      return '🎬';
    } else if (lowerCategory.contains('здоровье') ||
        lowerCategory.contains('медицин')) {
      return '🏥';
    } else if (lowerCategory.contains('путешеств')) {
      return '✈️';
    } else if (lowerCategory.contains('еда') ||
        lowerCategory.contains('кулинар')) {
      return '🍽️';
    } else {
      return '📰';
    }
  }

  /// Gets user feeds from cached data (no HTTP request)
  /// Call fetchUserFeedsHTTP() first to populate the cache
  static Future<List<Feed>> getUserFeeds() async {
    // First, check _lastFetchedData (populated by fetchUserFeedsHTTP)
    if (_lastFetchedData != null && _lastFetchedData!.containsKey('feeds')) {
      return _lastFetchedData!['feeds'] as List<Feed>;
    }

    // Fallback to FeedCacheService
    final cache = FeedCacheService();
    final cachedFeeds = cache.getCachedFeeds();
    if (cachedFeeds != null) {
      return cachedFeeds;
    }

    // No data available - should call fetchUserFeedsHTTP first
    return [];
  }

  /// Extract unread counts from fetched feeds data
  /// Returns a map of feedId -> unread count
  static Map<String, int> getUnreadCountsFromCache() {
    if (_lastRawFeedData == null || _lastRawFeedData!.isEmpty) {
      return {};
    }

    final Map<String, int> counts = {};

    for (var item in _lastRawFeedData!) {
      if (item is Map<String, dynamic> &&
          item.containsKey('id') &&
          item.containsKey('unread_count')) {
        final feedId = item['id'] as String;
        final unreadCount = item['unread_count'] as int? ?? 0;
        counts[feedId] = unreadCount;
      }
    }

    return counts;
  }

  static Future<List<NewsItem>> fetchUserFeedsHTTP({bool forceRefresh = false}) async {
    final cache = FeedCacheService();

    try {
      final user = AuthService().currentUser;
      if (user == null) {
        // User not authenticated
        return [];
      }

      // Check cache first (unless forcing refresh)
      if (!forceRefresh) {
        final cachedFeeds = cache.getCachedFeeds();
        if (cachedFeeds != null) {
          cache.setOfflineState(false);

          // Feeds are cached, posts are loaded via pagination
          _lastFetchedData = {'news': <NewsItem>[], 'feeds': cachedFeeds};

          // Return empty - posts loaded via fetchPostsPage()
          return [];
        }
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/feeds');

      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': ApiConfig.apiKey,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final response = await _httpClient.get(
        url,
        headers: headers,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        // Safely decode JSON with validation
        final dynamic decoded;
        try {
          decoded = json.decode(response.body);
        } catch (e) {
          print('[NewsService] fetchUserFeedsHTTP: Invalid JSON response: $e');
          // Return cached feeds on JSON error
          final cachedFeeds = cache.getCachedFeeds();
          if (cachedFeeds != null) {
            _lastFetchedData = {'news': <NewsItem>[], 'feeds': cachedFeeds};
          }
          return [];
        }

        if (decoded is! List) {
          print('[NewsService] fetchUserFeedsHTTP: Response is not a list');
          final cachedFeeds = cache.getCachedFeeds();
          if (cachedFeeds != null) {
            _lastFetchedData = {'news': <NewsItem>[], 'feeds': cachedFeeds};
          }
          return [];
        }
        final List<dynamic> data = decoded;

        // Store raw feed data (includes unread_count)
        _lastRawFeedData = data;

        // Mark as online since request succeeded
        cache.setOfflineState(false);

        if (data.isEmpty) {
          // Cache empty result
          cache.cacheFeeds([]);
          return [];
        }

        List<Feed> feeds = [];

        for (final feedData in data) {
          if (feedData is! Map<String, dynamic>) {
            continue;
          }

          // /feeds возвращает только метаданные фидов (без постов)
          final feed = Feed.fromJson(feedData);
          // Пропускаем пустые ленты без имени
          if (feed.name.isEmpty) {
            continue;
          }

          // Добавляем ленту в список категорий
          feeds.add(feed);
        }

        // Cache feeds (only metadata, no posts)
        cache.cacheFeeds(feeds);

        // Сохраняем данные для использования в других методах
        // Posts will be loaded via fetchPostsPage() for each feed
        _lastFetchedData = {'news': <NewsItem>[], 'feeds': feeds};

        // Return empty list - posts are loaded via pagination
        return [];
      } else {
        // Try to return cached feeds on error (for feed list)
        final cachedFeeds = cache.getCachedFeeds();
        if (cachedFeeds != null) {
          _lastFetchedData = {'news': <NewsItem>[], 'feeds': cachedFeeds};
        }

        return [];
      }
    } catch (e) {
      print('[NewsService] fetchUserFeedsHTTP: Exception: $e');

      // Mark as offline
      cache.setOfflineState(true);

      // Return cached feeds if available (for feed list)
      final cachedFeeds = cache.getCachedFeeds();
      if (cachedFeeds != null) {
        _lastFetchedData = {'news': <NewsItem>[], 'feeds': cachedFeeds};
      }

      // Return empty - posts loaded via pagination
      return [];
    }
  }

  /// Check creation status of a specific feed
  /// Returns null if feed not found
  static Future<Feed?> checkFeedStatus(String feedId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        return null;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/feeds');

      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': ApiConfig.apiKey,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final response = await _httpClient.get(
        url,
        headers: headers,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feedsData = data['feeds'] as List<dynamic>? ?? [];

        // Convert to Feed objects
        final feeds = feedsData.map((feedData) {
          return Feed.fromJson(feedData as Map<String, dynamic>);
        }).toList();

        // Find specific feed
        final feed = feeds.cast<Feed?>().firstWhere(
          (f) => f?.id == feedId,
          orElse: () => null,
        );

        if (feed != null) {
          return feed;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      print('[NewsService] Error checking feed status: $e');
      return null;
    }
  }

  /// Удаляет подписку пользователя на ленту
  static Future<bool> deleteFeedSubscription(String feedId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        return false;
      }

      // Используем n8n webhook endpoint с feed_id в query параметрах
      final url = Uri.parse('${ApiConfig.baseUrl}/users_feeds?feed_id=$feedId');
      final headers = {
        ...ApiConfig.commonHeaders,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final body = json.encode({
        'user_id': user.id,
      });

      final response = await _httpClient.delete(url, headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Очищаем кешированные данные
        _lastFetchedData = null;
        // Invalidate FeedCacheService
        FeedCacheService().invalidateAll();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Переименовывает ленту
  static Future<bool> renameFeed(String feedId, String newName) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        return false;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/feeds/rename');
      final headers = {
        ...ApiConfig.commonHeaders,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final body = json.encode({
        'feed_id': feedId,
        'new_name': newName,
        'user_id': user.id,
      });

      final response = await _httpClient.post(url, headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Очищаем кешированные данные
        _lastFetchedData = null;
        // Invalidate FeedCacheService
        FeedCacheService().invalidateFeedsList();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Отмечает посты как просмотренные
  static Future<bool> markPostsAsSeen(List<String> postIds) async {
    if (postIds.isEmpty) {
      return false;
    }

    try {
      final user = AuthService().currentUser;
      if (user == null) {
        return false;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/posts/seen');
      final headers = {
        ...ApiConfig.commonHeaders,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final body = json.encode({
        'post_ids': postIds,
      });

      final response = await _httpClient.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Отмечает все посты в ленте как прочитанные
  /// Returns a map with 'success' and 'marked_count' keys
  static Future<Map<String, dynamic>> markAllPostsAsRead(String feedId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        return {'success': false, 'marked_count': 0};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/feeds/read_all/$feedId');
      final headers = {
        ...ApiConfig.commonHeaders,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final response = await _httpClient.post(url, headers: headers);

      if (response.statusCode == 200) {
        // Parse response
        try {
          final responseData = json.decode(response.body);
          final success = responseData['success'] ?? false;
          final markedCount = responseData['marked_count'] ?? 0;
          final message = responseData['message'] ?? '';

          // Clear cached data since posts were updated
          _lastFetchedData = null;

          return {
            'success': success,
            'marked_count': markedCount,
            'message': message,
          };
        } catch (e) {
          return {'success': false, 'marked_count': 0};
        }
      } else {
        return {'success': false, 'marked_count': 0};
      }
    } catch (e) {
      return {'success': false, 'marked_count': 0};
    }
  }

  /// Summarizes unseen posts in a feed into a digest
  /// POST /feeds/summarize_unseen/{feed_id}
  /// Returns DigestResponse on success, null on error
  static Future<DigestResponse?> summarizeUnseenPosts(String feedId) async {
    print('========== summarizeUnseenPosts DEBUG ==========');
    print('feedId: $feedId');

    try {
      final user = AuthService().currentUser;
      if (user == null) {
        print('ERROR: user is null, returning');
        return null;
      }
      print('user.id: ${user.id}');

      final url = Uri.parse('${ApiConfig.baseUrl}/feeds/summarize_unseen/$feedId');
      final headers = {
        ...ApiConfig.commonHeaders,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      print('REQUEST URL: $url');
      print('REQUEST HEADERS: $headers');

      final response = await _httpClient.post(
        url,
        headers: headers,
        timeout: const Duration(seconds: 30),
      );

      print('RESPONSE statusCode: ${response.statusCode}');
      print('RESPONSE headers: ${response.headers}');
      print('RESPONSE body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('PARSED JSON: $data');

        // Clear cached data since posts were marked as seen
        _lastFetchedData = null;

        final digest = DigestResponse.fromJson(data);
        print('DigestResponse created:');
        print('  - id: ${digest.id}');
        print('  - markedAsSeenCount: ${digest.markedAsSeenCount}');
        print('========== summarizeUnseenPosts SUCCESS ==========');
        return digest;
      } else {
        print('ERROR: Non-201 status code: ${response.statusCode}');
        print('ERROR body: ${response.body}');
        print('========== summarizeUnseenPosts FAILED ==========');
        return null;
      }
    } catch (e, stackTrace) {
      print('summarizeUnseenPosts: Exception: $e');
      print('summarizeUnseenPosts: StackTrace: $stackTrace');
      print('========== summarizeUnseenPosts EXCEPTION ==========');
      return null;
    }
  }

  /// Fetches a single post by ID
  /// GET /posts/{post_id}
  /// Returns Post on success, null on error
  static Future<Post?> fetchPostById(String postId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        return null;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/posts/$postId');
      final headers = {
        ...ApiConfig.commonHeaders,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final response = await _httpClient.get(
        url,
        headers: headers,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // DEBUG: Log media fields from API response
        print('[NewsService] fetchPostById response for $postId:');
        print('  views: ${data['views']}');
        print('  media_objects: ${data['media_objects']}');
        print('  media_urls: ${data['media_urls']}');
        print('  image_url: ${data['image_url']}');

        return Post.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('[NewsService] fetchPostById: Exception: $e');
      return null;
    }
  }

  /// Validates a source URL or Telegram handle
  /// POST /sources/validate
  /// Returns SourceValidationResponse on success, null on network/server error
  static Future<SourceValidationResponse?> validateSource(String source) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        return null;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/sources/validate');
      final headers = {
        ...ApiConfig.commonHeaders,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final body = json.encode({'source': source});

      final response = await _httpClient.post(
        url,
        headers: headers,
        body: body,
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return SourceValidationResponse.fromJson(data);
      } else if (response.statusCode == 422) {
        // 422 = source format/content invalid → treat as invalid source
        return SourceValidationResponse(isValid: false);
      } else {
        return null;
      }
    } catch (e) {
      print('validateSource: Exception: $e');
      return null;
    }
  }

  /// Subscribe to a feed by ID (via deep link).
  ///
  /// POST /feeds/subscribe
  /// Body: {"feed_id": feedId}
  /// Returns true on success, false on error.
  ///
  /// TODO: Backend endpoint not ready yet. Currently uses stub implementation.
  /// When backend is ready, uncomment the HTTP call below.
  static Future<bool> subscribeFeed(String feedId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        return false;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/feeds/subscribe');
      final headers = {
        ...ApiConfig.commonHeaders,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final body = json.encode({
        'feed_id': feedId,
      });

      final response = await _httpClient.post(
        url,
        headers: headers,
        body: body,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        // Clear cache and refresh feeds
        _lastFetchedData = null;
        FeedCacheService().invalidateAll();
        await fetchUserFeedsHTTP(forceRefresh: true);
        return true;
      } else if (response.statusCode == 409) {
        // Already subscribed — treat as success
        print('[NewsService] subscribeFeed: Already subscribed to $feedId');
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('[NewsService] subscribeFeed: Exception: $e');
      return false;
    }
  }

  /// Fetch unread post counts for all user feeds
  /// Returns a map of feedId -> unread count
  static Future<Map<String, int>> fetchUnreadCounts() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        return {};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/api/feeds/unread_counts?user_id=${user.id}');
      final headers = {
        ...ApiConfig.commonHeaders,
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      };

      final response = await _httpClient.get(
        url,
        headers: headers,
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final Map<String, int> counts = {};

        if (data.containsKey('feeds') && data['feeds'] is List) {
          for (var item in data['feeds']) {
            if (item is Map && item.containsKey('feed_id') && item.containsKey('unread_count')) {
              counts[item['feed_id'] as String] = item['unread_count'] as int;
            }
          }
        }

        return counts;
      } else {
        return {};
      }
    } catch (e) {
      print('[NewsService] fetchUnreadCounts: Exception: $e');
      return {};
    }
  }
}
