/// Push notification configuration using compile-time constants.
///
/// These values are set via --dart-define flags during build time
/// and control notification behavior across the app.
class NotificationConfig {
  /// Controls whether push notifications are enabled.
  ///
  /// Set via --dart-define=ENABLE_NOTIFICATIONS=false to disable
  /// notifications for specific builds.
  ///
  /// Defaults to true - notifications are enabled by default.
  ///
  /// When false, all notification initialization code is skipped
  /// and the app won't request notification permissions.
  ///
  /// Usage:
  /// ```dart
  /// if (NotificationConfig.enableNotifications) {
  ///   await NotificationService().initialize();
  /// }
  /// ```
  static const bool enableNotifications = bool.fromEnvironment(
    'ENABLE_NOTIFICATIONS',
    defaultValue: true,
  );

  /// Android notification channel ID.
  ///
  /// This ID is used to create the default notification channel on Android.
  /// It must match the value in AndroidManifest.xml:
  /// `com.google.firebase.messaging.default_notification_channel_id`
  static const String androidChannelId = 'makefeed_default';

  /// Android notification channel name.
  ///
  /// This is the user-visible name of the notification channel.
  /// Users see this in Android Settings > Apps > Makefeed > Notifications.
  static const String androidChannelName = 'Makefeed Notifications';

  /// Android notification channel description.
  ///
  /// This is the user-visible description of the notification channel.
  /// Users see this in Android notification settings.
  static const String androidChannelDescription =
      'Notifications from Makefeed app';
}
