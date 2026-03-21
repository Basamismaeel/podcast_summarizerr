import 'summary_style.dart';

/// A single word with start/end timestamps from transcription.
class WordTimestamp {
  const WordTimestamp({
    required this.word,
    required this.startSec,
    required this.endSec,
  });

  final String word;
  final double startSec;
  final double endSec;

  factory WordTimestamp.fromJson(Map<String, dynamic> json) => WordTimestamp(
        word: json['word'] as String? ?? '',
        startSec: (json['start'] as num?)?.toDouble() ?? 0,
        endSec: (json['end'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'start': startSec,
        'end': endSec,
      };
}

/// Result of a transcription request (Deepgram, Taddy, or cache).
class TranscriptionResult {
  const TranscriptionResult({
    required this.transcript,
    required this.wordTimestamps,
    required this.source,
  });

  final String transcript;
  final List<WordTimestamp> wordTimestamps;

  /// 'deepgram' | 'taddy' | 'cache'
  final String source;

  bool get hasWordTimestamps => wordTimestamps.isNotEmpty;

  /// Extract transcript text within a time range using word timestamps.
  String sliceByTimestamp(int startSec, int endSec) {
    if (wordTimestamps.isEmpty) {
      return _estimateSliceByCharPosition(startSec, endSec);
    }
    final words = wordTimestamps
        .where((w) => w.startSec >= startSec && w.endSec <= endSec)
        .map((w) => w.word)
        .toList();
    return words.join(' ');
  }

  /// Rough character-position estimate when word timestamps are unavailable.
  String _estimateSliceByCharPosition(int startSec, int endSec) {
    if (transcript.isEmpty) return '';
    const wordsPerSec = 2.5;
    final startWord = (startSec * wordsPerSec).round();
    final endWord = (endSec * wordsPerSec).round();
    final words = transcript.split(RegExp(r'\s+'));
    final clampedStart = startWord.clamp(0, words.length);
    final clampedEnd = endWord.clamp(clampedStart, words.length);
    return words.sublist(clampedStart, clampedEnd).join(' ');
  }

  Map<String, dynamic> toJson() => {
        'transcript': transcript,
        'wordTimestamps': wordTimestamps.map((w) => w.toJson()).toList(),
        'source': source,
      };

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    final rawTimestamps = json['wordTimestamps'] as List<dynamic>?;
    return TranscriptionResult(
      transcript: json['transcript'] as String? ?? '',
      wordTimestamps: rawTimestamps
              ?.map((e) =>
                  WordTimestamp.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      source: json['source'] as String? ?? 'cache',
    );
  }
}

/// Parsed AI summary output.
class ParsedSummary {
  const ParsedSummary({
    required this.bullets,
    required this.quotes,
    this.chapters,
    required this.style,
  });

  final List<String> bullets;
  final List<String> quotes;
  final List<ChapterInfo>? chapters;
  final SummaryStyle style;
}

/// A detected chapter in the transcript.
class ChapterInfo {
  const ChapterInfo({
    required this.title,
    required this.approximateTime,
    required this.summary,
  });

  final String title;
  final String approximateTime;
  final String summary;

  Map<String, dynamic> toJson() => {
        'title': title,
        'approximateTime': approximateTime,
        'summary': summary,
      };

  factory ChapterInfo.fromJson(Map<String, dynamic> json) => ChapterInfo(
        title: json['title'] as String? ?? '',
        approximateTime: json['approximateTime'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
      );
}

/// Typed exception for pipeline failures with user-facing messages.
class PipelineException implements Exception {
  const PipelineException(this.userMessage, {this.retryable = false});

  final String userMessage;
  final bool retryable;

  @override
  String toString() => 'PipelineException: $userMessage';
}
