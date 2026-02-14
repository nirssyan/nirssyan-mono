import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'news_service.dart';

/// Service for managing seen posts state with local caching and batch API updates
class SeenPostsService extends ChangeNotifier {
  // Singleton pattern
  static final SeenPostsService _instance = SeenPostsService._internal();
  factory SeenPostsService() => _instance;
  SeenPostsService._internal() {
    _loadSeenPosts();
  }

  // Local cache of seen post IDs
  final Set<String> _seenPostIds = {};

  // Queue for posts that need to be marked as seen on the backend
  final Set<String> _pendingSeenPostIds = {};

  // Timer for batching API calls
  Timer? _debounceTimer;

  // SharedPreferences key
  static const String _storageKey = 'seen_posts';

  // Debounce duration for batching API calls
  static const Duration _debounceDuration = Duration(seconds: 2);

  /// Check if a post is marked as seen
  bool isPostSeen(String? postId) {
    if (postId == null) return false;
    return _seenPostIds.contains(postId);
  }

  /// Mark a single post as seen
  Future<void> markPostAsSeen(String? postId) async {
    if (postId == null || postId.isEmpty) return;

    // If already seen, do nothing
    if (_seenPostIds.contains(postId)) return;

    // Add to local cache immediately for instant UI update
    _seenPostIds.add(postId);
    _pendingSeenPostIds.add(postId);

    // Save to local storage
    await _saveSeenPosts();

    // Notify listeners for UI update
    notifyListeners();

    // Schedule batch API call
    _scheduleBatchUpdate();

  }

  /// Mark multiple posts as seen
  Future<void> markPostsAsSeen(List<String> postIds) async {
    if (postIds.isEmpty) return;

    bool hasNewPosts = false;

    for (final postId in postIds) {
      if (!_seenPostIds.contains(postId)) {
        _seenPostIds.add(postId);
        _pendingSeenPostIds.add(postId);
        hasNewPosts = true;
      }
    }

    if (hasNewPosts) {
      // Save to local storage
      await _saveSeenPosts();

      // Notify listeners for UI update
      notifyListeners();

      // Schedule batch API call
      _scheduleBatchUpdate();

    }
  }

  /// Schedule a batch update to the backend
  void _scheduleBatchUpdate() {
    // Cancel existing timer if any
    _debounceTimer?.cancel();

    // Schedule new batch update
    _debounceTimer = Timer(_debounceDuration, () {
      _sendBatchUpdate();
    });
  }

  /// Send batch update to the backend
  Future<void> _sendBatchUpdate() async {
    if (_pendingSeenPostIds.isEmpty) return;

    // Copy pending IDs to process
    final postIdsToSend = _pendingSeenPostIds.toList();


    try {
      // Call the API
      final success = await NewsService.markPostsAsSeen(postIdsToSend);

      if (success) {
        // Clear pending IDs on success
        _pendingSeenPostIds.removeAll(postIdsToSend);
      } else {
        // Keep pending IDs to retry later
      }
    } catch (e) {
      // Keep pending IDs to retry later
    }
  }

  /// Force send all pending updates (useful when app is closing)
  Future<void> forceSendPendingUpdates() async {
    _debounceTimer?.cancel();
    await _sendBatchUpdate();
  }

  /// Load seen posts from local storage
  Future<void> _loadSeenPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenPostsJson = prefs.getString(_storageKey);

      if (seenPostsJson != null) {
        final List<dynamic> seenPostsList = json.decode(seenPostsJson);
        _seenPostIds.clear();
        _seenPostIds.addAll(seenPostsList.cast<String>());

      }
    } catch (e) {
    }
  }

  /// Save seen posts to local storage
  Future<void> _saveSeenPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenPostsList = _seenPostIds.toList();

      // Keep only last 1000 posts to prevent storage bloat
      if (seenPostsList.length > 1000) {
        seenPostsList.removeRange(0, seenPostsList.length - 1000);
        _seenPostIds.clear();
        _seenPostIds.addAll(seenPostsList);
      }

      await prefs.setString(_storageKey, json.encode(seenPostsList));
    } catch (e) {
    }
  }

  /// Clear all seen posts (useful for logout)
  Future<void> clearSeenPosts() async {
    _seenPostIds.clear();
    _pendingSeenPostIds.clear();
    _debounceTimer?.cancel();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
    }

    notifyListeners();
  }

  /// Update seen posts from server data (when refreshing feeds)
  void updateSeenPostsFromServer(List<String> seenPostIds) {
    _seenPostIds.clear();
    _seenPostIds.addAll(seenPostIds);

    // Remove from pending if they're already marked on server
    _pendingSeenPostIds.removeAll(seenPostIds);

    // Save and notify
    _saveSeenPosts();
    notifyListeners();

  }

  /// Get total count of seen posts
  int get seenPostsCount => _seenPostIds.length;

  /// Get count of pending posts
  int get pendingPostsCount => _pendingSeenPostIds.length;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}