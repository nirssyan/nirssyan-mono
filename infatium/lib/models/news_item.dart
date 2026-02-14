import 'feed_builder_models.dart'; // For FeedType enum
import 'feed_models.dart';
import 'media_object.dart';

class NewsItem {
  final String feedId;
  final String title;
  final String subtitle;
  final String content;
  final String imageUrl;
  final List<String> mediaUrls; // Для обратной совместимости с UI
  final List<MediaObject> mediaObjects; // Новый контракт с метаданными
  final String source;
  final DateTime publishedAt;
  final String category;
  final String? id;
  final String? link;
  final Map<String, String> contentViews; // Dynamic content views from v2 API
  final List<Source> sources;
  final bool seen; // Статус просмотра новости пользователем
  final FeedType feedType; // Тип ленты: DIGEST или SINGLE_POST

  NewsItem({
    required this.feedId,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.imageUrl,
    this.mediaUrls = const [],
    this.mediaObjects = const [],
    required this.source,
    required this.publishedAt,
    required this.category,
    this.id,
    this.link,
    this.contentViews = const {},
    this.sources = const [],
    this.seen = false, // По умолчанию новость не просмотрена
    this.feedType = FeedType.SINGLE_POST, // По умолчанию обычная лента
  });
} 