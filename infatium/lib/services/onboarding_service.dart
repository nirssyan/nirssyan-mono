import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing onboarding state.
/// Uses singleton pattern (like ThemeService).
class OnboardingService extends ChangeNotifier {
  static final OnboardingService _instance = OnboardingService._internal();
  factory OnboardingService() => _instance;
  OnboardingService._internal();

  static const String _onboardingKey = 'onboarding_completed';
  bool _isCompleted = false;
  bool _isInitialized = false;

  bool get isCompleted => _isCompleted;
  bool get isInitialized => _isInitialized;

  bool get shouldShowOnboarding => !_isCompleted;

  /// Initialize service - load saved state from SharedPreferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedState = prefs.getBool(_onboardingKey);

      if (savedState != null) {
        _isCompleted = savedState;
      } else {
        _isCompleted = false;
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[OnboardingService] Error initializing: $e');
      }
      _isCompleted = false;
      _isInitialized = true;
    }
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    if (_isCompleted) return;

    _isCompleted = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
    } catch (e) {
      if (kDebugMode) {
        print('[OnboardingService] Error saving state: $e');
      }
    }

    notifyListeners();
  }

  /// Reset onboarding (for testing purposes)
  Future<void> resetOnboarding() async {
    _isCompleted = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, false);
    } catch (e) {
      if (kDebugMode) {
        print('[OnboardingService] Error resetting state: $e');
      }
    }

    notifyListeners();
  }
}
