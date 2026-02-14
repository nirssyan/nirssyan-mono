import 'package:flutter/cupertino.dart';

/// Helper class for getting localized labels and icons for dynamic content views.
class ViewLabelHelper {
  /// Returns a formatted label for the given view key.
  /// All keys are formatted by capitalizing and replacing underscores with spaces.
  /// This shows the actual key names from the backend API.
  static String getLabel(BuildContext context, String key) {
    return _formatUnknownKey(key);
  }

  /// Returns an icon for the given view key.
  static IconData getIcon(String key) {
    return CupertinoIcons.doc_plaintext;
  }

  /// Formats an unknown key into a readable label.
  /// Example: "ai_analysis" -> "Ai Analysis"
  static String _formatUnknownKey(String key) {
    if (key.isEmpty) return key;
    return key
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }
}
