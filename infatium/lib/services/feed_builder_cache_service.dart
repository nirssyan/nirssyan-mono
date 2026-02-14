import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../models/feed_builder_models.dart';
import 'feed_builder_service.dart';

/// Service for smart session caching with automatic updates
class FeedBuilderCacheService extends ChangeNotifier {
  static final FeedBuilderCacheService _instance = FeedBuilderCacheService._internal();
  factory FeedBuilderCacheService() => _instance;
  FeedBuilderCacheService._internal();

  // Cache: Map<sessionId, FeedBuilderSession>
  final Map<String, FeedBuilderSession> _sessionsCache = {};

  // Session list in correct order (by activity)
  List<String> _sessionOrder = [];
  
  // Флаг загрузки
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  // Время последнего обновления
  DateTime? _lastUpdate;
  
  // Таймер для периодического обновления
  Timer? _refreshTimer;
  
  // Интервал автообновления (в секундах)
  static const int _autoRefreshInterval = 30;

  /// Get all sessions in correct order
  List<FeedBuilderSession> get sessions {
    return _sessionOrder
        .map((sessionId) => _sessionsCache[sessionId])
        .where((session) => session != null)
        .cast<FeedBuilderSession>()
        .toList();
  }

  /// Получить конкретный чат по ID
  FeedBuilderSession? getSession(String sessionId) {
    return _sessionsCache[sessionId];
  }

  /// Проверить есть ли чат в кеше
  bool hasSession(String sessionId) {
    return _sessionsCache.containsKey(sessionId);
  }

  /// Find first empty session (without messages) for reuse
  FeedBuilderSession? findEmptySession() {
    for (final session in sessions) {
      if (session.messages.isEmpty) {
        log('[FeedBuilderCacheService] Found empty session: ${session.sessionId}');
        return session;
      }
    }
    log('[FeedBuilderCacheService] No empty sessions found');
    return null;
  }

  /// Load all sessions (with cache update)
  Future<List<FeedBuilderSession>> loadSessions({bool forceRefresh = false}) async {
    log('[FeedBuilderCacheService] loadSessions called, forceRefresh: $forceRefresh');
    log('[FeedBuilderCacheService] Current cache state: ${_sessionsCache.length} sessions, loading: $_isLoading');

    if (_isLoading) {
      // If already loading, wait for completion
      log('[FeedBuilderCacheService] Already loading sessions, waiting...');
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      log('[FeedBuilderCacheService] Wait completed, returning ${sessions.length} cached sessions');
      return sessions;
    }

    // Check if we need to update
    if (!forceRefresh && _lastUpdate != null) {
      final timeSinceUpdate = DateTime.now().difference(_lastUpdate!);
      if (timeSinceUpdate.inSeconds < 10 && _sessionsCache.isNotEmpty) {
        log('[FeedBuilderCacheService] Using cached sessions (updated ${timeSinceUpdate.inSeconds}s ago)');
        return sessions;
      }
    }

    _isLoading = true;
    log('[FeedBuilderCacheService] Setting loading to true, notifying listeners');
    notifyListeners();

    try {
      log('[FeedBuilderCacheService] Loading sessions from server...');
      final fetchedSessions = await FeedBuilderService.fetchSessions();

      log('[FeedBuilderCacheService] Fetched ${fetchedSessions.length} sessions from server');

      // Update cache
      _updateCache(fetchedSessions);
      _lastUpdate = DateTime.now();

      log('[FeedBuilderCacheService] Updated cache with ${fetchedSessions.length} sessions, cache now has ${_sessionsCache.length} items');

      // Start auto-refresh if not already started
      _startAutoRefresh();

      log('[FeedBuilderCacheService] Successfully loaded ${fetchedSessions.length} sessions, returning ${sessions.length}');
      return sessions;
    } catch (e) {
      log('[FeedBuilderCacheService] Error loading sessions: $e');
      // On error, return cached data
      log('[FeedBuilderCacheService] Error occurred, returning ${sessions.length} cached sessions');
      return sessions;
    } finally {
      _isLoading = false;
      log('[FeedBuilderCacheService] Setting loading to false, notifying listeners');
      notifyListeners();
    }
  }

  /// Create new session and add to cache
  Future<String> createSession() async {
    try {
      log('[FeedBuilderCacheService] Creating new session...');
      final sessionId = await FeedBuilderService.createSession();

      // Create new session object and add to cache
      final newSession = FeedBuilderSession(
        sessionId: sessionId,
        createdAt: DateTime.now(),
        messages: [],
      );

      // Add to the beginning of the list (as most recent)
      _sessionsCache[sessionId] = newSession;
      _sessionOrder.insert(0, sessionId);

      log('[FeedBuilderCacheService] Created new session: $sessionId');
      notifyListeners();
      return sessionId;
    } catch (e) {
      log('[FeedBuilderCacheService] Error creating session: $e');
      rethrow;
    }
  }

  /// Delete session from cache and server
  Future<bool> deleteSession(String sessionId) async {
    try {
      log('[FeedBuilderCacheService] Deleting session: $sessionId');
      final success = await FeedBuilderService.deleteSession(sessionId);

      if (success) {
        // Remove from cache
        _sessionsCache.remove(sessionId);
        _sessionOrder.remove(sessionId);

        log('[FeedBuilderCacheService] Successfully deleted session: $sessionId');
        notifyListeners();
      }

      return success;
    } catch (e) {
      log('[FeedBuilderCacheService] Error deleting session: $e');
      rethrow;
    }
  }

