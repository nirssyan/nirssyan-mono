import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'auth_service.dart';
import 'analytics_service.dart';
import 'news_service.dart';
import '../models/analytics_event_schema.dart';
import '../models/custom_auth_state.dart';
import '../config/api_config.dart';

/// Singleton service for persistent WebSocket connections
/// Listens for real-time post updates across all subscribed feeds
class WebSocketService extends ChangeNotifier {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  // Connection state
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  bool _isConnected = false;
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;

  // Persistent mode state
  Set<String> _subscribedFeedIds = {};
  Function(String feedId, String postId)? _onPostCreatedCallback;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 30; // seconds
  static const int _heartbeatInterval = 30; // seconds

  // Token refresh tracking
  StreamSubscription<CustomAuthState>? _authStateSubscription;
  DateTime? _lastConnectionTime;

  // Feed creation tracking (uses persistent connection)
  String? _pendingFeedId;
  Function(String feedId)? _onFeedCreationComplete;
  Timer? _feedCreationTimeout;

  // Public getters
  bool get isConnected => _isConnected;
  WebSocketConnectionState get state => _state;

  /// Connect persistently and listen for ALL post_created events
  /// This connection stays open until explicitly disconnected
  Future<void> connectPersistent({
    required Set<String> feedIds,
    required Function(String feedId, String postId) onPostCreated,
  }) async {
    print('[WebSocketService] connectPersistent called with ${feedIds.length} feeds');

    // If already connected, merge with existing feed IDs (don't overwrite pending feeds)
    if (_isConnected) {
      _subscribedFeedIds = {..._subscribedFeedIds, ...feedIds};
      _onPostCreatedCallback = onPostCreated;
      print('[WebSocketService] Updated subscribed feeds (already connected): ${_subscribedFeedIds.length} feeds');
      return;
    }

    _subscribedFeedIds = {..._subscribedFeedIds, ...feedIds};
    _onPostCreatedCallback = onPostCreated;

    // Subscribe to token refresh events
    _authStateSubscription?.cancel();
    _authStateSubscription = AuthService().authStateChanges.listen((state) {
      if (state.event == CustomAuthEvent.tokenRefreshed && _isConnected) {
        print('[WebSocketService] Token refreshed, reconnecting WebSocket');
        _reconnectForTokenRefresh();
      }
    });

    await _connect();
  }

  Future<void> _connect() async {
    if (_isConnected) return;

    _setState(WebSocketConnectionState.connecting);

    try {
      final token = AuthService().currentSession?.accessToken;
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final apiUri = Uri.parse(ApiConfig.baseUrl);
      final wsScheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
      final wsUrl = Uri(
        scheme: wsScheme,
        host: apiUri.host,
        port: apiUri.hasPort ? apiUri.port : null,
        path: '/ws/feeds',
        queryParameters: {'token': token},
      );

      print('[WebSocketService] Connecting WebSocket to $wsUrl');

      _channel = WebSocketChannel.connect(wsUrl);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _lastConnectionTime = DateTime.now();
      _setState(WebSocketConnectionState.connected);

      // Start heartbeat to keep connection alive
      _startHeartbeat();

      AnalyticsService().capture(EventSchema.websocketConnected, properties: {
        'feed_count': _subscribedFeedIds.length,
      });

      print('[WebSocketService] WebSocket connected successfully');
    } catch (e) {
      print('[WebSocketService] Connection failed: $e');
      // Note: Connection failures are logged but not tracked in analytics (internal technical detail)

      _setState(WebSocketConnectionState.error);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    print('[WebSocketService] Message received: $message');
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final feedId = data['feed_id'] as String?;
      final postId = data['post_id'] as String?;

      if (type == 'post_created' && feedId != null && postId != null) {
        // Check if this is the pending feed BEFORE clearing state
        final isPendingFeed = _pendingFeedId != null && feedId == _pendingFeedId;

        // Notify callback if feed is subscribed OR if it's the pending feed
        // Important: Check isPendingFeed BEFORE clearing _pendingFeedId
        if (_subscribedFeedIds.contains(feedId) || isPendingFeed) {
          print('[WebSocketService] New post in feed: feedId=$feedId, postId=$postId');
          _onPostCreatedCallback?.call(feedId, postId);
        } else {
          print('[WebSocketService] Ignoring post from non-subscribed feed: $feedId');
        }

        // Handle feed creation complete (only on first post for pending feed)
        if (isPendingFeed) {
          print('[WebSocketService] Feed creation complete: feedId=$feedId, postId=$postId');

          // Mark feed as created in cache
          NewsService.markFeedAsCreated(feedId);

          AnalyticsService().capture(EventSchema.websocketFeedCreated, properties: {
            'feed_id': feedId,
            'post_id': postId,
          });

          _feedCreationTimeout?.cancel();
          _onFeedCreationComplete?.call(feedId);

          // Clear pending state AFTER callbacks
          _pendingFeedId = null;
          _onFeedCreationComplete = null;
        }
      } else if (type == 'pong') {
        // Heartbeat response - connection is alive
        print('[WebSocketService] Received pong');
      } else {
        print('[WebSocketService] Ignoring message type: $type');
      }
    } catch (e) {
      print('[WebSocketService] Failed to parse message: $e');
    }
  }

