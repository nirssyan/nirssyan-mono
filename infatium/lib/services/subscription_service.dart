import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/subscription_models.dart';
import 'auth_service.dart';

/// Service for managing subscription limits.
/// Singleton pattern following AuthService pattern.
class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal() {
    print('SubscriptionService: Initialized with default status - maxSources=${_status.plan.maxSources}, maxFeeds=${_status.plan.maxFeeds}');
  }

  SubscriptionStatus _status = SubscriptionStatus.defaultStatus;
  DateTime? _lastFetchTime;
  bool _isFetching = false;

  // Cache timeout: 5 minutes
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Current subscription status
  SubscriptionStatus get status => _status;

  /// Current subscription plan
  SubscriptionPlan get plan => _status.plan;

  /// Check if user can add more of a specific limit type
  bool canAddMore(LimitType limitType, int currentCount) {
    final limit = _status.plan.getLimit(limitType);
    final result = _status.canAddMore(limitType, currentCount);
    print('SubscriptionService.canAddMore: limitType=$limitType, currentCount=$currentCount, limit=$limit, canAdd=$result');
    return result;
  }

  /// Check if user can create a new feed
  bool get canCreateFeed => _status.canCreateFeed;

  /// Get the limit for a specific type
  int getLimit(LimitType limitType) {
    return _status.plan.getLimit(limitType);
  }

  /// Get active feeds count
  int get activeFeedsCount => _status.activeFeedsCount;

  /// Fetch subscription status from API
  Future<void> fetchSubscription({bool forceRefresh = false}) async {
    // Check cache validity
    if (!forceRefresh && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < _cacheTimeout) {
        return;
      }
    }

    // Prevent concurrent fetches
    if (_isFetching) return;

    final user = AuthService().currentUser;
    if (user == null) {
      _status = SubscriptionStatus.defaultStatus;
      notifyListeners();
      return;
    }

    _isFetching = true;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/subscriptions/current'),
        headers: {
          ...ApiConfig.commonHeaders,
          'user-id': user.id,
          'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
        },
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _status = SubscriptionStatus.fromJson(json);
        _lastFetchTime = DateTime.now();
        notifyListeners();
        print('SubscriptionService: Fetched subscription - plan: ${_status.plan.type}, feeds: ${_status.activeFeedsCount}/${_status.plan.maxFeeds}, sources limit: ${_status.plan.maxSources}');
      } else {
        print('SubscriptionService: Error fetching subscription - ${response.statusCode}: ${response.body}');
        // On error, keep existing status or use default
        if (_lastFetchTime == null) {
          _status = SubscriptionStatus.defaultStatus;
          notifyListeners();
        }
      }
    } catch (e) {
      print('SubscriptionService: Exception fetching subscription - $e');
      // On error, keep existing status or use default
      if (_lastFetchTime == null) {
        _status = SubscriptionStatus.defaultStatus;
        notifyListeners();
      }
    } finally {
      _isFetching = false;
    }
  }

  /// Update active feeds count locally (e.g., after creating/deleting a feed)
  void updateActiveFeedsCount(int count) {
    _status = SubscriptionStatus(
      plan: _status.plan,
      activeFeedsCount: count,
    );
    notifyListeners();
  }

  /// Increment active feeds count
  void incrementFeedsCount() {
    updateActiveFeedsCount(_status.activeFeedsCount + 1);
  }

  /// Decrement active feeds count
  void decrementFeedsCount() {
    if (_status.activeFeedsCount > 0) {
      updateActiveFeedsCount(_status.activeFeedsCount - 1);
    }
  }

  /// Clear subscription status (call on logout)
  void clear() {
    _status = SubscriptionStatus.defaultStatus;
    _lastFetchTime = null;
    _isFetching = false;
    notifyListeners();
    print('SubscriptionService: Cleared subscription status');
  }
}
