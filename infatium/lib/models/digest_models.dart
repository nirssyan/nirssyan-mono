/// Response model for POST /feeds/summarize_unseen/{feed_id}
/// Simplified: only contains id and markedAsSeenCount
/// Full post data is fetched via GET /posts/{id}
class DigestResponse {
  final String id;
  final int markedAsSeenCount;

  DigestResponse({
    required this.id,
    required this.markedAsSeenCount,
  });

  factory DigestResponse.fromJson(Map<String, dynamic> json) {
    return DigestResponse(
      id: (json['id'] as String?) ?? '',
      markedAsSeenCount: (json['marked_as_seen_count'] as int?) ?? 0,
    );
  }
}
