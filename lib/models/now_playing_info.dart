class NowPlayingInfo {
  const NowPlayingInfo({
    required this.title,
    required this.artist,
    this.positionSeconds,
    this.sourceApp,
    this.isPlaying = false,
  });

  final String title;
  final String artist;
  final int? positionSeconds;
  final String? sourceApp;
  final bool isPlaying;

  factory NowPlayingInfo.fromMap(Map<dynamic, dynamic> map) {
    String t = (map['title'] as String? ?? '').trim();
    String a = (map['artist'] as String? ?? '').trim();
    final source = (map['source'] as String?)?.trim();
    if (t.isEmpty) {
      t = (map['podcastTitle'] as String? ?? '').trim();
    }
    if (t.isEmpty) {
      t = (map['podcast'] as String? ?? '').trim();
    }
    if (t.isEmpty) {
      t = (map['albumTitle'] as String? ?? '').trim();
    }
    if (t.isEmpty && a.isNotEmpty) {
      t = a;
    }

    final pos = map['position'];
    int? positionSeconds;
    if (pos is int) {
      positionSeconds = pos;
    } else if (pos is num) {
      positionSeconds = pos.toInt();
    }

    return NowPlayingInfo(
      title: t,
      artist: a,
      positionSeconds: positionSeconds,
      sourceApp: source,
      isPlaying: map['isPlaying'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'NowPlayingInfo(title: $title, artist: $artist, position: $positionSeconds, source: $sourceApp, playing: $isPlaying)';

  NowPlayingInfo copyWith({
    String? title,
    String? artist,
    int? positionSeconds,
    String? sourceApp,
    bool? isPlaying,
  }) {
    return NowPlayingInfo(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      sourceApp: sourceApp ?? this.sourceApp,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}
