import 'package:drift/drift.dart';

import '../models/summary_style.dart';
import 'database.dart';

class SessionDao {
  SessionDao(this._db);

  final AppDatabase _db;

  Future<void> insertSession(ListeningSessionsCompanion entry) {
    return _db.into(_db.listeningSessions).insert(entry);
  }

  /// Partial row update — only non-absent companion fields change.
  /// (Using `replace` would null out omitted columns and drop [endTimeSec], etc.)
  Future<void> updateSession(ListeningSessionsCompanion entry) {
    final id = entry.id;
    if (!id.present) {
      throw ArgumentError('updateSession requires companion.id');
    }
    return (_db.update(_db.listeningSessions)
          ..where((t) => t.id.equals(id.value)))
        .write(entry);
  }

  Future<int> deleteSession(String id) {
    return (_db.delete(_db.listeningSessions)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  /// New start time in seconds; clears summary output and re-queues pipeline.
  Future<void> requeueFromStartTime(String id, int startTimeSec) async {
    await (_db.update(_db.listeningSessions)..where((t) => t.id.equals(id)))
        .write(
      ListeningSessionsCompanion(
        startTimeSec: Value(startTimeSec),
        status: Value(SessionStatus.queued.name),
        bullet1: const Value(null),
        bullet2: const Value(null),
        bullet3: const Value(null),
        bullet4: const Value(null),
        bullet5: const Value(null),
        quote1: const Value(null),
        quote2: const Value(null),
        quote3: const Value(null),
        chaptersJson: const Value(null),
        errorMessage: const Value(null),
        transcriptSource: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// New start/end window; clears summary and re-queues (e.g. user-adjusted range).
  Future<void> requeueWithTimeRange(
    String id, {
    required int startTimeSec,
    int? endTimeSec,
    String? rangeLabel,
  }) async {
    await (_db.update(_db.listeningSessions)..where((t) => t.id.equals(id)))
        .write(
      ListeningSessionsCompanion(
        startTimeSec: Value(startTimeSec),
        endTimeSec: Value(endTimeSec),
        rangeLabel:
            rangeLabel != null ? Value(rangeLabel) : const Value.absent(),
        status: Value(SessionStatus.queued.name),
        bullet1: const Value(null),
        bullet2: const Value(null),
        bullet3: const Value(null),
        bullet4: const Value(null),
        bullet5: const Value(null),
        quote1: const Value(null),
        quote2: const Value(null),
        quote3: const Value(null),
        chaptersJson: const Value(null),
        errorMessage: const Value(null),
        transcriptSource: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> updateSessionTags(String id, String? tags) async {
    await (_db.update(_db.listeningSessions)..where((t) => t.id.equals(id)))
        .write(
      ListeningSessionsCompanion(
        id: Value(id),
        tags: Value(tags),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<int> deleteAllSessions() {
    return _db.delete(_db.listeningSessions).go();
  }

  Stream<List<ListeningSession>> watchAllSessions() {
    return (_db.select(_db.listeningSessions)
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Future<ListeningSession?> getSessionById(String id) {
    return (_db.select(_db.listeningSessions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<ListeningSession>> getQueuedSessions() {
    return (_db.select(_db.listeningSessions)
          ..where(
              (t) => t.status.equals(SessionStatus.queued.name)))
        .get();
  }

  Stream<List<ListeningSession>> watchSessionsByStatus(
      SessionStatus status) {
    return (_db.select(_db.listeningSessions)
          ..where((t) => t.status.equals(status.name))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }
}
