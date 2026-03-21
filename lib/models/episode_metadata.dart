class EpisodeMetadata {
  const EpisodeMetadata({
    required this.id,
    required this.title,
    required this.podcastName,
    this.imageUrl,
    this.durationSeconds,
    this.publishedAt,
    this.episodeUrl,
  });

  final String id;
  final String title;
  final String podcastName;
  final String? imageUrl;
  final int? durationSeconds;
  final DateTime? publishedAt;
  final String? episodeUrl;

  factory EpisodeMetadata.fromJson(Map<String, dynamic> json) {
    return EpisodeMetadata(
      id: json['id'] as String,
      title: json['title'] as String,
      podcastName: json['podcastName'] as String,
      imageUrl: json['imageUrl'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      episodeUrl: json['episodeUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'podcastName': podcastName,
        'imageUrl': imageUrl,
        'durationSeconds': durationSeconds,
        'publishedAt': publishedAt?.toIso8601String(),
        'episodeUrl': episodeUrl,
      };
}