  /// Add message to specific session cache
  void addMessageToSession(String sessionId, FeedBuilderMessage message) {
    final session = _sessionsCache[sessionId];
    if (session != null) {
      // Create new session object with updated messages
      final updatedMessages = List<FeedBuilderMessage>.from(session.messages)..add(message);
      final updatedSession = FeedBuilderSession(
        sessionId: session.sessionId,
        createdAt: session.createdAt,
        messages: updatedMessages,
      );

      _sessionsCache[sessionId] = updatedSession;

      // Move session to the beginning of the list (update activity)
      _sessionOrder.remove(sessionId);
      _sessionOrder.insert(0, sessionId);

      log('[FeedBuilderCacheService] Added message to session $sessionId, total messages: ${updatedMessages.length}');
      notifyListeners();
    }
  }

  /// Refresh specific session
  Future<FeedBuilderSession?> refreshSession(String sessionId) async {
    try {
      log('[FeedBuilderCacheService] Refreshing session: $sessionId');

      // Use seamless update
      await _silentRefresh();

      return _sessionsCache[sessionId];
    } catch (e) {
      log('[FeedBuilderCacheService] Error refreshing session: $e');
      return _sessionsCache[sessionId];
    }
  }

  /// Принудительное бесшовное обновление (для ручного вызова)
  Future<void> silentRefreshNow() async {
    await _silentRefresh();
  }

  /// Уведомить о активности пользователя (для оптимизации частоты обновлений)
  void notifyUserActivity() {
    // В будущем можно использовать для адаптивной частоты обновлений
    log('[FeedBuilderCacheService] User activity detected');
  }

  /// Update cache with new data
  void _updateCache(List<FeedBuilderSession> fetchedSessions) {
    // Clear old cache
    _sessionsCache.clear();
    _sessionOrder.clear();

    // Fill with new data
    for (final session in fetchedSessions) {
      _sessionsCache[session.sessionId] = session;
      _sessionOrder.add(session.sessionId);
    }

    log('[FeedBuilderCacheService] Updated cache with ${fetchedSessions.length} sessions');
  }

  /// Запустить автоматическое обновление
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    
    _refreshTimer = Timer.periodic(
      const Duration(seconds: _autoRefreshInterval),
      (timer) async {
        if (!_isLoading && hasListeners) {
          log('[FeedBuilderCacheService] Silent auto-refresh triggered');
          try {
            await _silentRefresh();
          } catch (e) {
            log('[FeedBuilderCacheService] Silent auto-refresh failed: $e');
          }
        } else if (!hasListeners) {
          log('[FeedBuilderCacheService] Skipping auto-refresh - no active listeners');
        }
      },
    );
    
    log('[FeedBuilderCacheService] Silent auto-refresh started (every ${_autoRefreshInterval}s)');
  }

  /// Seamless background refresh without showing loader
  Future<void> _silentRefresh() async {
    try {
      log('[FeedBuilderCacheService] Starting silent refresh...');

      // Load data directly via FeedBuilderService without changing loading state
      final fetchedSessions = await FeedBuilderService.fetchSessions();

      // Compare with current cache and update only if there are changes
      final hasChanges = _hasDataChanged(fetchedSessions);

      if (hasChanges) {
        // Update cache seamlessly
        _updateCache(fetchedSessions);
        _lastUpdate = DateTime.now();

        log('[FeedBuilderCacheService] Silent refresh completed - data updated');
        // Notify listeners about changes (without changing _isLoading)
        notifyListeners();
      } else {
        log('[FeedBuilderCacheService] Silent refresh completed - no changes');
        _lastUpdate = DateTime.now();
      }
    } catch (e) {
      log('[FeedBuilderCacheService] Silent refresh error: $e');
      // On error, silently do nothing, use current cache
    }
  }

  /// Check if data has changed
  bool _hasDataChanged(List<FeedBuilderSession> newSessions) {
    // Quick check by session count
    if (newSessions.length != _sessionsCache.length) {
      return true;
    }

    // Check each session for changes
    for (final newSession in newSessions) {
      final cachedSession = _sessionsCache[newSession.sessionId];

      if (cachedSession == null) {
        return true; // New session
      }

      // Check message count
      if (newSession.messages.length != cachedSession.messages.length) {
        return true;
      }

      // Check last activity time
      if (newSession.lastActivityAt != cachedSession.lastActivityAt) {
        return true;
      }
    }

    return false; // No changes
  }

  /// Остановить автоматическое обновление
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    log('[FeedBuilderCacheService] Auto-refresh stopped');
  }

  /// Очистить кеш
  void clearCache() {
    _sessionsCache.clear();
    _sessionOrder.clear();
    _lastUpdate = null;
    stopAutoRefresh();
    log('[FeedBuilderCacheService] Cache cleared');
    notifyListeners();
  }

  /// Получить статистику кеша
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_chats': _sessionsCache.length,
      'last_update': _lastUpdate?.toIso8601String(),
      'is_loading': _isLoading,
      'auto_refresh_active': _refreshTimer?.isActive ?? false,
    };
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
