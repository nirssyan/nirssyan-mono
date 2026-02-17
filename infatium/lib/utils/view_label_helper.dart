import 'package:flutter/cupertino.dart';

import '../models/feed_builder_models.dart';

/// Helper class for getting localized labels and icons for dynamic content views.
class ViewLabelHelper {
  /// Returns a label for the given view key, using backend names as-is.
  static String getLabel(BuildContext context, String key) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final view = ViewOptions.all.firstWhere(
      (v) => v.id == key || v.labelEn.toLowerCase() == key.toLowerCase(),
      orElse: () => ConfigOption(id: key, labelRu: key, labelEn: key),
    );
    return view.getLabel(isRu);
  }

  /// Returns an icon for the given view key.
  static IconData getIcon(String key) {
    return CupertinoIcons.doc_plaintext;
  }
}
