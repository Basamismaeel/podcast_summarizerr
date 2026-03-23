import 'package:shared_preferences/shared_preferences.dart';

import 'app_badge_service.dart';

/// Tracks lifetime stats for smart empty states, first-summary confetti, etc.
class MomentsStatsService {
  MomentsStatsService._();

  static const _kMomentsSaved = 'total_moments_saved';
  static const _kSummariesDone = 'total_summaries_done';
  static const _kFirstSummaryDone = 'first_summary_done';
  static const _kRecentManual = 'recent_manual_podcasts'; // comma-separated titles
  static const _kTypewriterDonePrefix = 'summary_typewriter_done_';

  static Future<int> getTotalMomentsSaved() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kMomentsSaved) ?? 0;
  }

  static Future<int> getTotalSummariesDone() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kSummariesDone) ?? 0;
  }

  static Future<bool> isFirstSummaryDone() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kFirstSummaryDone) ?? false;
  }

  static Future<void> markFirstSummaryDone() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kFirstSummaryDone, true);
  }

  /// After the first viewing, summary bullets show instantly (no typewriter).
  static Future<bool> hasSummaryTypewriterPlayed(String sessionId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('$_kTypewriterDonePrefix$sessionId') ?? false;
  }

  static Future<void> markSummaryTypewriterPlayed(String sessionId) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('$_kTypewriterDonePrefix$sessionId', true);
  }

  static Future<void> incrementMomentsSaved() async {
    final p = await SharedPreferences.getInstance();
    final n = (p.getInt(_kMomentsSaved) ?? 0) + 1;
    await p.setInt(_kMomentsSaved, n);
  }

  static Future<void> incrementSummariesDone() async {
    final p = await SharedPreferences.getInstance();
    final n = (p.getInt(_kSummariesDone) ?? 0) + 1;
    await p.setInt(_kSummariesDone, n);
  }

  /// Recent podcast/show names from manual entry (most recent first).
  static Future<List<String>> getRecentManualPodcasts() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kRecentManual) ?? '';
    if (raw.isEmpty) return [];
    return raw
        .split('\u001e')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static Future<void> recordManualPodcast(String artist) async {
    final name = artist.trim();
    if (name.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    var list = await getRecentManualPodcasts();
    list = [name, ...list.where((e) => e.toLowerCase() != name.toLowerCase())];
    if (list.length > 8) list = list.sublist(0, 8);
    await p.setString(_kRecentManual, list.join('\u001e'));
  }

  /// Recompute app icon badge from sessions (queued + summarizing).
  static Future<void> syncBadgeFromSessionCounts({
    required int queuedOrSummarizingCount,
  }) async {
    await AppBadgeService.updateQueueCount(queuedOrSummarizingCount);
  }
}
