import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import '../models/analytics_event_schema.dart';

/// Service for managing Zen Mode (hiding unread counters)
/// Zen Mode helps users focus on content without distraction from unread badges
class ZenModeService extends ChangeNotifier {
  static final ZenModeService _instance = ZenModeService._internal();
  factory ZenModeService() => _instance;
  ZenModeService._internal();

  static const String _zenModeKey = 'zen_mode_enabled';
  bool _isZenMode = false; // Default: counters are shown
  bool _isInitialized = false;

  bool get isZenMode => _isZenMode;
  bool get isInitialized => _isInitialized;

  /// Initialize service - loads saved preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedZenMode = prefs.getBool(_zenModeKey);

      if (savedZenMode != null) {
        _isZenMode = savedZenMode;
      } else {
        // First time: default to false (show counters)
        _isZenMode = false;
        await prefs.setBool(_zenModeKey, _isZenMode);
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('ZenModeService: Error initializing: $e');
      }
      _isZenMode = false; // Fallback to showing counters
      _isInitialized = true;
    }
  }

  /// Toggle Zen Mode on/off
  Future<void> toggleZenMode() async {
    await setZenMode(!_isZenMode);
  }

  /// Set Zen Mode state
  Future<void> setZenMode(bool enabled) async {
    if (_isZenMode == enabled) return;

    _isZenMode = enabled;

    // Save setting
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_zenModeKey, enabled);
    } catch (e) {
      if (kDebugMode) {
        print('ZenModeService: Error saving: $e');
      }
    }

    // Track zen mode change
    try {
      await AnalyticsService().capture(EventSchema.zenModeToggled, properties: {
        'enabled': _isZenMode,
      });
    } catch (_) {
      // Silently fail - analytics is optional
    }

    notifyListeners();
  }
}
