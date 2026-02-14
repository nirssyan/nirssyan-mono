/// Application-wide configuration using compile-time constants.
///
/// These values are set via --dart-define flags during build time
/// and allow for different app behaviors across distribution channels.
class AppConfig {
  /// Controls the text displayed in the splash screen animation.
  ///
  /// Set via --dart-define=SPLASH_TEXT="your_text" to customize the splash
  /// screen text during build time.
  ///
  /// Defaults to 'infatium' if not specified.
  ///
  /// The text will be displayed with a typing animation effect on app startup.
  ///
  /// Usage:
  /// ```bash
  /// flutter run --dart-define=SPLASH_TEXT="makefeed"
  /// flutter build ipa --dart-define=SPLASH_TEXT="custom_name"
  /// ```
  ///
  /// ```dart
  /// Text(AppConfig.splashText); // Displays configured text
  /// ```
  static const String splashText = String.fromEnvironment(
    'SPLASH_TEXT',
    defaultValue: 'infatium',
  );
}
