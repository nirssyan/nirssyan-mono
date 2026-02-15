import 'package:flutter/foundation.dart';
import '../services/suggestion_service.dart';

class FeedBuilderMessage {
  final String id;
  final String type; // 'ai' or 'human'
  final String sessionId; // JSON key is still 'chat_id' for backend compatibility
  final String message;
  final DateTime createdAt;

  FeedBuilderMessage({
    required this.id,
    required this.type,
    required this.sessionId,
    required this.message,
    required this.createdAt,
  });

  factory FeedBuilderMessage.fromJson(Map<String, dynamic> json) {
    return FeedBuilderMessage(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      sessionId: (json['chat_id'] as String?) ?? '', // Backend uses 'chat_id'
      message: (json['message'] as String?) ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'chat_id': sessionId, // Backend expects 'chat_id'
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isUser => type == 'HUMAN';
  bool get isAI => type == 'AI';
}

class FeedBuilderSession {
  final String sessionId; // JSON key is still 'chat_id' for backend compatibility
  final DateTime createdAt;
  final List<FeedBuilderMessage> messages;
  final List<String>? suggestions;
  final bool? isReadyToCreateFeed;

  FeedBuilderSession({
    required this.sessionId,
    required this.createdAt,
    required this.messages,
    this.suggestions,
    this.isReadyToCreateFeed,
  });

  factory FeedBuilderSession.fromJson(Map<String, dynamic> json) {
    final sessionId = (json['chat_id'] as String?) ?? ''; // Backend uses 'chat_id'
    if (kDebugMode) {
    }
    
    // Парсим suggestions
    List<String>? suggestions;
    if (json.containsKey('suggestions') && json['suggestions'] != null) {
      final suggestionsData = json['suggestions'];
      if (suggestionsData is List) {
        suggestions = suggestionsData
            .where((s) => s != null && s.toString().isNotEmpty)
            .map((s) => s.toString())
            .toList();
      }
    }

    // Парсим готовность к созданию фида
    bool? isReadyToCreateFeed;
    if (json.containsKey('is_ready_to_create_feed')) {
      isReadyToCreateFeed = json['is_ready_to_create_feed'] as bool?;
      if (kDebugMode) {
      }
    }

    return FeedBuilderSession(
      sessionId: sessionId,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      messages: ((json['messages'] as List<dynamic>?)
              ?.map((messageJson) => FeedBuilderMessage.fromJson(messageJson as Map<String, dynamic>))
              .toList() ??
          [])
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      suggestions: suggestions,
      isReadyToCreateFeed: isReadyToCreateFeed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': sessionId, // Backend expects 'chat_id'
      'created_at': createdAt.toIso8601String(),
      'messages': messages.map((message) => message.toJson()).toList(),
      'suggestions': suggestions,
      'is_ready_to_create_feed': isReadyToCreateFeed,
    };
  }

  // Get last message for preview
  FeedBuilderMessage? get lastMessage {
    if (messages.isEmpty) return null;

    final sortedMessages = List<FeedBuilderMessage>.from(messages)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sortedMessages.first;
  }

  // Get last activity time (for sorting sessions)
  DateTime get lastActivityAt {
    final lastMsg = lastMessage;
    return lastMsg?.createdAt ?? createdAt;
  }

  // Get short ID for display
  String get shortId {
    if (sessionId.length <= 8) return sessionId;
    return sessionId.substring(0, 8);
  }

  // Get last message preview
  // Uses l10n fallback string for empty sessions.
  // Caller should provide the translated fallback from AppLocalizations:
  //   l10n.feedBuilderStartCreating
  String getLastMessagePreview({String? emptyFallback}) {
    final lastMsg = lastMessage;
    if (lastMsg == null) {
      return emptyFallback ?? 'Start creating';
    }

    final text = lastMsg.message;
    if (text.length <= 50) return text;
    return '${text.substring(0, 47)}...';
  }

  // Get session title
  // Caller should provide the translated session label from AppLocalizations:
  //   l10n.feedBuilderSession
  String getSessionTitle({String? sessionLabel}) {
    final label = sessionLabel ?? 'Session';
    return '$label $shortId';
  }
}

class CreateSessionResponse {
  final String sessionId; // JSON key is still 'chat_id' for backend compatibility

  CreateSessionResponse({
    required this.sessionId,
  });

  factory CreateSessionResponse.fromJson(Map<String, dynamic> json) {
    return CreateSessionResponse(
      sessionId: (json['id'] as String?) ?? (json['chat_id'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': sessionId, // Backend expects 'chat_id'
    };
  }
}

class FeedOwner {
  final String id;
  final String name;

  FeedOwner({
    required this.id,
    required this.name,
  });

  factory FeedOwner.fromJson(Map<String, dynamic> json) {
    return FeedOwner(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

/// Localized string with en/ru translations
/// For sources, may also include url and type fields
class LocalizedItem {
  final String en;
  final String ru;
  final String? url;   // Source URL (e.g., https://t.me/channel)
  final String? type;  // Source type (e.g., TELEGRAM, RSS)

  const LocalizedItem({
    required this.en,
    required this.ru,
    this.url,
    this.type,
  });

  /// Get label based on current locale
  String getLabel(bool isRu) => isRu ? ru : en;

  /// Fallback to en if ru is empty
  String getLabelSafe(bool isRu) => isRu && ru.isNotEmpty ? ru : en;

  /// Parse from JSON - handles both old (string) and new (object) formats
  /// Old format: "Summary" -> LocalizedItem(en: "Summary", ru: "Summary")
  /// New format: {"en": "Summary", "ru": "Саммари"} -> LocalizedItem(en: "Summary", ru: "Саммари")
  /// Extended format: {"en": "Name", "ru": "Name", "url": "https://t.me/channel", "type": "TELEGRAM"}
  factory LocalizedItem.fromJson(dynamic json) {
    if (json is String) {
      // Old format: plain string - use same value for both languages
      return LocalizedItem(en: json, ru: json);
    } else if (json is Map<String, dynamic>) {
      // Nested format from go-processor: {"name": {"en": "...", "ru": "..."}, "prompt": "..."}
      if (json['name'] is Map<String, dynamic>) {
        final name = json['name'] as Map<String, dynamic>;
        return LocalizedItem(
          en: name['en'] as String? ?? '',
          ru: name['ru'] as String? ?? name['en'] as String? ?? '',
        );
      }
      // Flat format: {"en": "...", "ru": "...", "url": "...", "type": "..."}
      return LocalizedItem(
        en: json['en'] as String? ?? '',
        ru: json['ru'] as String? ?? json['en'] as String? ?? '',
        url: json['url'] as String?,
        type: json['type'] as String?,
      );
    } else {
      // Fallback for unexpected types
      return LocalizedItem(en: json?.toString() ?? '', ru: json?.toString() ?? '');
    }
  }

  Map<String, dynamic> toJson() => {
    'en': en,
    'ru': ru,
    if (url != null) 'url': url,
    if (type != null) 'type': type,
  };

  @override
  String toString() => en; // Fallback for debugging
}

class FeedPreview {
  final String? id; // null for preview, feed_id for existing feeds
  final String name;
  final String description;
  final DateTime? createdAt; // null for preview
  final String type; // FILTER, SUMMARY, COMMENT, READ
  final FeedOwner owner;
  final String prompt;
  final List<LocalizedItem> sources;
  final int? digestIntervalHours;
  // NEW: views and filters arrays (localized)
  final List<LocalizedItem>? views;
  final List<LocalizedItem>? filters;
  // LEGACY: kept for backward compatibility, backend handles migration
  final bool? filterAds;
  final bool? filterDuplicates;

  FeedPreview({
    this.id,
    required this.name,
    required this.description,
    this.createdAt,
    required this.type,
    required this.owner,
    required this.prompt,
    required this.sources,
    this.digestIntervalHours,
    this.views,
    this.filters,
    this.filterAds,
    this.filterDuplicates,
  });

  factory FeedPreview.fromJson(Map<String, dynamic> json) {
    return FeedPreview(
      id: json['id'] as String?,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      type: (json['type'] as String?) ?? '',
      owner: FeedOwner.fromJson((json['owner'] as Map<String, dynamic>?) ?? {}),
      prompt: (json['prompt'] as String?) ?? '',
      // sources/views/filters: handle both old (string array) and new (object array) formats
      sources: (json['sources'] as List<dynamic>?)
          ?.map((s) => LocalizedItem.fromJson(s))
          .toList() ?? [],
      digestIntervalHours: json['digest_interval_hours'] as int?,
      views: (json['views'] as List<dynamic>?)
          ?.map((v) => LocalizedItem.fromJson(v))
          .toList(),
      filters: (json['filters'] as List<dynamic>?)
          ?.map((f) => LocalizedItem.fromJson(f))
          .toList(),
      filterAds: json['filter_ads'] as bool?,
      filterDuplicates: json['filter_duplicates'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'type': type,
      'owner': owner.toJson(),
      'prompt': prompt,
      'sources': sources.map((s) => s.toJson()).toList(),
      if (digestIntervalHours != null) 'digest_interval_hours': digestIntervalHours,
      if (views != null && views!.isNotEmpty) 'views': views!.map((v) => v.toJson()).toList(),
      if (filters != null && filters!.isNotEmpty) 'filters': filters!.map((f) => f.toJson()).toList(),
      if (filterAds != null) 'filter_ads': filterAds,
      if (filterDuplicates != null) 'filter_duplicates': filterDuplicates,
    };
  }

  // Проверка, является ли это preview (еще не созданная лента)
  bool get isPreview => id == null;
}

/// Feed type for creation form
enum FeedType {
  SINGLE_POST,
  DIGEST,
}

extension FeedTypeExtension on FeedType {
  /// API value for backend
  String get apiValue => name; // 'SINGLE_POST' or 'DIGEST'

  /// l10n key identifier for display name.
  /// Callers should use AppLocalizations to get translated strings:
  ///   FeedType.SINGLE_POST -> l10n.feedTypeIndividualPosts
  ///   FeedType.DIGEST -> l10n.feedTypeDigestLabel
  String get displayNameKey {
    switch (this) {
      case FeedType.SINGLE_POST:
        return 'feedTypeIndividualPosts';
      case FeedType.DIGEST:
        return 'feedTypeDigestLabel';
    }
  }

  /// l10n key identifier for description.
  /// Callers should use AppLocalizations to get translated strings:
  ///   FeedType.SINGLE_POST -> l10n.feedTypeIndividualPostsDesc
  ///   FeedType.DIGEST -> l10n.feedTypeDigestLabelDesc
  String get descriptionKey {
    switch (this) {
      case FeedType.SINGLE_POST:
        return 'feedTypeIndividualPostsDesc';
      case FeedType.DIGEST:
        return 'feedTypeDigestLabelDesc';
    }
  }
}

/// Current state of feed info from PATCH response
class CurrentFeedInfo {
  final String? title;
  final String? description;
  final List<String> tags;
  final List<String> sources;
  final Map<String, String> sourceTypes;
  final String? type;
  final String? prompt;
  final int? digestIntervalHours;

  CurrentFeedInfo({
    this.title,
    this.description,
    required this.tags,
    required this.sources,
    required this.sourceTypes,
    this.type,
    this.prompt,
    this.digestIntervalHours,
  });

  factory CurrentFeedInfo.fromJson(Map<String, dynamic> json) {
    return CurrentFeedInfo(
      title: json['title'] as String?,
      description: json['description'] as String?,
      tags: ((json['tags'] as List<dynamic>?) ?? [])
          .map((t) => t.toString())
          .toList(),
      sources: ((json['sources'] as List<dynamic>?) ?? [])
          .map((s) => s.toString())
          .toList(),
      sourceTypes: ((json['source_types'] as Map<String, dynamic>?) ?? {})
          .map((key, value) => MapEntry(key, value.toString())),
      type: json['type'] as String?,
      prompt: json['prompt'] as String?,
      digestIntervalHours: json['digest_interval_hours'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'tags': tags,
      'sources': sources,
      'source_types': sourceTypes,
      'type': type,
      'prompt': prompt,
      'digest_interval_hours': digestIntervalHours,
    };
  }
}

/// Response from PATCH /chats/{chat_id}/feed_preview
class FeedPreviewUpdateResponse {
  final bool success;
  final String message;
  final CurrentFeedInfo currentFeedInfo;
  final bool isReadyToCreateFeed;
  final List<String> exceptions;

  FeedPreviewUpdateResponse({
    required this.success,
    required this.message,
    required this.currentFeedInfo,
    required this.isReadyToCreateFeed,
    required this.exceptions,
  });

  factory FeedPreviewUpdateResponse.fromJson(Map<String, dynamic> json) {
    return FeedPreviewUpdateResponse(
      success: (json['success'] as bool?) ?? false,
      message: (json['message'] as String?) ?? '',
      currentFeedInfo: CurrentFeedInfo.fromJson(
          (json['current_feed_info'] as Map<String, dynamic>?) ?? {}),
      isReadyToCreateFeed: (json['is_ready_to_create_feed'] as bool?) ?? false,
      exceptions: ((json['exceptions'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'current_feed_info': currentFeedInfo.toJson(),
      'is_ready_to_create_feed': isReadyToCreateFeed,
      'exceptions': exceptions,
    };
  }
}

// ============================================================================
// NEW API: POST /feeds/create
// ============================================================================

/// Source item for feed creation API
class SourceItem {
  final String url;
  final String type; // 'RSS' | 'TELEGRAM'

  SourceItem({
    required this.url,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'type': type,
  };

  factory SourceItem.fromJson(Map<String, dynamic> json) {
    return SourceItem(
      url: (json['url'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'RSS',
    );
  }
}

/// Request body for POST /feeds/create
class CreateFeedRequest {
  final String? name; // Optional - backend auto-generates if null
  final List<SourceItem> sources; // SourceInput objects {url, type}
  final String feedType; // 'SINGLE_POST' | 'DIGEST'
  final List<String>? viewsRaw;
  final List<String>? filtersRaw;
  final int? digestIntervalHours; // 1-48, only for DIGEST

  CreateFeedRequest({
    this.name,
    required this.sources,
    required this.feedType,
    this.viewsRaw,
    this.filtersRaw,
    this.digestIntervalHours,
  });

  Map<String, dynamic> toJson() => {
    if (name != null && name!.isNotEmpty) 'name': name,
    'sources': sources.map((s) => s.toJson()).toList(),
    'feed_type': feedType,
    if (viewsRaw != null && viewsRaw!.isNotEmpty) 'views_raw': viewsRaw,
    if (filtersRaw != null && filtersRaw!.isNotEmpty) 'filters_raw': filtersRaw,
    if (digestIntervalHours != null) 'digest_interval_hours': digestIntervalHours,
  };
}

/// Response from POST /feeds/create
class CreateFeedResponse {
  final bool success;
  final String? feedId;
  final String? message;

  CreateFeedResponse({
    required this.success,
    this.feedId,
    this.message,
  });

  factory CreateFeedResponse.fromJson(Map<String, dynamic> json) {
    return CreateFeedResponse(
      success: (json['success'] as bool?) ?? false,
      feedId: json['feed_id'] as String?,
      message: json['message'] as String?,
    );
  }
}

// ============================================================================
// Configuration options for feed creation wizard
// ============================================================================

/// Option for style/filter chip selection.
/// For API-provided options, labelRu/labelEn come from backend.
/// For default options, l10nKey is set so callers can use AppLocalizations.
/// Callers should prefer l10nKey when available, falling back to labelRu/labelEn.
class ConfigOption {
  final String id;
  final String labelRu;
  final String labelEn;
  /// Optional l10n key for translation via AppLocalizations at display layer.
  /// When set, callers should use AppLocalizations to get the translated label
  /// instead of using labelRu/labelEn directly.
  final String? l10nKey;

  const ConfigOption({
    required this.id,
    required this.labelRu,
    required this.labelEn,
    this.l10nKey,
  });

  /// Get label based on locale. For default options with l10nKey,
  /// callers should use AppLocalizations instead for proper localization.
  String getLabel(bool isRu) => isRu ? labelRu : labelEn;
}

/// Predefined view options (how to process/display content)
class ViewOptions {
  /// Get view options from API, fallback to defaults if empty
  static List<ConfigOption> get all {
    final apiViews = SuggestionService().views;
    if (apiViews.isNotEmpty) {
      return apiViews.map((s) => ConfigOption(
        id: s.id,
        labelRu: s.name['ru'] ?? s.name['en'] ?? '',
        labelEn: s.name['en'] ?? '',
      )).toList();
    }
    return defaults;
  }

  static const List<ConfigOption> defaults = [
    ConfigOption(id: 'brief', labelRu: 'Краткий пересказ', labelEn: 'Brief summary', l10nKey: 'configBriefSummary'),
    ConfigOption(id: 'bullets', labelRu: 'Bullet points', labelEn: 'Bullet points'),
    ConfigOption(id: 'analysis', labelRu: 'С анализом', labelEn: 'With analysis', l10nKey: 'configWithAnalysis'),
    ConfigOption(id: 'original', labelRu: 'Оригинал', labelEn: 'Original', l10nKey: 'configOriginal'),
    ConfigOption(id: 'highlights', labelRu: 'Только главное', labelEn: 'Highlights only', l10nKey: 'configKeyPointsOnly'),
  ];
}

/// Predefined filter options (what to remove from content)
class FilterOptions {
  /// Get filter options from API, fallback to defaults if empty
  static List<ConfigOption> get all {
    final apiFilters = SuggestionService().filters;
    if (apiFilters.isNotEmpty) {
      return apiFilters.map((s) => ConfigOption(
        id: s.id,
        labelRu: s.name['ru'] ?? s.name['en'] ?? '',
        labelEn: s.name['en'] ?? '',
      )).toList();
    }
    return defaults;
  }

  static const List<ConfigOption> defaults = [
    ConfigOption(id: 'duplicates', labelRu: 'Удалять дубликаты', labelEn: 'Remove duplicates', l10nKey: 'configRemoveDuplicates'),
    ConfigOption(id: 'ads', labelRu: 'Фильтровать рекламу', labelEn: 'Filter ads', l10nKey: 'configFilterAds'),
    ConfigOption(id: 'spam', labelRu: 'Убирать спам', labelEn: 'Remove spam', l10nKey: 'configRemoveSpam'),
    ConfigOption(id: 'clickbait', labelRu: 'Без кликбейта', labelEn: 'No clickbait', l10nKey: 'configNoClickbait'),
  ];
}
