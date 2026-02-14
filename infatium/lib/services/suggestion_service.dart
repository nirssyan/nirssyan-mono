import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/suggestion_models.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'analytics_service.dart';

/// Service for loading and caching suggestions (filters, views, sources)
/// for the Feed Builder (Chat) tab.
///
/// Uses singleton pattern with ChangeNotifier for reactive updates.
class SuggestionService extends ChangeNotifier {
  static final SuggestionService _instance = SuggestionService._internal();
  factory SuggestionService() => _instance;
  SuggestionService._internal();

  // In-memory cache
  List<Suggestion>? _filters;
  List<Suggestion>? _views;
  List<Suggestion>? _sources;

  // Loading state
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Suggestion> get filters => _filters ?? [];
  List<Suggestion> get views => _views ?? [];
  List<Suggestion> get sources => _sources ?? [];
  bool get isLoaded => _filters != null && _views != null && _sources != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all suggestions in parallel
  Future<void> fetchAll() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;

    try {
      await Future.wait([
        _fetchFilters(),
        _fetchViews(),
        _fetchSources(),
      ]);
      print('[SuggestionService] All suggestions loaded successfully');
    } catch (e) {
      print('[SuggestionService] Error loading suggestions: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch filters from API
  Future<void> _fetchFilters() async {
    try {
      print('[SuggestionService] Fetching filters...');
      final suggestions = await _fetchSuggestions('/suggestions/filters');
      _filters = suggestions;
      print('[SuggestionService] Loaded ${suggestions.length} filters:');
      for (final s in suggestions) {
        print('  - ${s.id}: ${s.name}');
      }
    } catch (e) {
      print('[SuggestionService] Error fetching filters: $e');
      // Don't rethrow - allow other fetches to continue
    }
  }

  /// Fetch views from API
  Future<void> _fetchViews() async {
    try {
      print('[SuggestionService] Fetching views...');
      final suggestions = await _fetchSuggestions('/suggestions/views');
      _views = suggestions;
      print('[SuggestionService] Loaded ${suggestions.length} views:');
      for (final s in suggestions) {
        print('  - ${s.id}: ${s.name}');
      }
    } catch (e) {
      print('[SuggestionService] Error fetching views: $e');
    }
  }

  /// Fetch sources from API
  Future<void> _fetchSources() async {
    try {
      print('[SuggestionService] Fetching sources...');
      final suggestions = await _fetchSuggestions('/suggestions/sources');
      _sources = suggestions;
      print('[SuggestionService] Loaded ${suggestions.length} sources:');
      for (final s in suggestions) {
        print('  - ${s.id}: ${s.name}');
      }
    } catch (e) {
      print('[SuggestionService] Error fetching sources: $e');
    }
  }

  /// Generic method to fetch suggestions from an endpoint
  Future<List<Suggestion>> _fetchSuggestions(String endpoint) async {
    final user = AuthService().currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {
      ...ApiConfig.commonHeaders,
      'user-id': user.id,
      'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
    };

    final response = await http.get(uri, headers: headers).timeout(
      ApiConfig.requestTimeout,
      onTimeout: () => throw Exception('Request timed out'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body) as List<dynamic>;
      return data
          .map((item) => Suggestion.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      // Try to refresh token and retry
      final refreshResult = await AuthService().refreshSession();
      if (refreshResult.success) {
        return _fetchSuggestions(endpoint);
      }
      throw Exception('Authentication failed');
    } else {
      throw Exception('Failed to fetch suggestions: ${response.statusCode}');
    }
  }

  /// Clear all cached data (e.g., on logout)
  void clear() {
    _filters = null;
    _views = null;
    _sources = null;
    _error = null;
    notifyListeners();
  }
}
