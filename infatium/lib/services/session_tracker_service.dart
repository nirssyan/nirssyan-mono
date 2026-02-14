import 'package:flutter/widgets.dart';
import 'analytics_service.dart';
import '../models/analytics_event_schema.dart';

/// Tracks app session duration and engagement metrics
///
/// Monitors app lifecycle (foreground/background) and collects:
/// - Session duration (time between app open and backgrounding)
/// - Screens viewed (unique route names visited)
/// - Posts viewed (tracked externally, aggregated here)
///
/// **Usage:**
/// ```dart
/// // In main app widget
/// class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
///   final SessionTrackerService _sessionTracker = SessionTrackerService();
///
///   @override
///   void initState() {
///     super.initState();
///     WidgetsBinding.instance.addObserver(this);
///     _sessionTracker.initialize();
///   }
///
///   @override
///   void dispose() {
///     WidgetsBinding.instance.removeObserver(this);
///     _sessionTracker.dispose();
///     super.dispose();
///   }
///
///   @override
///   void didChangeAppLifecycleState(AppLifecycleState state) {
///     _sessionTracker.handleLifecycleChange(state);
///   }
/// }
/// ```
class SessionTrackerService {
  static final SessionTrackerService _instance = SessionTrackerService._internal();
  factory SessionTrackerService() => _instance;
  SessionTrackerService._internal();

  DateTime? _sessionStartTime;
  final Set<String> _screensViewed = {};
  int _postsViewed = 0;
  bool _isActive = false;

  /// Initialize session tracking
  void initialize() {
    _startSession();
  }

  /// Handle app lifecycle state changes
  void handleLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground
        if (!_isActive) {
          _startSession();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App going to background
        if (_isActive) {
          _endSession();
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App being terminated or hidden
        if (_isActive) {
          _endSession();
        }
        break;
    }
  }

  /// Start a new session
  void _startSession() {
    _sessionStartTime = DateTime.now();
    _screensViewed.clear();
    _postsViewed = 0;
    _isActive = true;
    debugPrint('SessionTracker: Session started');
  }

  /// End current session and track analytics
  void _endSession() {
    if (_sessionStartTime == null || !_isActive) return;

    final duration = DateTime.now().difference(_sessionStartTime!);
    final durationSeconds = duration.inSeconds;

    // Track session ended event
    AnalyticsService().capture(EventSchema.sessionEnded, properties: {
      'duration_seconds': durationSeconds,
      'screens_viewed': _screensViewed.length,
      'posts_viewed': _postsViewed,
    });

    debugPrint('SessionTracker: Session ended - ${durationSeconds}s, '
        '${_screensViewed.length} screens, $_postsViewed posts');

    _isActive = false;
  }

  /// Track screen view (call when navigating to new route)
  void trackScreenView(String screenName) {
    if (!_isActive) return;
    _screensViewed.add(screenName);
  }

  /// Increment post view counter
  void trackPostView() {
    if (!_isActive) return;
    _postsViewed++;
  }

  /// Get current session duration in seconds (for debugging)
  int? get currentSessionDuration {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!).inSeconds;
  }

  /// Get screens viewed count (for debugging)
  int get screensViewedCount => _screensViewed.length;

  /// Get posts viewed count (for debugging)
  int get postsViewedCount => _postsViewed;

  /// Cleanup
  void dispose() {
    if (_isActive) {
      _endSession();
    }
  }
}
