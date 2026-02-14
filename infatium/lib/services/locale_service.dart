import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import '../models/analytics_event_schema.dart';
import 'dart:ui' as ui;

class LocaleService extends ChangeNotifier {
  static final LocaleService _instance = LocaleService._internal();
  factory LocaleService() => _instance;
  LocaleService._internal();

  static const String _localeKey = 'selected_locale';
  
  Locale _currentLocale = const Locale('en'); // По умолчанию английский
  bool _isInitialized = false;
  
  Locale get currentLocale => _currentLocale;
  bool get isInitialized => _isInitialized;
  
  List<Locale> get supportedLocales => const [
    Locale('ru'),
    Locale('en'),
  ];

  /// Инициализация сервиса - загружает сохраненный язык или определяет по устройству
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString(_localeKey);
      
      if (savedLanguageCode != null) {
        // Загружаем сохраненный язык
        _currentLocale = Locale(savedLanguageCode);
      } else {
        // При первом запуске определяем язык по устройству
        _currentLocale = _getDeviceLocale();
        // Сохраняем определенный язык
        await prefs.setString(_localeKey, _currentLocale.languageCode);
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
      }
      _currentLocale = const Locale('en'); // Fallback к английскому при ошибке
      _isInitialized = true;
    }
  }

  /// Определение языка устройства
  Locale _getDeviceLocale() {
    final deviceLocale = ui.PlatformDispatcher.instance.locale;
    
    // Если язык устройства русский - используем русский
    if (deviceLocale.languageCode == 'ru') {
      return const Locale('ru');
    }
    
    // Для всех остальных языков используем английский
    return const Locale('en');
  }
  
  /// Установка языка
  Future<void> setLocale(Locale locale) async {
    if (_currentLocale == locale) return;
    
    _currentLocale = locale;
    
    // Сохраняем настройку
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
    } catch (e) {
      if (kDebugMode) {
      }
    }
    
    // Track locale change
    try {
      await AnalyticsService().capture(EventSchema.languageChanged, properties: {
        'language_code': locale.languageCode,
      });
    } catch (_) {}
    
    notifyListeners();
  }
  
  String getLocaleName(Locale locale) {
    switch (locale.languageCode) {
      case 'ru':
        return 'Русский';
      case 'en':
        return 'English';
      default:
        return locale.languageCode;
    }
  }
} 