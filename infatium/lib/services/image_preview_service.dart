import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import '../models/analytics_event_schema.dart';

/// Service for managing Image Previews visibility in news feed
/// Controls whether image/video previews are shown in news cards
class ImagePreviewService extends ChangeNotifier {
  static final ImagePreviewService _instance = ImagePreviewService._internal();
  factory ImagePreviewService() => _instance;
  ImagePreviewService._internal();

  static const String _imagePreviewsKey = 'image_previews_enabled';
  bool _showImagePreviews = true; // Default: previews are shown
  bool _isInitialized = false;

  bool get showImagePreviews => _showImagePreviews;
  bool get isInitialized => _isInitialized;

  /// Initialize service - loads saved preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedImagePreviews = prefs.getBool(_imagePreviewsKey);

      if (savedImagePreviews != null) {
        _showImagePreviews = savedImagePreviews;
      } else {
        // First time: default to true (show previews)
        _showImagePreviews = true;
        await prefs.setBool(_imagePreviewsKey, _showImagePreviews);
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('ImagePreviewService: Error initializing: $e');
      }
      _showImagePreviews = true; // Fallback to showing previews
      _isInitialized = true;
    }
  }

  /// Toggle Image Previews on/off
  Future<void> toggleImagePreviews() async {
    await setImagePreviews(!_showImagePreviews);
  }

  /// Set Image Previews state
  Future<void> setImagePreviews(bool enabled) async {
    if (_showImagePreviews == enabled) return;

    _showImagePreviews = enabled;

    // Save setting
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_imagePreviewsKey, enabled);
    } catch (e) {
      if (kDebugMode) {
        print('ImagePreviewService: Error saving: $e');
      }
    }

    // Track image previews change
    try {
      await AnalyticsService().capture(EventSchema.imagePreviewsToggled, properties: {
        'enabled': _showImagePreviews,
      });
    } catch (_) {
      // Silently fail - analytics is optional
    }

    notifyListeners();
  }
}
