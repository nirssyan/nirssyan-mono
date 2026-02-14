class PromptExample {
  final String id;
  final String prompt;
  final List<String> tags;
  final DateTime createdAt;

  PromptExample({
    required this.id,
    required this.prompt,
    required this.tags,
    required this.createdAt,
  });

  factory PromptExample.fromJson(Map<String, dynamic> json) {
    return PromptExample(
      id: (json['id'] as String?) ?? '',
      prompt: (json['prompt'] as String?) ?? '',
      tags: ((json['tags'] as List<dynamic>?) ?? [])
          .map((tag) => tag.toString())
          .toList(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
