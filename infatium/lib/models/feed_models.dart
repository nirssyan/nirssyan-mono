import 'feed_builder_models.dart'; // For FeedType enum
import 'media_object.dart';

class Source {
  final String id;
  final String postId;
  final String? sourceUrl;
  final DateTime createdAt;

  Source({
    required this.id,
    required this.postId,
    this.sourceUrl,
    required this.createdAt,
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: (json['id'] as String?) ?? '',
      postId: (json['post_id'] as String?) ?? '',
      sourceUrl: json['source_url'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'source_url': sourceUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Post {
  final String id;
  final String title;
  final String feedId;
  final List<Source> sources;
  final Map<String, String> views; // Dynamic views from v2 API
  final String? imageUrl;
  final List<String> mediaUrls; // Для обратной совместимости
  final List<MediaObject> mediaObjects; // Новый контракт с метаданными
  final DateTime createdAt;
  final bool seen; // Статус просмотра поста пользователем

  Post({
    required this.id,
    required this.title,
    required this.feedId,
    required this.sources,
    this.views = const {},
    this.imageUrl,
    this.mediaUrls = const [],
    this.mediaObjects = const [],
    required this.createdAt,
    this.seen = false, // По умолчанию пост не просмотрен
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final postId = json['id'] ?? 'unknown';
    // DEBUG: Log raw media fields at start of parsing
    print('[Post.fromJson] Parsing post $postId:');
    print('  raw media_objects: ${json['media_objects']}');
    print('  raw media_urls: ${json['media_urls']}');
    print('  raw image_url: ${json['image_url']}');

    // Переменные для совместимости со старым API
    String? singleImage;
    List<String> multipleImages = [];

    // Парсим media_objects (новый контракт)
    List<MediaObject> mediaObjects = [];
    final dynamic rawMediaObjects = json['media_objects'];
    if (rawMediaObjects is List && rawMediaObjects.isNotEmpty) {
      print('[Post.fromJson] Using media_objects path (${rawMediaObjects.length} items)');
      for (var i = 0; i < rawMediaObjects.length; i++) {
        final objData = rawMediaObjects[i];
        if (objData is Map<String, dynamic>) {
          try {
            final mediaObj = MediaObject.fromJson(objData);
            mediaObjects.add(mediaObj);
          } catch (e) {
            // Silently skip malformed media objects
          }
        }
      }

      // Генерируем URLs для совместимости
      multipleImages = mediaObjects.map((m) => m.url).toList();
      singleImage = multipleImages.isNotEmpty ? multipleImages.first : null;
    } else {
      // Fallback на старый контракт
      print('[Post.fromJson] Fallback to old API contract');

      // Обрабатываем video_urls и video_preview_urls
      final dynamic rawVideoUrls = json['video_urls'];
      final dynamic rawVideoPreviewUrls = json['video_preview_urls'];

      if (rawVideoUrls is List && rawVideoUrls.isNotEmpty) {
        // Получаем список preview urls
        List<String> previewUrls = [];
        if (rawVideoPreviewUrls is List) {
          previewUrls = rawVideoPreviewUrls
              .where((e) => e != null)
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
        }

        // Создаем MediaObjects для видео
        for (int i = 0; i < rawVideoUrls.length; i++) {
          final videoUrl = rawVideoUrls[i];
          if (videoUrl != null && videoUrl.toString().isNotEmpty) {
            final previewUrl = i < previewUrls.length ? previewUrls[i] : null;

            mediaObjects.add(MediaObject(
              type: MediaType.video,
              url: videoUrl.toString(),
              previewUrl: previewUrl,
            ));
          }
        }
      }

      // Сначала пробуем media_urls для изображений
      final dynamic rawMediaUrls = json['media_urls'];
      if (rawMediaUrls is List && rawMediaUrls.isNotEmpty) {
        print('[Post.fromJson] Using media_urls path (${rawMediaUrls.length} items)');
        // Создаем MediaObjects для изображений
        for (final url in rawMediaUrls) {
          if (url != null && url.toString().isNotEmpty) {
            mediaObjects.add(MediaObject(
              type: MediaType.photo,
              url: url.toString(),
            ));
          }
        }

        multipleImages = rawMediaUrls
            .where((e) => e != null)
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
        singleImage = multipleImages.isNotEmpty ? multipleImages.first : null;
      }

      // Если media_urls пустой или отсутствует, fallback на image_url
      if (multipleImages.isEmpty && mediaObjects.isEmpty) {
        print('[Post.fromJson] Fallback to image_url');
        final dynamic rawImageUrl = json['image_url'];
        if (rawImageUrl is List && rawImageUrl.isNotEmpty) {
          print('[Post.fromJson] Using image_url as list (${rawImageUrl.length} items)');
          for (final url in rawImageUrl) {
            if (url != null && url.toString().isNotEmpty) {
              mediaObjects.add(MediaObject(
                type: MediaType.photo,
                url: url.toString(),
              ));
            }
          }

          multipleImages = rawImageUrl
              .where((e) => e != null)
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
          singleImage = multipleImages.isNotEmpty ? multipleImages.first : null;
        } else if (rawImageUrl is String && rawImageUrl.isNotEmpty) {
          print('[Post.fromJson] Using image_url as string');
          mediaObjects.add(MediaObject(
            type: MediaType.photo,
            url: rawImageUrl,
          ));

          singleImage = rawImageUrl;
          multipleImages = [rawImageUrl];
        } else {
          print('[Post.fromJson] No image_url found or empty');
        }
      }

      // Генерируем общий список URL для совместимости
      if (mediaObjects.isNotEmpty) {
        multipleImages = mediaObjects.map((m) => m.url).toList();
        singleImage = multipleImages.isNotEmpty ? multipleImages.first : null;
      } else if (multipleImages.isEmpty) {
        // Если ничего не нашли, берем пустые значения
        multipleImages = [];
        singleImage = null;
      }
    }

    // DEBUG: Log final parsed result
    print('[Post.fromJson] Final result for post $postId: ${mediaObjects.length} media objects, ${multipleImages.length} images');

    // Parse views: support both v2 (views object) and v1 (flat fields)
    Map<String, String> viewsMap = {};

    if (json.containsKey('views') && json['views'] is Map) {
      // v2 API: parse all keys from views object (preserving order)
      final views = json['views'] as Map<String, dynamic>;
      for (final entry in views.entries) {
        if (entry.value is String) {
          viewsMap[entry.key] = entry.value as String;
        }
      }
    } else {
      // v1 API fallback: build views map from flat fields
      final summary = (json['summary'] as String?) ?? '';
      final fullText = (json['full_text'] as String?) ?? '';
      if (summary.isNotEmpty) viewsMap['summary'] = summary;
      if (fullText.isNotEmpty) viewsMap['full_text'] = fullText;
    }

    return Post(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      feedId: (json['feed_id'] as String?) ?? '',
      sources: (json['sources'] as List<dynamic>?)
              ?.map((sourceJson) => Source.fromJson(sourceJson as Map<String, dynamic>))
              .toList() ??
          [],
      views: viewsMap,
      imageUrl: singleImage,
      mediaUrls: multipleImages,
      mediaObjects: mediaObjects,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      seen: json['seen'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'feed_id': feedId,
      'sources': sources.map((source) => source.toJson()).toList(),
      'views': views,
      'media_urls': mediaUrls,
      'media_objects': mediaObjects.map((obj) => obj.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'seen': seen,
    };
  }
}

class Feed {
  final String id;
  final String name;
  final List<Post> posts;
  final DateTime createdAt;
  final bool? isCreatingFinished; // null = error, false = in progress, true = completed
  final FeedType type; // DIGEST or SINGLE_POST
  final List<String> tags; // Feed tags from API
  final int unreadCount; // Number of unread posts from /feeds
  final int postsCount; // Total number of posts from /feeds API
  final int rawFeedsCount; // Number of sources (Telegram/RSS) from API

  Feed({
    required this.id,
    required this.name,
    required this.posts,
    required this.createdAt,
    this.isCreatingFinished,
    this.type = FeedType.SINGLE_POST, // Default for backward compatibility
    this.tags = const [],
    this.unreadCount = 0,
    this.postsCount = 0,
    this.rawFeedsCount = 0,
  });

  factory Feed.fromJson(Map<String, dynamic> json) {
    // Parse type field: "DIGEST" or "SINGLE_POST"
    FeedType feedType = FeedType.SINGLE_POST;
    final typeStr = json['type'] as String?;
    if (typeStr == 'DIGEST') {
      feedType = FeedType.DIGEST;
    }

    return Feed(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      posts: (json['posts'] as List<dynamic>?)
          ?.map((postJson) => Post.fromJson(postJson as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      isCreatingFinished: json['is_creating_finished'] as bool?,
      type: feedType,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      unreadCount: (json['unread_count'] as int?) ?? 0,
      postsCount: (json['posts_count'] as int?) ?? 0,
      rawFeedsCount: (json['raw_feeds_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'posts': posts.map((post) => post.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'is_creating_finished': isCreatingFinished,
      'type': type.apiValue,
      'tags': tags,
      'unread_count': unreadCount,
      'posts_count': postsCount,
      'raw_feeds_count': rawFeedsCount,
    };
  }

  /// Create a copy of this Feed with updated fields
  Feed copyWith({
    String? id,
    String? name,
    List<Post>? posts,
    DateTime? createdAt,
    bool? isCreatingFinished,
    FeedType? type,
    List<String>? tags,
    int? unreadCount,
    int? postsCount,
    int? rawFeedsCount,
  }) {
    return Feed(
      id: id ?? this.id,
      name: name ?? this.name,
      posts: posts ?? this.posts,
      createdAt: createdAt ?? this.createdAt,
      isCreatingFinished: isCreatingFinished ?? this.isCreatingFinished,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      unreadCount: unreadCount ?? this.unreadCount,
      postsCount: postsCount ?? this.postsCount,
      rawFeedsCount: rawFeedsCount ?? this.rawFeedsCount,
    );
  }
}

class UserFeedResponse {
  final Feed feeds;

  UserFeedResponse({
    required this.feeds,
  });

  factory UserFeedResponse.fromJson(Map<String, dynamic> json) {
    return UserFeedResponse(
      feeds: Feed.fromJson((json['feeds'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feeds': feeds.toJson(),
    };
  }
}