import 'dart:developer';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/tag_models.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'analytics_service.dart';
import 'authenticated_http_client.dart';

class TagService {
  static final TagService _instance = TagService._internal();
  factory TagService() => _instance;
  TagService._internal();

  final AuthenticatedHttpClient _httpClient = AuthenticatedHttpClient();

  static String get _baseUrl => ApiConfig.baseUrl;
  static String get _apiKey => ApiConfig.apiKey;
  static Duration get _timeout => ApiConfig.requestTimeout;

  // In-memory cache for prompt examples
  List<PromptExample>? _cachedPromptExamples;

  /// Ensures the JWT token is valid before making API requests.
  /// If token expires in less than 1 minute, refreshes it proactively.
  /// Returns true if token is valid or was successfully refreshed, false otherwise.
  Future<bool> _ensureValidToken() async {
    try {
      final session = AuthService().currentSession;
      if (session == null || session.expiresAt == null) {
        log('❌ TagService: No active session found');
        return false;
      }

      final timeUntilExpiry = session.expiresAt!.difference(DateTime.now());

      // If token expires in less than 1 minute, refresh it proactively
      if (timeUntilExpiry < const Duration(minutes: 1)) {
        final refreshResult = await AuthService().refreshSession();
        if (refreshResult.success) {
          return true;
        } else {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('❌ TagService: Error checking token validity: $e');
      return false;
    }
  }

  /// Get cached prompt examples (returns empty list if not cached)
  List<PromptExample> getCachedPromptExamples() {
    return _cachedPromptExamples ?? [];
  }

  /// Fetch prompt examples filtered by user's tags
  Future<List<PromptExample>> fetchPromptExamples() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        log('TagService: User not authenticated for prompt examples');
        return []; // Return empty list to use defaults
      }

      // Ensure token is valid before making request
      await _ensureValidToken();

      final uri = Uri.parse('$_baseUrl/prompt_examples');
      final headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
        'user-id': user.id,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
      };

      log('TagService: Fetching prompt examples from $uri');
      log('TagService: User ID: ${user.id}');

      // Use authenticated client (handles 401 retry automatically)
      final response = await _httpClient.get(uri, headers: headers, timeout: _timeout);
      log('TagService: Response status: ${response.statusCode}');
      log('TagService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> data = responseData['data'] ?? [];
        final promptExamples = data.map((json) => PromptExample.fromJson(json)).toList();

        // Cache prompt examples
        _cachedPromptExamples = promptExamples;

        log('TagService: Successfully fetched ${promptExamples.length} prompt examples');
        return promptExamples;
      } else if (response.statusCode == 400) {
        log('TagService: Invalid or missing user-id for prompt examples');
        return []; // Return empty list to use defaults
      } else if (response.statusCode == 401) {
        log('TagService: JWT token authentication failed for prompt examples (even after retry)');
        return []; // Return empty list to use defaults
      } else if (response.statusCode == 405) {
        log('TagService: Wrong HTTP method for prompt examples');
        return []; // Return empty list to use defaults
      } else {
        log('TagService: Failed to fetch prompt examples, status: ${response.statusCode}');

        return []; // Return empty list to use defaults
      }
    } catch (e) {
      log('TagService: Error fetching prompt examples: $e');
      return []; // Return empty list to use defaults on any error
    }
  }

  /// Clear cache (e.g., on logout)
  Future<void> clearCache() async {
    _cachedPromptExamples = null;
    log('TagService: Cache cleared');
  }
}
