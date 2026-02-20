import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import '../models/analytics_event_schema.dart';

/// App Tracking Transparency (ATT) service for iOS
///
/// Manages the ATT permission prompt required by Apple for IDFA access.
/// Used by AppMetrica for install attribution (SKAdNetwork postbacks).
///
/// **Behavior:**
/// - Only runs on iOS (no-op on other platforms)
/// - Respects GDPR opt-out from AnalyticsService
/// - Caches "prompt shown" state via SharedPreferences
/// - Tracks result via analytics event
///
/// **Usage:**
/// ```dart
/// // Call after app is loaded and user is authenticated
/// await AttService().requestTrackingIfNeeded();
/// ```
class AttService {
  static final AttService _instance = AttService._internal();
  factory AttService() => _instance;
  AttService._internal();

  static const String _kPromptShownKey = 'att_prompt_shown';

  /// Request ATT permission if not already shown.
  ///
  /// No-op if:
  /// - Not running on iOS
  /// - User has opted out of analytics (GDPR)
  /// - Prompt was already shown in a previous session
  /// - ATT status is already determined (user changed in Settings)
  Future<void> requestTrackingIfNeeded() async {
    // Only relevant on iOS
    if (!Platform.isIOS) return;

    try {
      // Respect GDPR opt-out
      final isOptedOut = await AnalyticsService().isOptedOut();
      if (isOptedOut) {
        if (kDebugMode) {
          print('AttService: Skipping ATT — analytics opted out');
        }
        return;
      }

      // Check if prompt was already shown
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool(_kPromptShownKey) ?? false;
      if (alreadyShown) {
        if (kDebugMode) {
          print('AttService: Prompt already shown, skipping');
        }
        return;
      }

      // Check current status — if already determined, don't show again
      final currentStatus =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (currentStatus != TrackingStatus.notDetermined) {
        // Already decided (via Settings or previous prompt) — mark as shown
        await prefs.setBool(_kPromptShownKey, true);
        if (kDebugMode) {
          print('AttService: Status already determined: $currentStatus');
        }
        return;
      }

      // Show the ATT prompt
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();

      // Mark as shown
      await prefs.setBool(_kPromptShownKey, true);

      final statusName = _statusToString(status);
      if (kDebugMode) {
        print('AttService: ATT authorization result: $statusName');
      }

      // Track the result
      await AnalyticsService().capture(
        EventSchema.attStatusChanged,
        properties: {
          'status': statusName,
          'platform': 'ios',
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('AttService: Error requesting tracking: $e');
      }
    }
  }

  String _statusToString(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.notDetermined:
        return 'not_determined';
      case TrackingStatus.restricted:
        return 'restricted';
      case TrackingStatus.denied:
        return 'denied';
      case TrackingStatus.authorized:
        return 'authorized';
      default:
        return 'unknown';
    }
  }
}
