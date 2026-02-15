import 'package:flutter/cupertino.dart';

import '../models/feed_builder_models.dart';

/// Helper class for getting localized labels and icons for dynamic content views.
class ViewLabelHelper {
  /// Returns a formatted label for the given view key.
  /// Keys are space-separated (e.g. "in russian") and formatted by capitalizing each word.
  /// This shows the actual key names from the backend API.
  static String getLabel(BuildContext context, String key) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final view = ViewOptions.all.firstWhere(
      (v) => v.id == key || v.labelEn.toLowerCase() == key.toLowerCase(),
      orElse: () => ConfigOption(id: key, labelRu: _formatKey(key), labelEn: _formatKey(key)),
    );
    return view.getLabel(isRu);
  }

  /// Returns an icon for the given view key.
  static IconData getIcon(String key) {
    return CupertinoIcons.doc_plaintext;
  }

  /// Formats a space-separated key into a readable label.
  /// Example: "in russian" -> "In Russian"
  static String _formatKey(String key) {
    if (key.isEmpty) return key;
    return key
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }
}
