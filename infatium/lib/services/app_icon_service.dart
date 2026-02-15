import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Android MethodChannel
  static const MethodChannel _androidChannel =
      MethodChannel('com.nirssyan.makefeed/app_icon');

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

    try {
      if (Platform.isIOS) {
        _isSupported = await FlutterDynamicIcon.supportsAlternateIcons;
        if (_isSupported) {
          final iconName = await FlutterDynamicIcon.getAlternateIconName();
          _currentIcon = iconName ?? defaultIconIOS;
        } else {
          _currentIcon = defaultIconIOS;
        }
      } else if (Platform.isAndroid) {
        _isSupported = true;
        try {
          final iconName =
              await _androidChannel.invokeMethod<String>('getCurrentIcon');
          _currentIcon = iconName ?? defaultIconAndroid;
        } catch (e) {
          // Fallback to SharedPreferences if channel fails
          final prefs = await SharedPreferences.getInstance();
          _currentIcon =
              prefs.getString(_iconKey) ?? defaultIconAndroid;
          if (kDebugMode) {
            print('AppIconService: Android channel fallback to prefs: $e');
          }
        }
      }
    } catch (e) {
      // Graceful degradation — disable feature
      _isSupported = false;
      if (Platform.isIOS) {
        _currentIcon = defaultIconIOS;
      } else if (Platform.isAndroid) {
        _currentIcon = defaultIconAndroid;
      }
      if (kDebugMode) {
        print('AppIconService: initialization failed, feature disabled: $e');
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Change the app icon
  ///
  /// iOS: [iconName] should be 'default' or 'AppIconLight'
  /// Android: [iconName] should be 'MainActivityDefault' or 'MainActivityLight'
  /// Returns true if icon was changed successfully
  Future<bool> setIcon(String iconName) async {
    if (!_isSupported) {
      if (kDebugMode) {
        print('AppIconService: Dynamic icons not supported on this device');
      }
      return false;
    }

    try {
      if (Platform.isIOS) {
        if (iconName == defaultIconIOS) {
          await FlutterDynamicIcon.setAlternateIconName(null);
        } else {
          await FlutterDynamicIcon.setAlternateIconName(iconName);
        }
      } else if (Platform.isAndroid) {
        await _androidChannel
            .invokeMethod('setIcon', {'iconName': iconName});
      }

      _currentIcon = iconName;

      // Persist selection
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_iconKey, iconName);

      notifyListeners();

      if (kDebugMode) {
        print('AppIconService: Icon changed to $iconName');
      }
      return true;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('AppIconService: Failed to change icon: ${e.message}');
      }
      return false;
    }
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
