import 'package:drift/drift.dart';

import '../models/summary_style.dart';
import 'database.dart';

class SessionDao {
  SessionDao(this._db);

  final AppDatabase _db;

  Future<void> insertSession(ListeningSessionsCompanion entry) {
    return _db.into(_db.listeningSessions).insert(entry);
  }

  Future<bool> updateSession(ListeningSessionsCompanion entry) {
    return _db.update(_db.listeningSessions).replace(entry);
  }

  Future<int> deleteSession(String id) {
    return (_db.delete(_db.listeningSessions)
          ..where((t) => t.id.equals(id)))
        .go();
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