  void _onError(dynamic error) {
    print('[WebSocketService] Connection error: $error');
    // Note: Connection errors are logged but not tracked in analytics (internal technical detail)

    _isConnected = false;
    _stopHeartbeat();
    _setState(WebSocketConnectionState.error);
    _scheduleReconnect();
  }

  void _onDone() {
    print('[WebSocketService] Connection closed');
    // Note: Disconnection is logged but not tracked in analytics (internal technical detail)

    _isConnected = false;
    _stopHeartbeat();
    _setState(WebSocketConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s max
    final delay = min(pow(2, _reconnectAttempts).toInt(), _maxReconnectDelay);
    _reconnectAttempts++;

    print('[WebSocketService] Scheduling reconnect in ${delay}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _connect();
    });
  }

  /// Reconnect WebSocket after token refresh (without backoff)
  void _reconnectForTokenRefresh() async {
    print('[WebSocketService] Reconnecting for token refresh');

    // Close existing connection gracefully
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close(status.normalClosure);
    _channel = null;
    _isConnected = false;
    _stopHeartbeat();

    // Reset reconnect attempts (this is a planned reconnection, not an error)
    _reconnectAttempts = 0;

    // Reconnect immediately with fresh token
    await _connect();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatInterval),
      (_) {
        if (_isConnected && _channel != null) {
          try {
            _channel!.sink.add(jsonEncode({'type': 'ping'}));
            print('[WebSocketService] Sent heartbeat ping');
          } catch (e) {
            print('[WebSocketService] Failed to send heartbeat: $e');
          }
        }
      },
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Update subscribed feeds (when user subscribes/unsubscribes to feeds)
  void updateSubscribedFeeds(Set<String> feedIds) {
    _subscribedFeedIds = feedIds;
    print('[WebSocketService] Updated subscribed feeds: ${feedIds.length} feeds');
  }

  /// Wait for feed creation to complete via WebSocket
  /// Automatically adds the feed to subscribed feeds
  void waitForFeedCreation({
    required String feedId,
    required Function(String feedId) onComplete,
    required Function() onTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) {
    print('[WebSocketService] Waiting for feed creation: $feedId');

    // Add to subscribed feeds so we receive the post_created event
    _subscribedFeedIds.add(feedId);

    _pendingFeedId = feedId;
    _onFeedCreationComplete = onComplete;

    // Set timeout
    _feedCreationTimeout?.cancel();
    _feedCreationTimeout = Timer(timeout, () {
      print('[WebSocketService] Feed creation timeout: $feedId');

      AnalyticsService().capture(EventSchema.websocketFeedCreationTimeout, properties: {
        'feed_id': feedId,
      });

      _pendingFeedId = null;
      _onFeedCreationComplete = null;
      onTimeout();
    });

  }

  /// Cancel waiting for feed creation
  void cancelFeedCreationWait() {
    _feedCreationTimeout?.cancel();
    _feedCreationTimeout = null;
    _pendingFeedId = null;
    _onFeedCreationComplete = null;
  }

  /// Disconnect WebSocket (alias for backward compatibility)
  void disconnectPersistent() => disconnect();

  /// Disconnect WebSocket
  void disconnect() {
    print('[WebSocketService] Disconnecting (explicit)');

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _feedCreationTimeout?.cancel();
    _feedCreationTimeout = null;
    _stopHeartbeat();
    _subscribedFeedIds = {};
    _onPostCreatedCallback = null;
    _pendingFeedId = null;
    _onFeedCreationComplete = null;
    _reconnectAttempts = 0;

    // Clean up token refresh subscription
    _authStateSubscription?.cancel();
    _authStateSubscription = null;
    _lastConnectionTime = null;

    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close(status.goingAway);
    _channel = null;
    _isConnected = false;
    _setState(WebSocketConnectionState.disconnected);
    // Note: Explicit disconnection is logged but not tracked in analytics (internal technical detail)
  }

  void _setState(WebSocketConnectionState newState) {
    _state = newState;
    notifyListeners();
  }
}

/// Connection states for WebSocket
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}
