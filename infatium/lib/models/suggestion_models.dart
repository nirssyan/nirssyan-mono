/// Model for suggestion items (filters, views, sources)
class Suggestion {
  final String id;
  final Map<String, String> name;
  final String? sourceType; // 'TELEGRAM', 'RSS', etc. - only for sources

  const Suggestion({
    required this.id,
    required this.name,
    this.sourceType,
  });

  /// Get display name for the given locale code (e.g., 'en', 'ru')
  /// Falls back to English if locale not found
  String getDisplayName(String locale) {
    return name[locale] ?? name['en'] ?? '';
  }

  /// Get the source value (e.g., '@tass_agency') - stored in 'en' field
  String get value => name['en'] ?? '';

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    final nameData = json['name'] as Map<String, dynamic>;
    return Suggestion(
      id: json['id'] as String,
      name: nameData.map((key, value) => MapEntry(key, value as String)),
      sourceType: json['source_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (sourceType != null) 'source_type': sourceType,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Suggestion && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
