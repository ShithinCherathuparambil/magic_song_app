class SavedVoice {
  final String id;
  final String path;
  final String title;
  final String profile;
  final DateTime createdAt;

  const SavedVoice({
    required this.id,
    required this.path,
    required this.title,
    required this.profile,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'title': title,
    'profile': profile,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedVoice.fromJson(Map<String, dynamic> json) {
    return SavedVoice(
      id: json['id'] as String,
      path: json['path'] as String,
      title: json['title'] as String,
      profile: json['profile'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
