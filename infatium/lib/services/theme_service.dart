import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import '../models/analytics_event_schema.dart';
import 'dart:ui' as ui;

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themeKey = 'is_dark_mode';
  bool _isDarkMode = false; // Default to light mode
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;
  Brightness get brightness => _isDarkMode ? Brightness.dark : Brightness.light;

  /// Определение темы устройства
  Brightness _getDeviceBrightness() {
    return ui.PlatformDispatcher.instance.platformBrightness;
  }

  /// Инициализация сервиса - загружает сохраненную тему
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getBool(_themeKey);

      if (savedTheme != null) {
        // Загружаем сохраненную тему
        _isDarkMode = savedTheme;
      } else {
        // При первом запуске определяем тему по устройству
        _isDarkMode = _getDeviceBrightness() == Brightness.dark;
        // Сохраняем определенную тему
        await prefs.setBool(_themeKey, _isDarkMode);
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
      }
      _isDarkMode = false; // Fallback к светлой теме при ошибке
      _isInitialized = true;
    }
  }

  /// Переключение темы
  Future<void> toggleTheme() async {
    await setDarkMode(!_isDarkMode);
  }

  /// Установка темы
  Future<void> setDarkMode(bool isDark) async {
    if (_isDarkMode == isDark) return;
    
    _isDarkMode = isDark;
    
    // Сохраняем настройку
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, isDark);
    } catch (e) {
      if (kDebugMode) {
      }
    }
    
    // Track theme change
    try {
      await AnalyticsService().capture(EventSchema.themeChanged, properties: {
        'is_dark_mode': _isDarkMode,
      });
    } catch (_) {}
    
    notifyListeners();
  }
} 