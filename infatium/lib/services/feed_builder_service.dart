import 'dart:developer';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/feed_builder_models.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'feed_builder_cache_service.dart';
import 'analytics_service.dart';
import 'authenticated_http_client.dart';

class FeedBuilderService {
  static final AuthenticatedHttpClient _httpClient = AuthenticatedHttpClient();
  static String get _baseUrl => ApiConfig.baseUrl;
  static String get _apiKey => ApiConfig.apiKey;
  static Duration get _timeout => ApiConfig.requestTimeout;

  // Cache for sessions
  static List<FeedBuilderSession>? _cachedSessions;

  /// Получить все чаты пользователя
  static Future<List<FeedBuilderSession>> fetchSessions() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        log('FeedBuilderService: User not authenticated');
        return [];
      }

      final uri = Uri.parse('$_baseUrl/chats');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
        'user-id': user.id,
      };

      log('FeedBuilderService: Fetching chats from $uri');
      log('FeedBuilderService: Headers: ${headers.keys.toList()}');

      final response = await _httpClient.get(uri, headers: headers, timeout: _timeout);

      log('FeedBuilderService: Response status: ${response.statusCode}');
      log('FeedBuilderService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);

        log('FeedBuilderService: Raw response data type: ${responseData.runtimeType}');
        log('FeedBuilderService: Raw response data: $responseData');

        if (responseData == null) {
          log('FeedBuilderService: No chats found (null response)');
          _cachedSessions = [];
          return [];
        }

        // Новый формат: {"chats": [...]}
        if (responseData is Map<String, dynamic> && responseData.containsKey('chats')) {
          final dynamic chatsData = responseData['chats'];

          log('FeedBuilderService: Found chats field, type: ${chatsData.runtimeType}');

          if (chatsData == null || (chatsData is List && chatsData.isEmpty)) {
            log('FeedBuilderService: No chats found in chats array');
            _cachedSessions = [];
            return [];
          }

          if (chatsData is List) {
            log('FeedBuilderService: Processing ${chatsData.length} chat items from chats array');

            final sessions = <FeedBuilderSession>[];
            for (int i = 0; i < chatsData.length; i++) {
              try {
                final chatJson = chatsData[i] as Map<String, dynamic>;
                log('FeedBuilderService: Processing chat $i: ${chatJson.keys.toList()}');
                final session = FeedBuilderSession.fromJson(chatJson);
                sessions.add(session);
                log('FeedBuilderService: Successfully parsed chat ${session.sessionId}');
              } catch (e) {
                log('FeedBuilderService: Error parsing chat $i: $e');
              }
            }

            // Сортируем по последней активности (новые сначала)
            sessions.sort((a, b) {
              final aTime = a.lastActivityAt;
              final bTime = b.lastActivityAt;
              log('FeedBuilderService: Comparing chats - A: ${a.sessionId} (${aTime}), B: ${b.sessionId} (${bTime})');
              return bTime.compareTo(aTime);
            });

            _cachedSessions = sessions;
            log('FeedBuilderService: Successfully fetched ${sessions.length} chats from chats array');
            return sessions;
          } else {
            log('FeedBuilderService: chats field is not an array: ${chatsData.runtimeType}');
            return [];
          }
        }
        // Legacy формат: {"data": [...]}
        else if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
          final dynamic chatsData = responseData['data'];

          log('FeedBuilderService: Found legacy data field, type: ${chatsData.runtimeType}');

          if (chatsData == null || (chatsData is List && chatsData.isEmpty)) {
            log('FeedBuilderService: No chats found in data array');
            _cachedSessions = [];
            return [];
          }

          if (chatsData is List) {
            log('FeedBuilderService: Processing ${chatsData.length} chat items from legacy data array');

            final sessions = <FeedBuilderSession>[];
            for (int i = 0; i < chatsData.length; i++) {
              try {
                final chatJson = chatsData[i] as Map<String, dynamic>;
                log('FeedBuilderService: Processing legacy chat $i: ${chatJson.keys.toList()}');
                final session = FeedBuilderSession.fromJson(chatJson);
                sessions.add(session);
                log('FeedBuilderService: Successfully parsed legacy chat ${session.sessionId}');
              } catch (e) {
                log('FeedBuilderService: Error parsing legacy chat $i: $e');
              }
            }

            // Сортируем по последней активности (новые сначала)
            sessions.sort((a, b) {
              final aTime = a.lastActivityAt;
              final bTime = b.lastActivityAt;
              log('FeedBuilderService: Comparing legacy chats - A: ${a.sessionId} (${aTime}), B: ${b.sessionId} (${bTime})');
              return bTime.compareTo(aTime);
            });

            _cachedSessions = sessions;
            log('FeedBuilderService: Successfully fetched ${sessions.length} chats from legacy data array');
            return sessions;
          } else {
            log('FeedBuilderService: data field is not an array: ${chatsData.runtimeType}');
            return [];
          }
        }
        // Fallback: старый формат (прямой массив)
        else if (responseData is List) {
          log('FeedBuilderService: Processing legacy array format with ${responseData.length} items');

          final sessions = <FeedBuilderSession>[];
          for (int i = 0; i < responseData.length; i++) {
            try {
              final chatJson = responseData[i] as Map<String, dynamic>;
              final session = FeedBuilderSession.fromJson(chatJson);
              sessions.add(session);
            } catch (e) {
              log('FeedBuilderService: Error parsing legacy chat $i: $e');
            }
          }

          // Сортируем по последней активности (новые сначала)
          sessions.sort((a, b) {
            final aTime = a.lastActivityAt;
            final bTime = b.lastActivityAt;
            log('FeedBuilderService: Legacy sort - A: ${a.sessionId} (${aTime}), B: ${b.sessionId} (${bTime})');
            return bTime.compareTo(aTime);
          });

          _cachedSessions = sessions;
          log('FeedBuilderService: Successfully fetched ${sessions.length} chats (legacy array format)');
          return sessions;
        }
        // Fallback: одиночный объект чата
        else if (responseData is Map<String, dynamic> && responseData.containsKey('chat_id')) {
          final session = FeedBuilderSession.fromJson(responseData);
          final sessions = [session];

          _cachedSessions = sessions;
          log('FeedBuilderService: Successfully fetched 1 chat (single object)');
          return sessions;
        } else {
          log('FeedBuilderService: Unexpected response format: ${responseData.runtimeType}');
          log('FeedBuilderService: Response keys: ${responseData is Map ? responseData.keys.toList() : 'not a map'}');
          return [];
        }
      } else {
        log('FeedBuilderService: Failed to fetch chats, status: ${response.statusCode}');

        throw Exception('Failed to fetch chats: ${response.statusCode}');
      }
    } catch (e) {
      log('FeedBuilderService: Error fetching chats: $e');
      // Возвращаем кешированные данные при ошибке сети
      if (_cachedSessions != null) {
        log('FeedBuilderService: Returning cached chats due to network error');
        return _cachedSessions!;
      }
      rethrow;
    }
  }

  /// Создать новый чат
  static Future<String> createSession() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        log('FeedBuilderService: User not authenticated');
        throw Exception('User not authenticated');
      }

      final uri = Uri.parse('$_baseUrl/chats');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
        'user-id': user.id,
      };

      log('FeedBuilderService: Creating new chat at $uri');

      final response = await _httpClient.post(uri, headers: headers, timeout: _timeout);

      log('FeedBuilderService: Create chat response status: ${response.statusCode}');
      log('FeedBuilderService: Create chat response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final createResponse = CreateSessionResponse.fromJson(responseData);
        
        // Очищаем кеш чтобы при следующем запросе получить обновленный список
        _cachedSessions = null;
        
        log('FeedBuilderService: Successfully created chat: ${createResponse.sessionId}');
        return createResponse.sessionId;
      } else {
        log('FeedBuilderService: Failed to create chat, status: ${response.statusCode}');

        throw Exception('Failed to create chat: ${response.statusCode}');
      }
    } catch (e) {
      log('FeedBuilderService: Error creating chat: $e');
      rethrow;
    }
  }

  /// Удалить чат
  static Future<bool> deleteSession(String sessionId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        log('FeedBuilderService: User not authenticated');
        throw Exception('User not authenticated');
      }

      final uri = Uri.parse('$_baseUrl/chats/$sessionId');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
        'user-id': user.id,
      };

      log('FeedBuilderService: Deleting chat $sessionId at $uri');

      final response = await _httpClient.delete(uri, headers: headers, timeout: _timeout);

      log('FeedBuilderService: Delete chat response status: ${response.statusCode}');
      log('FeedBuilderService: Delete chat response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Очищаем кеш чтобы при следующем запросе получить обновленный список
        _cachedSessions = null;

        log('FeedBuilderService: Successfully deleted chat: $sessionId');
        return true;
      } else {
        log('FeedBuilderService: Failed to delete chat, status: ${response.statusCode}');

        throw Exception('Failed to delete chat: ${response.statusCode}');
      }
    } catch (e) {
      log('FeedBuilderService: Error deleting chat: $e');
      rethrow;
    }
  }



  // === НОВЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С УМНЫМ КЕШЕМ ===
  
  /// Get all sessions via smart cache
  static Future<List<FeedBuilderSession>> getSessionsWithCache({bool forceRefresh = false}) async {
    return await FeedBuilderCacheService().loadSessions(forceRefresh: forceRefresh);
  }
  
  /// Создать новый чат через кеш
  static Future<String> createSessionWithCache() async {
    return await FeedBuilderCacheService().createSession();
  }
  
  /// Удалить чат через кеш
  static Future<bool> deleteSessionWithCache(String sessionId) async {
    return await FeedBuilderCacheService().deleteSession(sessionId);
  }
  
  /// Get specific session from cache
  static FeedBuilderSession? getSessionFromCache(String sessionId) {
    return FeedBuilderCacheService().getSession(sessionId);
  }

  /// Find empty session (without messages) for reuse
  static FeedBuilderSession? findEmptySession() {
    return FeedBuilderCacheService().findEmptySession();
  }

  /// Add message to session cache
  static void addMessageToSessionCache(String sessionId, FeedBuilderMessage message) {
    FeedBuilderCacheService().addMessageToSession(sessionId, message);
  }

  /// Refresh specific session
  static Future<FeedBuilderSession?> refreshSessionInCache(String sessionId) async {
    return await FeedBuilderCacheService().refreshSession(sessionId);
  }
  
  /// Принудительное бесшовное обновление всех чатов
  static Future<void> silentRefreshSessions() async {
    return await FeedBuilderCacheService().silentRefreshNow();
  }

  // === СТАРЫЕ МЕТОДЫ (для совместимости) ===
  
  /// Очистить кеш (например, при logout)
  static void clearCache() {
    _cachedSessions = null;
    FeedBuilderCacheService().clearCache();
  }

  /// Получить кешированные чаты (для быстрого доступа)
  static List<FeedBuilderSession>? get cachedSessions => _cachedSessions;

  /// Получить preview ленты перед созданием (GET /modal/chat/{chat_id})
  static Future<FeedPreview> getFeedPreview(String sessionId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        log('FeedBuilderService: User not authenticated');
        throw Exception('User not authenticated');
      }

      final uri = Uri.parse('$_baseUrl/modal/chat/$sessionId');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
        'user-id': user.id,
      };

      log('FeedBuilderService: Fetching feed preview from $uri');
      log('FeedBuilderService: Headers: ${headers.keys.toList()}');

      final response = await _httpClient.get(uri, headers: headers, timeout: _timeout);

      log('FeedBuilderService: Feed preview response status: ${response.statusCode}');
      log('FeedBuilderService: Feed preview response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final preview = FeedPreview.fromJson(responseData);

        log('FeedBuilderService: Successfully fetched feed preview: ${preview.name}');
        return preview;
      } else if (response.statusCode == 400) {
        log('FeedBuilderService: Chat does not have source channels yet');

        throw Exception('Chat does not have source channels yet');
      } else if (response.statusCode == 404) {
        log('FeedBuilderService: Chat not found');

        throw Exception('Chat not found');
      } else {
        log('FeedBuilderService: Failed to fetch feed preview, status: ${response.statusCode}');

        throw Exception('Failed to fetch feed preview: ${response.statusCode}');
      }
    } catch (e) {
      log('FeedBuilderService: Error fetching feed preview: $e');
      rethrow;
    }
  }

  /// Получить preview ленты по feed_id (GET /modal/feed/{feed_id})
  static Future<FeedPreview> getFeedPreviewByFeedId(String feedId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        log('FeedBuilderService: User not authenticated');
        throw Exception('User not authenticated');
      }

      final uri = Uri.parse('$_baseUrl/modal/feed/$feedId');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
        'user-id': user.id,
      };

      log('FeedBuilderService: Fetching feed preview by feedId from $uri');

      final response = await _httpClient.get(uri, headers: headers, timeout: _timeout);

      log('FeedBuilderService: Feed preview response status: ${response.statusCode}');
      log('FeedBuilderService: Feed preview response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        // DEBUG: Log raw sources from API response
        print('=== getFeedPreviewByFeedId RAW sources DEBUG ===');
        print('Raw sources JSON: ${responseData['sources']}');
        print('================================================');

        final preview = FeedPreview.fromJson(responseData);

        log('FeedBuilderService: Successfully fetched feed preview by feedId: ${preview.name}');
        return preview;
      } else {
        log('FeedBuilderService: Failed to fetch feed preview by feedId, status: ${response.statusCode}');

        throw Exception('Failed to fetch feed preview: ${response.statusCode}');
      }
    } catch (e) {
      log('FeedBuilderService: Error fetching feed preview by feedId: $e');
      rethrow;
    }
  }

  /// Обновить preview ленты (PATCH /chats/{chat_id}/feed_preview)
  /// Используется для установки prompt, sources и type перед созданием фида
  static Future<FeedPreviewUpdateResponse> updateFeedPreview({
    required String sessionId,
    String? title,
    String? description,
    List<String>? tags,
    String? prompt,
    List<String>? sources,
    Map<String, String>? sourceTypes,
    String? type,
    int? digestIntervalHours,
    List<String>? views,
    List<String>? filters,
  }) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        log('FeedBuilderService: User not authenticated');
        throw Exception('User not authenticated');
      }

      final uri = Uri.parse('$_baseUrl/chats/$sessionId/feed_preview');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
        'user-id': user.id,
      };

      // Build request body - only include non-null fields
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (tags != null) body['tags'] = tags;
      if (prompt != null) body['prompt'] = prompt;
      if (sources != null) body['sources'] = sources;
      if (sourceTypes != null) body['source_types'] = sourceTypes;
      if (type != null) body['type'] = type;
      if (digestIntervalHours != null) body['digest_interval_hours'] = digestIntervalHours;
      if (views != null) body['views'] = views;
      if (filters != null) body['filters'] = filters;

      log('FeedBuilderService: Updating feed preview at $uri');
      log('FeedBuilderService: Request body: ${jsonEncode(body)}');

      final response = await _httpClient.patch(
        uri,
        headers: headers,
        body: jsonEncode(body),
        timeout: _timeout,
      );

      log('FeedBuilderService: Update feed preview response status: ${response.statusCode}');
      log('FeedBuilderService: Update feed preview response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        log('FeedBuilderService: Successfully updated feed preview');
        return FeedPreviewUpdateResponse.fromJson(responseData);
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'Validation error';
        log('FeedBuilderService: Validation error: $errorMessage');

        throw Exception(errorMessage);
      } else if (response.statusCode == 404) {
        log('FeedBuilderService: Chat not found');

        throw Exception('Chat not found');
      } else if (response.statusCode == 422) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'Business rule violation';
        log('FeedBuilderService: Business rule error: $errorMessage');

        throw Exception(errorMessage);
      } else {
        log('FeedBuilderService: Failed to update feed preview, status: ${response.statusCode}');

        throw Exception('Failed to update feed preview: ${response.statusCode}');
      }
    } catch (e) {
      log('FeedBuilderService: Error updating feed preview: $e');
      rethrow;
    }
  }

  /// Обновить существующий фид (PATCH /feeds/{feed_id})
  /// Используется для редактирования уже созданного фида
  static Future<bool> updateExistingFeed({
    required String feedId,
    String? title,
    String? prompt,
    String? description,
    List<Map<String, String>>? sources,  // [{url: "...", type: "TELEGRAM"}, ...]
    String? type,
    int? digestIntervalHours,
    List<String>? filters,
    List<String>? views,
    // LEGACY: kept for backward compatibility
    bool? filterAds,
    bool? filterDuplicates,
  }) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        log('FeedBuilderService: User not authenticated');
        throw Exception('User not authenticated');
      }

      final uri = Uri.parse('$_baseUrl/feeds/$feedId');

      // DEBUG LOGS for "Feed not found" investigation
      print('=== updateExistingFeed DEBUG ===');
      print('Feed ID: $feedId');
      print('User ID: ${user.id}');
      print('Full URL: $uri');
      print('Base URL: $_baseUrl');
      print('Has Auth Token: ${AuthService().currentSession?.accessToken != null}');
      print('================================');

      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
        'user-id': user.id,
      };

      // Build request body - only include non-null fields
      // API field names: name, description, sources, raw_prompt, views_raw, filters_raw, digest_interval_hours
      final body = <String, dynamic>{};
      if (title != null) body['name'] = title;  // API expects 'name', not 'title'
      if (prompt != null) body['raw_prompt'] = prompt;  // API expects 'raw_prompt'
      if (description != null) body['description'] = description;
      // API expects sources as array of SourceInput objects: [{"url": "...", "type": "..."}, ...]
      if (sources != null) body['sources'] = sources;
      // Note: 'type' is not editable via PATCH
      if (digestIntervalHours != null) body['digest_interval_hours'] = digestIntervalHours;
      if (views != null) body['views_raw'] = views;  // API expects 'views_raw'
      if (filters != null) body['filters_raw'] = filters;  // API expects 'filters_raw'

      log('FeedBuilderService: Updating existing feed at $uri');
      log('FeedBuilderService: Request body: ${jsonEncode(body)}');
      print('Request body: ${jsonEncode(body)}');  // DEBUG

      final response = await _httpClient.patch(
        uri,
        headers: headers,
        body: jsonEncode(body),
        timeout: _timeout,
      );

      // DEBUG LOGS for "Feed not found" investigation
      print('=== API Response DEBUG ===');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      print('===========================');

      if (response.statusCode == 200 || response.statusCode == 204) {
        log('FeedBuilderService: Successfully updated existing feed: $feedId');
        return true;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'Validation error';
        log('FeedBuilderService: Validation error: $errorMessage');

        throw Exception(errorMessage);
      } else if (response.statusCode == 404) {
        log('FeedBuilderService: Feed not found');

        throw Exception('Feed not found');
      } else {
        log('FeedBuilderService: Failed to update existing feed, status: ${response.statusCode}');

        throw Exception('Failed to update feed: ${response.statusCode}');
      }
    } catch (e) {
      log('FeedBuilderService: Error updating existing feed: $e');
      rethrow;
    }
  }

  /// Generate a title for a feed based on its configuration
  /// GET /modal/generate_title/{feed_id}
  static Future<String?> generateFeedTitle(String feedId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        log('FeedBuilderService: User not authenticated');
        return null;
      }

      final uri = Uri.parse('$_baseUrl/modal/generate_title/$feedId');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
        'user-id': user.id,
      };

      log('FeedBuilderService: Generating title for feed $feedId');
      final response = await _httpClient.get(uri, headers: headers, timeout: _timeout);

      log('FeedBuilderService: Generate title response status: ${response.statusCode}');
      log('FeedBuilderService: Generate title response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final title = data['title'] as String?;
        log('FeedBuilderService: Generated title: $title');
        return title;
      } else {
        log('FeedBuilderService: Failed to generate title: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('FeedBuilderService: Error generating title: $e');
      return null;
    }
  }

  // ============================================================================
  // NEW API: POST /feeds/generate_title - Direct title generation without chat
  // ============================================================================

  /// Generate title directly from source configuration (no chat/feed required)
  /// POST /feeds/generate_title
  static Future<String?> generateTitleDirect({
    required List<SourceItem> sources,
    required FeedType feedType,
    List<String>? viewsRaw,
    List<String>? filtersRaw,
    int? digestIntervalHours,
  }) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        log('FeedBuilderService: User not authenticated');
        return null;
      }

      final uri = Uri.parse('$_baseUrl/feeds/generate_title');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
        'user-id': user.id,
      };

      final body = jsonEncode({
        'sources': sources.map((s) => s.toJson()).toList(),
        'feed_type': feedType.apiValue,
        if (viewsRaw != null && viewsRaw.isNotEmpty) 'views_raw': viewsRaw,
        if (filtersRaw != null && filtersRaw.isNotEmpty) 'filters_raw': filtersRaw,
        if (digestIntervalHours != null) 'digest_interval_hours': digestIntervalHours,
      });

      final response = await _httpClient.post(uri, headers: headers, body: body, timeout: _timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final title = data['title'] as String?;
        log('FeedBuilderService: Generated title directly: $title');
        return title;
      } else {
        log('FeedBuilderService: Failed to generate title directly: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('FeedBuilderService: Error generating title directly: $e');
      return null;
    }
  }

  // ============================================================================
  // NEW API: POST /feeds/create - Direct feed creation without chat
  // ============================================================================

  /// Create feed directly via new API (bypassing chat flow)
  /// POST /feeds/create
  static Future<CreateFeedResponse> createFeedDirect({
    String? name,
    required List<SourceItem> sources,
    required FeedType feedType,
    List<String>? viewsRaw,
    List<String>? filtersRaw,
    int? digestIntervalHours,
  }) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        log('FeedBuilderService: User not authenticated');
        throw Exception('User not authenticated');
      }

      final uri = Uri.parse('$_baseUrl/feeds/create');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
        'user-id': user.id,
      };

      final request = CreateFeedRequest(
        name: name,
        sources: sources,
        feedType: feedType.apiValue,
        viewsRaw: viewsRaw,
        filtersRaw: filtersRaw,
        digestIntervalHours: feedType == FeedType.DIGEST ? digestIntervalHours : null,
      );

      final body = jsonEncode(request.toJson());

      final response = await _httpClient.post(
        uri,
        headers: headers,
        body: body,
        timeout: _timeout,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        log('FeedBuilderService: Successfully created feed - feedId: ${responseData['feed_id']}');
        return CreateFeedResponse.fromJson(responseData);
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? errorData['message'] ?? 'Validation error';
        log('FeedBuilderService: Validation error: $errorMessage');

        throw Exception(errorMessage);
      } else if (response.statusCode == 401) {
        log('FeedBuilderService: Unauthorized');

        throw Exception('Unauthorized');
      } else if (response.statusCode == 422) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? errorData['message'] ?? 'Validation error';
        log('FeedBuilderService: Unprocessable entity: $errorMessage');

        throw Exception(errorMessage);
      } else {
        log('FeedBuilderService: Failed to create feed, status: ${response.statusCode}');

        throw Exception('Failed to create feed: ${response.statusCode}');
      }
    } catch (e) {
      log('FeedBuilderService: Error creating feed: $e');
      rethrow;
    }
  }

  /// Тестовый метод для проверки API
  static Future<void> testApiConnection() async {
    try {
      log('FeedBuilderService: Testing API connection...');
      final user = AuthService().currentUser;
      if (user == null) {
        log('FeedBuilderService: User not authenticated');
        return;
      }

      final uri = Uri.parse('$_baseUrl/chats');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
        'user-id': user.id,
      };

      log('FeedBuilderService: Test GET $uri');
      final response = await _httpClient.get(uri, headers: headers, timeout: _timeout);

      log('FeedBuilderService: Test response status: ${response.statusCode}');
      log('FeedBuilderService: Test response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);
        log('FeedBuilderService: Test response parsed: ${responseData.runtimeType}');
        if (responseData is Map) {
          if (responseData.containsKey('chats')) {
            log('FeedBuilderService: Test found chats array with ${(responseData['chats'] as List).length} items');
          } else if (responseData.containsKey('data')) {
            log('FeedBuilderService: Test found legacy data array with ${(responseData['data'] as List).length} items');
          } else {
            log('FeedBuilderService: Test found map but no chats or data field');
          }
        }
      }
    } catch (e) {
      log('FeedBuilderService: Test error: $e');
    }
  }
}
