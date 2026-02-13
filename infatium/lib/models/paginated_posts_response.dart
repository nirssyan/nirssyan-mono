import 'feed_models.dart';

/// Response model for paginated posts endpoint
/// GET /posts/feed/{feed_id}?cursor=&limit=20
class PaginatedPostsResponse {
  final List<Post> posts;
  final String? nextCursor;
  final bool hasMore;
  final int totalCount;

  PaginatedPostsResponse({
    required this.posts,
    this.nextCursor,
    required this.hasMore,
    required this.totalCount,
  });

  factory PaginatedPostsResponse.fromJson(Map<String, dynamic> json) {
    return PaginatedPostsResponse(
      posts: (json['posts'] as List<dynamic>?)
              ?.map((postJson) => Post.fromJson(postJson as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
      totalCount: json['total_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'posts': posts.map((post) => post.toJson()).toList(),
      'next_cursor': nextCursor,
      'has_more': hasMore,
      'total_count': totalCount,
    };
  }

  @override
  String toString() {
    return 'PaginatedPostsResponse(posts: ${posts.length}, nextCursor: $nextCursor, hasMore: $hasMore, totalCount: $totalCount)';
  }
}
