import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
// TEMPORARILY DISABLED: AGP 8.0+ compatibility issues in CI/CD
// import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
// import 'package:android_dynamic_icon/android_dynamic_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';

/// Service for managing dynamic app icons on iOS and Android
///
/// Allows users to switch between dark (default) and light app icons.
/// Supports iOS (iOS 10.3+) and Android (API 21+).
///
/// Available icons:
/// - iOS:
///   - 'default': Dark icon (white jellyfish on black background)
///   - 'AppIconLight': Light icon (black jellyfish on white background)
/// - Android:
///   - 'MainActivityDefault': Dark icon
///   - 'MainActivityLight': Light icon
class AppIconService extends ChangeNotifier {
  static final AppIconService _instance = AppIconService._internal();
  factory AppIconService() => _instance;
  AppIconService._internal();

  static const String _iconKey = 'selected_app_icon';

  // iOS icon names
  static const String defaultIconIOS = 'default';
  static const String lightIconIOS = 'AppIconLight';

  // Android activity alias names
  static const String defaultIconAndroid = 'MainActivityDefault';
  static const String lightIconAndroid = 'MainActivityLight';

  String _currentIcon = '';
  bool _isInitialized = false;
  bool _isSupported = false;

  String get currentIcon => _currentIcon;
  bool get isInitialized => _isInitialized;
  bool get isSupported => _isSupported;
  bool get isDefaultIcon {
    if (Platform.isIOS) return _currentIcon == defaultIconIOS;
    if (Platform.isAndroid) return _currentIcon == defaultIconAndroid;
    return true;
  }
  bool get isLightIcon {
    if (Platform.isIOS) return _currentIcon == lightIconIOS;
    if (Platform.isAndroid) return _currentIcon == lightIconAndroid;
    return false;
  }

  /// Initialize the service - loads saved icon preference and checks platform support
  Future<void> initialize() async {
    if (_isInitialized) return;

    // TEMPORARILY DISABLED: Dynamic icon packages removed for AGP 8.0+ compatibility
    // Feature will be re-enabled once compatible packages are available
    _isSupported = false;

    // Set default icon based on platform
    if (Platform.isIOS) {
      _currentIcon = defaultIconIOS;
    } else if (Platform.isAndroid) {
      _currentIcon = defaultIconAndroid;
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Change the app icon
  ///
  /// TEMPORARILY DISABLED: Dynamic icon packages removed for AGP 8.0+ compatibility
  /// iOS: [iconName] should be 'default' or 'AppIconLight'
  /// Android: [iconName] should be 'MainActivityDefault' or 'MainActivityLight'
  /// Returns true if icon was changed successfully
  Future<bool> setIcon(String iconName) async {
    // Feature disabled - always return false
    if (kDebugMode) {
      print('AppIconService: Dynamic icon change disabled (AGP 8.0+ compatibility)');
    }
    return false;
  }

  /// Set the default (dark) icon
  Future<bool> setDefaultIcon() async {
    final iconName = Platform.isIOS ? defaultIconIOS : defaultIconAndroid;
    return await setIcon(iconName);
  }

  /// Set the light icon
  Future<bool> setLightIcon() async {
    final iconName = Platform.isIOS ? lightIconIOS : lightIconAndroid;
    return await setIcon(iconName);
  }

  /// Get current icon name for display
  String getIconDisplayName(String iconName) {
    if (iconName == defaultIconIOS || iconName == defaultIconAndroid) {
      return 'Dark';
    }
    if (iconName == lightIconIOS || iconName == lightIconAndroid) {
      return 'Light';
    }
    return iconName;
  }
}
