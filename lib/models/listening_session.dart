import 'package:intl/intl.dart';

import 'summary_style.dart';

class ListeningSession {
  const ListeningSession({
    required this.id,
    required this.title,
    required this.artist,
    this.sourceApp,
    required this.saveMethod,
    required this.startTimeSec,
    this.endTimeSec,
    this.rangeLabel,
    this.status = SessionStatus.queued,
    this.summaryStyle,
    this.bullet1,
    this.bullet2,
    this.bullet3,
    this.bullet4,
    this.bullet5,
    this.quote1,
    this.quote2,
    this.quote3,
    this.chaptersJson,
    this.errorMessage,
    this.episodeId,
    this.episodeUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String artist;
  final String? sourceApp;
  final SaveMethod saveMethod;
  final int startTimeSec;
  final int? endTimeSec;
  final String? rangeLabel;
  final SessionStatus status;
  final SummaryStyle? summaryStyle;
  final String? bullet1;
  final String? bullet2;
  final String? bullet3;
  final String? bullet4;
  final String? bullet5;
  final String? quote1;
  final String? quote2;
  final String? quote3;
  final String? chaptersJson;
  final String? errorMessage;
  final String? episodeId;
  final String? episodeUrl;
  final int createdAt;
  final int updatedAt;

  // ── Computed getters ──────────────────────────────────────────────────

  String get durationLabel {
    if (endTimeSec != null) {
      final start = _formatTimestamp(startTimeSec);
      final end = _formatTimestamp(endTimeSec!);
      return '$start – $end';
    }
    return rangeLabel ?? 'Full Episode';
  }

  int get durationMinutes {
    if (endTimeSec == null) return 0;
    return ((endTimeSec! - startTimeSec) / 60).round();
  }

  bool get isComplete => status == SessionStatus.done && bullet1 != null;

  String get formattedDate {
    final date = DateTime.fromMillisecondsSinceEpoch(createdAt);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final created = DateTime(date.year, date.month, date.day);

    if (created == today) return 'Today';
    if (created == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM d').format(date);
  }

  List<String> get bullets => [bullet1, bullet2, bullet3, bullet4, bullet5]
      .whereType<String>()
      .toList();

  List<String> get quotes =>
      [quote1, quote2, quote3].whereType<String>().toList();

  // ── Serialization ─────────────────────────────────────────────────────

  ListeningSession copyWith({
    String? id,
    String? title,
    String? artist,
    String? sourceApp,
    SaveMethod? saveMethod,
    int? startTimeSec,
    int? endTimeSec,
    String? rangeLabel,
    SessionStatus? status,
    SummaryStyle? summaryStyle,
    String? bullet1,
    String? bullet2,
    String? bullet3,
    String? bullet4,
    String? bullet5,
    String? quote1,
    String? quote2,
    String? quote3,
    String? chaptersJson,
    String? errorMessage,
    String? episodeId,
    String? episodeUrl,
    int? createdAt,
    int? updatedAt,
  }) {
    return ListeningSession(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      sourceApp: sourceApp ?? this.sourceApp,
      saveMethod: saveMethod ?? this.saveMethod,
      startTimeSec: startTimeSec ?? this.startTimeSec,
      endTimeSec: endTimeSec ?? this.endTimeSec,
      rangeLabel: rangeLabel ?? this.rangeLabel,
      status: status ?? this.status,
      summaryStyle: summaryStyle ?? this.summaryStyle,
      bullet1: bullet1 ?? this.bullet1,
      bullet2: bullet2 ?? this.bullet2,
      bullet3: bullet3 ?? this.bullet3,
      bullet4: bullet4 ?? this.bullet4,
      bullet5: bullet5 ?? this.bullet5,
      quote1: quote1 ?? this.quote1,
      quote2: quote2 ?? this.quote2,
      quote3: quote3 ?? this.quote3,
      chaptersJson: chaptersJson ?? this.chaptersJson,
      errorMessage: errorMessage ?? this.errorMessage,
      episodeId: episodeId ?? this.episodeId,
      episodeUrl: episodeUrl ?? this.episodeUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'sourceApp': sourceApp,
        'saveMethod': saveMethod.toJson(),
        'startTimeSec': startTimeSec,
        'endTimeSec': endTimeSec,
        'rangeLabel': rangeLabel,
        'status': status.toJson(),
        'summaryStyle': summaryStyle?.toJson(),
        'bullet1': bullet1,
        'bullet2': bullet2,
        'bullet3': bullet3,
        'bullet4': bullet4,
        'bullet5': bullet5,
        'quote1': quote1,
        'quote2': quote2,
        'quote3': quote3,
        'chaptersJson': chaptersJson,
        'errorMessage': errorMessage,
        'episodeId': episodeId,
        'episodeUrl': episodeUrl,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory ListeningSession.fromJson(Map<String, dynamic> json) {
    return ListeningSession(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      sourceApp: json['sourceApp'] as String?,
      saveMethod: SaveMethod.fromJson(json['saveMethod'] as String),
      startTimeSec: json['startTimeSec'] as int,
      endTimeSec: json['endTimeSec'] as int?,
      rangeLabel: json['rangeLabel'] as String?,
      status: SessionStatus.fromJson(json['status'] as String),
      summaryStyle: SummaryStyle.fromJson(json['summaryStyle'] as String?),
      bullet1: json['bullet1'] as String?,
      bullet2: json['bullet2'] as String?,
      bullet3: json['bullet3'] as String?,
      bullet4: json['bullet4'] as String?,
      bullet5: json['bullet5'] as String?,
      quote1: json['quote1'] as String?,
      quote2: json['quote2'] as String?,
      quote3: json['quote3'] as String?,
      chaptersJson: json['chaptersJson'] as String?,
      errorMessage: json['errorMessage'] as String?,
      episodeId: json['episodeId'] as String?,
      episodeUrl: json['episodeUrl'] as String?,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
    );
  }

  static String _formatTimestamp(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
