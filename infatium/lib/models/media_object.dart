/// Типы медиа-контента
enum MediaType {
  photo,
  video,
  animation,
  document,
  unknown;

  static MediaType fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'photo':
        return MediaType.photo;
      case 'video':
        return MediaType.video;
      case 'animation':
        return MediaType.animation;
      case 'document':
        return MediaType.document;
      default:
        return MediaType.unknown;
    }
  }

  String toApiString() {
    switch (this) {
      case MediaType.photo:
        return 'photo';
      case MediaType.video:
        return 'video';
      case MediaType.animation:
        return 'animation';
      case MediaType.document:
        return 'document';
      case MediaType.unknown:
        return 'unknown';
    }
  }
}

/// Модель медиа-объекта с метаданными (новый API контракт)
class MediaObject {
  final MediaType type;
  final String url;
  final String? previewUrl;
  final String? mimeType;
  final int? width;
  final int? height;
  final int? duration; // Для видео - длительность в секундах
  final String? fileName;

  MediaObject({
    required this.type,
    required this.url,
    this.previewUrl,
    this.mimeType,
    this.width,
    this.height,
    this.duration,
    this.fileName,
  });

  /// Фабрика для создания из JSON с детальным логированием
  factory MediaObject.fromJson(Map<String, dynamic> json) {

    final typeStr = json['type'] as String?;
    final type = MediaType.fromString(typeStr);
    final url = json['url'] as String? ?? '';
    final previewUrl = json['preview_url'] as String?;
    final mimeType = json['mime_type'] as String?;
    final width = json['width'] as int?;
    final height = json['height'] as int?;
    // Duration может приходить как int или double из API
    final dynamic rawDuration = json['duration'];
    final int? duration = rawDuration != null
        ? (rawDuration is int ? rawDuration : (rawDuration as double).round())
        : null;
    final fileName = json['file_name'] as String?;

    return MediaObject(
      type: type,
      url: url,
      previewUrl: previewUrl,
      mimeType: mimeType,
      width: width,
      height: height,
      duration: duration,
      fileName: fileName,
    );
  }

  /// Конвертация в JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.toApiString(),
      'url': url,
      if (previewUrl != null) 'preview_url': previewUrl,
      if (mimeType != null) 'mime_type': mimeType,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
      if (fileName != null) 'file_name': fileName,
    };
  }

  // Геттеры для проверки типа медиа
  bool get isPhoto => type == MediaType.photo;
  bool get isVideo => type == MediaType.video;
  bool get isAnimation => type == MediaType.animation;
  bool get isDocument => type == MediaType.document;

  /// Получить превью URL (для видео - preview_url, для фото - сам url)
  String get effectivePreviewUrl => previewUrl ?? url;

  /// Получить текст для отображения длительности (например, "1:23")
  String? get formattedDuration {
    if (duration == null) return null;
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'MediaObject(type: $type, url: $url, preview: $previewUrl, ${width}x$height, ${duration}s)';
  }
}
