import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class ListeningSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get sourceApp => text().nullable()();
  TextColumn get saveMethod => text()();
  IntColumn get startTimeSec => integer()();
  IntColumn get endTimeSec => integer().nullable()();
  TextColumn get rangeLabel => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('queued'))();
  TextColumn get summaryStyle => text().nullable()();
  TextColumn get bullet1 => text().nullable()();
  TextColumn get bullet2 => text().nullable()();
  TextColumn get bullet3 => text().nullable()();
  TextColumn get bullet4 => text().nullable()();
  TextColumn get bullet5 => text().nullable()();
  TextColumn get quote1 => text().nullable()();
  TextColumn get quote2 => text().nullable()();
  TextColumn get quote3 => text().nullable()();
  TextColumn get chaptersJson => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get episodeId => text().nullable()();
  TextColumn get episodeUrl => text().nullable()();
  /// Pasted open.spotify.com / podcasts.apple.com link (for “Open in …” buttons).
  TextColumn get sourceShareUrl => text().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  /// Transcription backend: `deepgram` | `taddy` (affects timestamp accuracy UI).
  TextColumn get transcriptSource => text().nullable()();
  /// Comma-separated labels, e.g. `work,ideas`.
  TextColumn get tags => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ListeningSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(listeningSessions, listeningSessions.artworkUrl);
          }
          if (from < 3) {
            await m.addColumn(
                listeningSessions, listeningSessions.transcriptSource);
            await m.addColumn(listeningSessions, listeningSessions.tags);
          }
          if (from < 4) {
            await m.addColumn(
                listeningSessions, listeningSessions.sourceShareUrl);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'podcast_safety_net',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}

AppDatabase? _appDatabaseSingleton;

/// Single SQLite connection for the whole app (Riverpod + [NotificationService]).
///
/// Opening [AppDatabase] twice on the same file causes Drift race warnings and
/// can corrupt or crash the app.
AppDatabase get appDatabaseSingleton {
  _appDatabaseSingleton ??= AppDatabase();
  return _appDatabaseSingleton!;
}
