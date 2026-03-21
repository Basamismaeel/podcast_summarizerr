import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/session_dao.dart';
import '../models/summary_style.dart';
import '../services/cloud_pipeline_service.dart';

const _uuid = Uuid();

// ═══════════════════════════════════════════════════════════════════════════
// CORE PROVIDERS (unchanged API surface – existing consumers still work)
// ═══════════════════════════════════════════════════════════════════════════

final databaseProvider = Provider<AppDatabase>((ref) {
  return appDatabaseSingleton;
});

final sessionDaoProvider = Provider<SessionDao>((ref) {
  return SessionDao(ref.watch(databaseProvider));
});

final allSessionsProvider =
    StreamProvider<List<ListeningSession>>((ref) {
  return ref.watch(sessionDaoProvider).watchAllSessions();
});

final sessionByIdProvider =
    FutureProvider.family<ListeningSession?, String>((ref, id) {
  return ref.watch(sessionDaoProvider).getSessionById(id);
});

final sessionActionsProvider = Provider<SessionActions>((ref) {
  final dao = ref.watch(sessionDaoProvider);
  return SessionActions(
    dao: dao,
    pipeline: CloudPipelineService(dao: dao),
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// SUMMARIZATION NOTIFIER
// ═══════════════════════════════════════════════════════════════════════════

/// Tracks which sessions are currently being summarized in this app instance.
final summarizeSessionProvider =
    StateNotifierProvider<SummarizeSessionNotifier, Set<String>>((ref) {
  return SummarizeSessionNotifier(
    dao: ref.watch(sessionDaoProvider),
    pipeline: CloudPipelineService(dao: ref.watch(sessionDaoProvider)),
  );
});

class SummarizeSessionNotifier extends StateNotifier<Set<String>> {
  SummarizeSessionNotifier({required this.dao, required this.pipeline})
      : super({});

  final SessionDao dao;
  final CloudPipelineService pipeline;

  bool isSummarizing(String sessionId) => state.contains(sessionId);

  /// Kick off summarization for a session.
  Future<void> summarize(String sessionId, {SummaryStyle? style}) async {
    if (state.contains(sessionId)) return; // already running

    state = {...state, sessionId};
    try {
      await pipeline.processSession(sessionId, style: style);
    } catch (e) {
      debugPrint('[SummarizeNotifier] Unexpected error: $e');
    } finally {
      state = {...state}..remove(sessionId);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STUCK-SESSION WATCHER
// ═══════════════════════════════════════════════════════════════════════════

/// Polls every 30 s for sessions stuck in "summarizing" > 2 min and retries.
final stuckSessionWatcherProvider = Provider<StuckSessionWatcher>((ref) {
  final watcher = StuckSessionWatcher(
    dao: ref.watch(sessionDaoProvider),
    pipeline: CloudPipelineService(dao: ref.watch(sessionDaoProvider)),
  );
  ref.onDispose(watcher.stop);
  return watcher;
});

class StuckSessionWatcher {
  StuckSessionWatcher({required this.dao, required this.pipeline});

  final SessionDao dao;
  final CloudPipelineService pipeline;
  Timer? _timer;
  final Set<String> _retrying = {};

  static const _pollInterval = Duration(seconds: 30);
  static const _stuckThreshold = Duration(minutes: 2);

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _checkStuck());
    // Also run immediately.
    _checkStuck();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkStuck() async {
    try {
      final summarizing =
          await dao.watchSessionsByStatus(SessionStatus.summarizing).first;

      final now = DateTime.now().millisecondsSinceEpoch;
      for (final s in summarizing) {
        final age = Duration(milliseconds: now - s.updatedAt);
        if (age > _stuckThreshold && !_retrying.contains(s.id)) {
          debugPrint('[StuckWatcher] Retrying stuck session ${s.id} '
              '(age: ${age.inSeconds}s)');
          _retrying.add(s.id);
          unawaited(
            pipeline.processSession(s.id).whenComplete(
                  () => _retrying.remove(s.id),
                ),
          );
        }
      }
    } catch (e) {
      debugPrint('[StuckWatcher] Error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SESSION ACTIONS (extended with summarize trigger)
// ═══════════════════════════════════════════════════════════════════════════

class SessionActions {
  SessionActions({required this.dao, required this.pipeline});

  final SessionDao dao;
  final CloudPipelineService pipeline;

  Future<String> createSession({
    required String title,
    required String artist,
    required SaveMethod saveMethod,
    required int startTimeSec,
    int? endTimeSec,
    String? rangeLabel,
    String? sourceApp,
    String? artworkUrl,
    SummaryStyle? summaryStyle,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await dao.insertSession(
      ListeningSessionsCompanion.insert(
        id: id,
        title: title,
        artist: artist,
        sourceApp: Value(sourceApp),
        artworkUrl: Value(artworkUrl),
        saveMethod: saveMethod.toJson(),
        startTimeSec: startTimeSec,
        endTimeSec: Value(endTimeSec),
        rangeLabel: Value(rangeLabel),
        summaryStyle: Value(summaryStyle?.toJson()),
        createdAt: now,
        updatedAt: now,
      ),
    );

    return id;
  }

  /// Create a session and immediately kick off the summarization pipeline.
  /// [episodeHint] carries platform-specific IDs for exact episode lookup
  /// (e.g. itunesEpisodeId, itunesPodcastId, spotifyEpisodeId).
  Future<String> createAndSummarize({
    required String title,
    required String artist,
    required SaveMethod saveMethod,
    required int startTimeSec,
    int? endTimeSec,
    String? rangeLabel,
    String? sourceApp,
    String? artworkUrl,
    SummaryStyle? summaryStyle,
    Map<String, String>? episodeHint,
  }) async {
    final id = await createSession(
      title: title,
      artist: artist,
      saveMethod: saveMethod,
      startTimeSec: startTimeSec,
      endTimeSec: endTimeSec,
      rangeLabel: rangeLabel,
      sourceApp: sourceApp,
      artworkUrl: artworkUrl,
      summaryStyle: summaryStyle,
    );
    unawaited(pipeline.processSession(id, style: summaryStyle, episodeHint: episodeHint));
    return id;
  }

  Future<void> deleteSession(String id) => dao.deleteSession(id);

  /// Manually retry a failed session.
  Future<void> retrySummary(String sessionId, {SummaryStyle? style}) {
    return pipeline.processSession(sessionId, style: style);
  }
}
