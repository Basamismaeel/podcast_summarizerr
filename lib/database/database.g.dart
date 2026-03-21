// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ListeningSessionsTable extends ListeningSessions
    with TableInfo<$ListeningSessionsTable, ListeningSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListeningSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceAppMeta = const VerificationMeta(
    'sourceApp',
  );
  @override
  late final GeneratedColumn<String> sourceApp = GeneratedColumn<String>(
    'source_app',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _saveMethodMeta = const VerificationMeta(
    'saveMethod',
  );
  @override
  late final GeneratedColumn<String> saveMethod = GeneratedColumn<String>(
    'save_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeSecMeta = const VerificationMeta(
    'startTimeSec',
  );
  @override
  late final GeneratedColumn<int> startTimeSec = GeneratedColumn<int>(
    'start_time_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeSecMeta = const VerificationMeta(
    'endTimeSec',
  );
  @override
  late final GeneratedColumn<int> endTimeSec = GeneratedColumn<int>(
    'end_time_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rangeLabelMeta = const VerificationMeta(
    'rangeLabel',
  );
  @override
  late final GeneratedColumn<String> rangeLabel = GeneratedColumn<String>(
    'range_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _summaryStyleMeta = const VerificationMeta(
    'summaryStyle',
  );
  @override
  late final GeneratedColumn<String> summaryStyle = GeneratedColumn<String>(
    'summary_style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bullet1Meta = const VerificationMeta(
    'bullet1',
  );
  @override
  late final GeneratedColumn<String> bullet1 = GeneratedColumn<String>(
    'bullet1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bullet2Meta = const VerificationMeta(
    'bullet2',
  );
  @override
  late final GeneratedColumn<String> bullet2 = GeneratedColumn<String>(
    'bullet2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bullet3Meta = const VerificationMeta(
    'bullet3',
  );
  @override
  late final GeneratedColumn<String> bullet3 = GeneratedColumn<String>(
    'bullet3',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bullet4Meta = const VerificationMeta(
    'bullet4',
  );
  @override
  late final GeneratedColumn<String> bullet4 = GeneratedColumn<String>(
    'bullet4',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bullet5Meta = const VerificationMeta(
    'bullet5',
  );
  @override
  late final GeneratedColumn<String> bullet5 = GeneratedColumn<String>(
    'bullet5',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quote1Meta = const VerificationMeta('quote1');
  @override
  late final GeneratedColumn<String> quote1 = GeneratedColumn<String>(
    'quote1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quote2Meta = const VerificationMeta('quote2');
  @override
  late final GeneratedColumn<String> quote2 = GeneratedColumn<String>(
    'quote2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quote3Meta = const VerificationMeta('quote3');
  @override
  late final GeneratedColumn<String> quote3 = GeneratedColumn<String>(
    'quote3',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chaptersJsonMeta = const VerificationMeta(
    'chaptersJson',
  );
  @override
  late final GeneratedColumn<String> chaptersJson = GeneratedColumn<String>(
    'chapters_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<String> episodeId = GeneratedColumn<String>(
    'episode_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeUrlMeta = const VerificationMeta(
    'episodeUrl',
  );
  @override
  late final GeneratedColumn<String> episodeUrl = GeneratedColumn<String>(
    'episode_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    artist,
    sourceApp,
    saveMethod,
    startTimeSec,
    endTimeSec,
    rangeLabel,
    status,
    summaryStyle,
    bullet1,
    bullet2,
    bullet3,
    bullet4,
    bullet5,
    quote1,
    quote2,
    quote3,
    chaptersJson,
    errorMessage,
    episodeId,
    episodeUrl,
    artworkUrl,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'listening_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListeningSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('source_app')) {
      context.handle(
        _sourceAppMeta,
        sourceApp.isAcceptableOrUnknown(data['source_app']!, _sourceAppMeta),
      );
    }
    if (data.containsKey('save_method')) {
      context.handle(
        _saveMethodMeta,
        saveMethod.isAcceptableOrUnknown(data['save_method']!, _saveMethodMeta),
      );
    } else if (isInserting) {
      context.missing(_saveMethodMeta);
    }
    if (data.containsKey('start_time_sec')) {
      context.handle(
        _startTimeSecMeta,
        startTimeSec.isAcceptableOrUnknown(
          data['start_time_sec']!,
          _startTimeSecMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startTimeSecMeta);
    }
    if (data.containsKey('end_time_sec')) {
      context.handle(
        _endTimeSecMeta,
        endTimeSec.isAcceptableOrUnknown(
          data['end_time_sec']!,
          _endTimeSecMeta,
        ),
      );
    }
    if (data.containsKey('range_label')) {
      context.handle(
        _rangeLabelMeta,
        rangeLabel.isAcceptableOrUnknown(data['range_label']!, _rangeLabelMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('summary_style')) {
      context.handle(
        _summaryStyleMeta,
        summaryStyle.isAcceptableOrUnknown(
          data['summary_style']!,
          _summaryStyleMeta,
        ),
      );
    }
    if (data.containsKey('bullet1')) {
      context.handle(
        _bullet1Meta,
        bullet1.isAcceptableOrUnknown(data['bullet1']!, _bullet1Meta),
      );
    }
    if (data.containsKey('bullet2')) {
      context.handle(
        _bullet2Meta,
        bullet2.isAcceptableOrUnknown(data['bullet2']!, _bullet2Meta),
      );
    }
    if (data.containsKey('bullet3')) {
      context.handle(
        _bullet3Meta,
        bullet3.isAcceptableOrUnknown(data['bullet3']!, _bullet3Meta),
      );
    }
    if (data.containsKey('bullet4')) {
      context.handle(
        _bullet4Meta,
        bullet4.isAcceptableOrUnknown(data['bullet4']!, _bullet4Meta),
      );
    }
    if (data.containsKey('bullet5')) {
      context.handle(
        _bullet5Meta,
        bullet5.isAcceptableOrUnknown(data['bullet5']!, _bullet5Meta),
      );
    }
    if (data.containsKey('quote1')) {
      context.handle(
        _quote1Meta,
        quote1.isAcceptableOrUnknown(data['quote1']!, _quote1Meta),
      );
    }
    if (data.containsKey('quote2')) {
      context.handle(
        _quote2Meta,
        quote2.isAcceptableOrUnknown(data['quote2']!, _quote2Meta),
      );
    }
    if (data.containsKey('quote3')) {
      context.handle(
        _quote3Meta,
        quote3.isAcceptableOrUnknown(data['quote3']!, _quote3Meta),
      );
    }
    if (data.containsKey('chapters_json')) {
      context.handle(
        _chaptersJsonMeta,
        chaptersJson.isAcceptableOrUnknown(
          data['chapters_json']!,
          _chaptersJsonMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    if (data.containsKey('episode_url')) {
      context.handle(
        _episodeUrlMeta,
        episodeUrl.isAcceptableOrUnknown(data['episode_url']!, _episodeUrlMeta),
      );
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ListeningSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListeningSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      sourceApp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_app'],
      ),
      saveMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}save_method'],
      )!,
      startTimeSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_time_sec'],
      )!,
      endTimeSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_time_sec'],
      ),
      rangeLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}range_label'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      summaryStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_style'],
      ),
      bullet1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bullet1'],
      ),
      bullet2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bullet2'],
      ),
      bullet3: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bullet3'],
      ),
      bullet4: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bullet4'],
      ),
      bullet5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bullet5'],
      ),
      quote1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote1'],
      ),
      quote2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote2'],
      ),
      quote3: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote3'],
      ),
      chaptersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapters_json'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_id'],
      ),
      episodeUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_url'],
      ),
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ListeningSessionsTable createAlias(String alias) {
    return $ListeningSessionsTable(attachedDatabase, alias);
  }
}

class ListeningSession extends DataClass
    implements Insertable<ListeningSession> {
  final String id;
  final String title;
  final String artist;
  final String? sourceApp;
  final String saveMethod;
  final int startTimeSec;
  final int? endTimeSec;
  final String? rangeLabel;
  final String status;
  final String? summaryStyle;
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
  final String? artworkUrl;
  final int createdAt;
  final int updatedAt;
  const ListeningSession({
    required this.id,
    required this.title,
    required this.artist,
    this.sourceApp,
    required this.saveMethod,
    required this.startTimeSec,
    this.endTimeSec,
    this.rangeLabel,
    required this.status,
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
    this.artworkUrl,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    if (!nullToAbsent || sourceApp != null) {
      map['source_app'] = Variable<String>(sourceApp);
    }
    map['save_method'] = Variable<String>(saveMethod);
    map['start_time_sec'] = Variable<int>(startTimeSec);
    if (!nullToAbsent || endTimeSec != null) {
      map['end_time_sec'] = Variable<int>(endTimeSec);
    }
    if (!nullToAbsent || rangeLabel != null) {
      map['range_label'] = Variable<String>(rangeLabel);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || summaryStyle != null) {
      map['summary_style'] = Variable<String>(summaryStyle);
    }
    if (!nullToAbsent || bullet1 != null) {
      map['bullet1'] = Variable<String>(bullet1);
    }
    if (!nullToAbsent || bullet2 != null) {
      map['bullet2'] = Variable<String>(bullet2);
    }
    if (!nullToAbsent || bullet3 != null) {
      map['bullet3'] = Variable<String>(bullet3);
    }
    if (!nullToAbsent || bullet4 != null) {
      map['bullet4'] = Variable<String>(bullet4);
    }
    if (!nullToAbsent || bullet5 != null) {
      map['bullet5'] = Variable<String>(bullet5);
    }
    if (!nullToAbsent || quote1 != null) {
      map['quote1'] = Variable<String>(quote1);
    }
    if (!nullToAbsent || quote2 != null) {
      map['quote2'] = Variable<String>(quote2);
    }
    if (!nullToAbsent || quote3 != null) {
      map['quote3'] = Variable<String>(quote3);
    }
    if (!nullToAbsent || chaptersJson != null) {
      map['chapters_json'] = Variable<String>(chaptersJson);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || episodeId != null) {
      map['episode_id'] = Variable<String>(episodeId);
    }
    if (!nullToAbsent || episodeUrl != null) {
      map['episode_url'] = Variable<String>(episodeUrl);
    }
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ListeningSessionsCompanion toCompanion(bool nullToAbsent) {
    return ListeningSessionsCompanion(
      id: Value(id),
      title: Value(title),
      artist: Value(artist),
      sourceApp: sourceApp == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceApp),
      saveMethod: Value(saveMethod),
      startTimeSec: Value(startTimeSec),
      endTimeSec: endTimeSec == null && nullToAbsent
          ? const Value.absent()
          : Value(endTimeSec),
      rangeLabel: rangeLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(rangeLabel),
      status: Value(status),
      summaryStyle: summaryStyle == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryStyle),
      bullet1: bullet1 == null && nullToAbsent
          ? const Value.absent()
          : Value(bullet1),
      bullet2: bullet2 == null && nullToAbsent
          ? const Value.absent()
          : Value(bullet2),
      bullet3: bullet3 == null && nullToAbsent
          ? const Value.absent()
          : Value(bullet3),
      bullet4: bullet4 == null && nullToAbsent
          ? const Value.absent()
          : Value(bullet4),
      bullet5: bullet5 == null && nullToAbsent
          ? const Value.absent()
          : Value(bullet5),
      quote1: quote1 == null && nullToAbsent
          ? const Value.absent()
          : Value(quote1),
      quote2: quote2 == null && nullToAbsent
          ? const Value.absent()
          : Value(quote2),
      quote3: quote3 == null && nullToAbsent
          ? const Value.absent()
          : Value(quote3),
      chaptersJson: chaptersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(chaptersJson),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      episodeId: episodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeId),
      episodeUrl: episodeUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeUrl),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ListeningSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListeningSession(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      sourceApp: serializer.fromJson<String?>(json['sourceApp']),
      saveMethod: serializer.fromJson<String>(json['saveMethod']),
      startTimeSec: serializer.fromJson<int>(json['startTimeSec']),
      endTimeSec: serializer.fromJson<int?>(json['endTimeSec']),
      rangeLabel: serializer.fromJson<String?>(json['rangeLabel']),
      status: serializer.fromJson<String>(json['status']),
      summaryStyle: serializer.fromJson<String?>(json['summaryStyle']),
      bullet1: serializer.fromJson<String?>(json['bullet1']),
      bullet2: serializer.fromJson<String?>(json['bullet2']),
      bullet3: serializer.fromJson<String?>(json['bullet3']),
      bullet4: serializer.fromJson<String?>(json['bullet4']),
      bullet5: serializer.fromJson<String?>(json['bullet5']),
      quote1: serializer.fromJson<String?>(json['quote1']),
      quote2: serializer.fromJson<String?>(json['quote2']),
      quote3: serializer.fromJson<String?>(json['quote3']),
      chaptersJson: serializer.fromJson<String?>(json['chaptersJson']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      episodeId: serializer.fromJson<String?>(json['episodeId']),
      episodeUrl: serializer.fromJson<String?>(json['episodeUrl']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'sourceApp': serializer.toJson<String?>(sourceApp),
      'saveMethod': serializer.toJson<String>(saveMethod),
      'startTimeSec': serializer.toJson<int>(startTimeSec),
      'endTimeSec': serializer.toJson<int?>(endTimeSec),
      'rangeLabel': serializer.toJson<String?>(rangeLabel),
      'status': serializer.toJson<String>(status),
      'summaryStyle': serializer.toJson<String?>(summaryStyle),
      'bullet1': serializer.toJson<String?>(bullet1),
      'bullet2': serializer.toJson<String?>(bullet2),
      'bullet3': serializer.toJson<String?>(bullet3),
      'bullet4': serializer.toJson<String?>(bullet4),
      'bullet5': serializer.toJson<String?>(bullet5),
      'quote1': serializer.toJson<String?>(quote1),
      'quote2': serializer.toJson<String?>(quote2),
      'quote3': serializer.toJson<String?>(quote3),
      'chaptersJson': serializer.toJson<String?>(chaptersJson),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'episodeId': serializer.toJson<String?>(episodeId),
      'episodeUrl': serializer.toJson<String?>(episodeUrl),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ListeningSession copyWith({
    String? id,
    String? title,
    String? artist,
    Value<String?> sourceApp = const Value.absent(),
    String? saveMethod,
    int? startTimeSec,
    Value<int?> endTimeSec = const Value.absent(),
    Value<String?> rangeLabel = const Value.absent(),
    String? status,
    Value<String?> summaryStyle = const Value.absent(),
    Value<String?> bullet1 = const Value.absent(),
    Value<String?> bullet2 = const Value.absent(),
    Value<String?> bullet3 = const Value.absent(),
    Value<String?> bullet4 = const Value.absent(),
    Value<String?> bullet5 = const Value.absent(),
    Value<String?> quote1 = const Value.absent(),
    Value<String?> quote2 = const Value.absent(),
    Value<String?> quote3 = const Value.absent(),
    Value<String?> chaptersJson = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    Value<String?> episodeId = const Value.absent(),
    Value<String?> episodeUrl = const Value.absent(),
    Value<String?> artworkUrl = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => ListeningSession(
    id: id ?? this.id,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    sourceApp: sourceApp.present ? sourceApp.value : this.sourceApp,
    saveMethod: saveMethod ?? this.saveMethod,
    startTimeSec: startTimeSec ?? this.startTimeSec,
    endTimeSec: endTimeSec.present ? endTimeSec.value : this.endTimeSec,
    rangeLabel: rangeLabel.present ? rangeLabel.value : this.rangeLabel,
    status: status ?? this.status,
    summaryStyle: summaryStyle.present ? summaryStyle.value : this.summaryStyle,
    bullet1: bullet1.present ? bullet1.value : this.bullet1,
    bullet2: bullet2.present ? bullet2.value : this.bullet2,
    bullet3: bullet3.present ? bullet3.value : this.bullet3,
    bullet4: bullet4.present ? bullet4.value : this.bullet4,
    bullet5: bullet5.present ? bullet5.value : this.bullet5,
    quote1: quote1.present ? quote1.value : this.quote1,
    quote2: quote2.present ? quote2.value : this.quote2,
    quote3: quote3.present ? quote3.value : this.quote3,
    chaptersJson: chaptersJson.present ? chaptersJson.value : this.chaptersJson,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    episodeId: episodeId.present ? episodeId.value : this.episodeId,
    episodeUrl: episodeUrl.present ? episodeUrl.value : this.episodeUrl,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ListeningSession copyWithCompanion(ListeningSessionsCompanion data) {
    return ListeningSession(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      sourceApp: data.sourceApp.present ? data.sourceApp.value : this.sourceApp,
      saveMethod: data.saveMethod.present
          ? data.saveMethod.value
          : this.saveMethod,
      startTimeSec: data.startTimeSec.present
          ? data.startTimeSec.value
          : this.startTimeSec,
      endTimeSec: data.endTimeSec.present
          ? data.endTimeSec.value
          : this.endTimeSec,
      rangeLabel: data.rangeLabel.present
          ? data.rangeLabel.value
          : this.rangeLabel,
      status: data.status.present ? data.status.value : this.status,
      summaryStyle: data.summaryStyle.present
          ? data.summaryStyle.value
          : this.summaryStyle,
      bullet1: data.bullet1.present ? data.bullet1.value : this.bullet1,
      bullet2: data.bullet2.present ? data.bullet2.value : this.bullet2,
      bullet3: data.bullet3.present ? data.bullet3.value : this.bullet3,
      bullet4: data.bullet4.present ? data.bullet4.value : this.bullet4,
      bullet5: data.bullet5.present ? data.bullet5.value : this.bullet5,
      quote1: data.quote1.present ? data.quote1.value : this.quote1,
      quote2: data.quote2.present ? data.quote2.value : this.quote2,
      quote3: data.quote3.present ? data.quote3.value : this.quote3,
      chaptersJson: data.chaptersJson.present
          ? data.chaptersJson.value
          : this.chaptersJson,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      episodeUrl: data.episodeUrl.present
          ? data.episodeUrl.value
          : this.episodeUrl,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListeningSession(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('saveMethod: $saveMethod, ')
          ..write('startTimeSec: $startTimeSec, ')
          ..write('endTimeSec: $endTimeSec, ')
          ..write('rangeLabel: $rangeLabel, ')
          ..write('status: $status, ')
          ..write('summaryStyle: $summaryStyle, ')
          ..write('bullet1: $bullet1, ')
          ..write('bullet2: $bullet2, ')
          ..write('bullet3: $bullet3, ')
          ..write('bullet4: $bullet4, ')
          ..write('bullet5: $bullet5, ')
          ..write('quote1: $quote1, ')
          ..write('quote2: $quote2, ')
          ..write('quote3: $quote3, ')
          ..write('chaptersJson: $chaptersJson, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('episodeId: $episodeId, ')
          ..write('episodeUrl: $episodeUrl, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    artist,
    sourceApp,
    saveMethod,
    startTimeSec,
    endTimeSec,
    rangeLabel,
    status,
    summaryStyle,
    bullet1,
    bullet2,
    bullet3,
    bullet4,
    bullet5,
    quote1,
    quote2,
    quote3,
    chaptersJson,
    errorMessage,
    episodeId,
    episodeUrl,
    artworkUrl,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListeningSession &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.sourceApp == this.sourceApp &&
          other.saveMethod == this.saveMethod &&
          other.startTimeSec == this.startTimeSec &&
          other.endTimeSec == this.endTimeSec &&
          other.rangeLabel == this.rangeLabel &&
          other.status == this.status &&
          other.summaryStyle == this.summaryStyle &&
          other.bullet1 == this.bullet1 &&
          other.bullet2 == this.bullet2 &&
          other.bullet3 == this.bullet3 &&
          other.bullet4 == this.bullet4 &&
          other.bullet5 == this.bullet5 &&
          other.quote1 == this.quote1 &&
          other.quote2 == this.quote2 &&
          other.quote3 == this.quote3 &&
          other.chaptersJson == this.chaptersJson &&
          other.errorMessage == this.errorMessage &&
          other.episodeId == this.episodeId &&
          other.episodeUrl == this.episodeUrl &&
          other.artworkUrl == this.artworkUrl &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ListeningSessionsCompanion extends UpdateCompanion<ListeningSession> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> artist;
  final Value<String?> sourceApp;
  final Value<String> saveMethod;
  final Value<int> startTimeSec;
  final Value<int?> endTimeSec;
  final Value<String?> rangeLabel;
  final Value<String> status;
  final Value<String?> summaryStyle;
  final Value<String?> bullet1;
  final Value<String?> bullet2;
  final Value<String?> bullet3;
  final Value<String?> bullet4;
  final Value<String?> bullet5;
  final Value<String?> quote1;
  final Value<String?> quote2;
  final Value<String?> quote3;
  final Value<String?> chaptersJson;
  final Value<String?> errorMessage;
  final Value<String?> episodeId;
  final Value<String?> episodeUrl;
  final Value<String?> artworkUrl;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ListeningSessionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.sourceApp = const Value.absent(),
    this.saveMethod = const Value.absent(),
    this.startTimeSec = const Value.absent(),
    this.endTimeSec = const Value.absent(),
    this.rangeLabel = const Value.absent(),
    this.status = const Value.absent(),
    this.summaryStyle = const Value.absent(),
    this.bullet1 = const Value.absent(),
    this.bullet2 = const Value.absent(),
    this.bullet3 = const Value.absent(),
    this.bullet4 = const Value.absent(),
    this.bullet5 = const Value.absent(),
    this.quote1 = const Value.absent(),
    this.quote2 = const Value.absent(),
    this.quote3 = const Value.absent(),
    this.chaptersJson = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.episodeUrl = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListeningSessionsCompanion.insert({
    required String id,
    required String title,
    required String artist,
    this.sourceApp = const Value.absent(),
    required String saveMethod,
    required int startTimeSec,
    this.endTimeSec = const Value.absent(),
    this.rangeLabel = const Value.absent(),
    this.status = const Value.absent(),
    this.summaryStyle = const Value.absent(),
    this.bullet1 = const Value.absent(),
    this.bullet2 = const Value.absent(),
    this.bullet3 = const Value.absent(),
    this.bullet4 = const Value.absent(),
    this.bullet5 = const Value.absent(),
    this.quote1 = const Value.absent(),
    this.quote2 = const Value.absent(),
    this.quote3 = const Value.absent(),
    this.chaptersJson = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.episodeUrl = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       artist = Value(artist),
       saveMethod = Value(saveMethod),
       startTimeSec = Value(startTimeSec),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ListeningSession> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? sourceApp,
    Expression<String>? saveMethod,
    Expression<int>? startTimeSec,
    Expression<int>? endTimeSec,
    Expression<String>? rangeLabel,
    Expression<String>? status,
    Expression<String>? summaryStyle,
    Expression<String>? bullet1,
    Expression<String>? bullet2,
    Expression<String>? bullet3,
    Expression<String>? bullet4,
    Expression<String>? bullet5,
    Expression<String>? quote1,
    Expression<String>? quote2,
    Expression<String>? quote3,
    Expression<String>? chaptersJson,
    Expression<String>? errorMessage,
    Expression<String>? episodeId,
    Expression<String>? episodeUrl,
    Expression<String>? artworkUrl,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (sourceApp != null) 'source_app': sourceApp,
      if (saveMethod != null) 'save_method': saveMethod,
      if (startTimeSec != null) 'start_time_sec': startTimeSec,
      if (endTimeSec != null) 'end_time_sec': endTimeSec,
      if (rangeLabel != null) 'range_label': rangeLabel,
      if (status != null) 'status': status,
      if (summaryStyle != null) 'summary_style': summaryStyle,
      if (bullet1 != null) 'bullet1': bullet1,
      if (bullet2 != null) 'bullet2': bullet2,
      if (bullet3 != null) 'bullet3': bullet3,
      if (bullet4 != null) 'bullet4': bullet4,
      if (bullet5 != null) 'bullet5': bullet5,
      if (quote1 != null) 'quote1': quote1,
      if (quote2 != null) 'quote2': quote2,
      if (quote3 != null) 'quote3': quote3,
      if (chaptersJson != null) 'chapters_json': chaptersJson,
      if (errorMessage != null) 'error_message': errorMessage,
      if (episodeId != null) 'episode_id': episodeId,
      if (episodeUrl != null) 'episode_url': episodeUrl,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListeningSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? artist,
    Value<String?>? sourceApp,
    Value<String>? saveMethod,
    Value<int>? startTimeSec,
    Value<int?>? endTimeSec,
    Value<String?>? rangeLabel,
    Value<String>? status,
    Value<String?>? summaryStyle,
    Value<String?>? bullet1,
    Value<String?>? bullet2,
    Value<String?>? bullet3,
    Value<String?>? bullet4,
    Value<String?>? bullet5,
    Value<String?>? quote1,
    Value<String?>? quote2,
    Value<String?>? quote3,
    Value<String?>? chaptersJson,
    Value<String?>? errorMessage,
    Value<String?>? episodeId,
    Value<String?>? episodeUrl,
    Value<String?>? artworkUrl,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ListeningSessionsCompanion(
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
      artworkUrl: artworkUrl ?? this.artworkUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (sourceApp.present) {
      map['source_app'] = Variable<String>(sourceApp.value);
    }
    if (saveMethod.present) {
      map['save_method'] = Variable<String>(saveMethod.value);
    }
    if (startTimeSec.present) {
      map['start_time_sec'] = Variable<int>(startTimeSec.value);
    }
    if (endTimeSec.present) {
      map['end_time_sec'] = Variable<int>(endTimeSec.value);
    }
    if (rangeLabel.present) {
      map['range_label'] = Variable<String>(rangeLabel.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (summaryStyle.present) {
      map['summary_style'] = Variable<String>(summaryStyle.value);
    }
    if (bullet1.present) {
      map['bullet1'] = Variable<String>(bullet1.value);
    }
    if (bullet2.present) {
      map['bullet2'] = Variable<String>(bullet2.value);
    }
    if (bullet3.present) {
      map['bullet3'] = Variable<String>(bullet3.value);
    }
    if (bullet4.present) {
      map['bullet4'] = Variable<String>(bullet4.value);
    }
    if (bullet5.present) {
      map['bullet5'] = Variable<String>(bullet5.value);
    }
    if (quote1.present) {
      map['quote1'] = Variable<String>(quote1.value);
    }
    if (quote2.present) {
      map['quote2'] = Variable<String>(quote2.value);
    }
    if (quote3.present) {
      map['quote3'] = Variable<String>(quote3.value);
    }
    if (chaptersJson.present) {
      map['chapters_json'] = Variable<String>(chaptersJson.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<String>(episodeId.value);
    }
    if (episodeUrl.present) {
      map['episode_url'] = Variable<String>(episodeUrl.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListeningSessionsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('saveMethod: $saveMethod, ')
          ..write('startTimeSec: $startTimeSec, ')
          ..write('endTimeSec: $endTimeSec, ')
          ..write('rangeLabel: $rangeLabel, ')
          ..write('status: $status, ')
          ..write('summaryStyle: $summaryStyle, ')
          ..write('bullet1: $bullet1, ')
          ..write('bullet2: $bullet2, ')
          ..write('bullet3: $bullet3, ')
          ..write('bullet4: $bullet4, ')
          ..write('bullet5: $bullet5, ')
          ..write('quote1: $quote1, ')
          ..write('quote2: $quote2, ')
          ..write('quote3: $quote3, ')
          ..write('chaptersJson: $chaptersJson, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('episodeId: $episodeId, ')
          ..write('episodeUrl: $episodeUrl, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ListeningSessionsTable listeningSessions =
      $ListeningSessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [listeningSessions];
}

typedef $$ListeningSessionsTableCreateCompanionBuilder =
    ListeningSessionsCompanion Function({
      required String id,
      required String title,
      required String artist,
      Value<String?> sourceApp,
      required String saveMethod,
      required int startTimeSec,
      Value<int?> endTimeSec,
      Value<String?> rangeLabel,
      Value<String> status,
      Value<String?> summaryStyle,
      Value<String?> bullet1,
      Value<String?> bullet2,
      Value<String?> bullet3,
      Value<String?> bullet4,
      Value<String?> bullet5,
      Value<String?> quote1,
      Value<String?> quote2,
      Value<String?> quote3,
      Value<String?> chaptersJson,
      Value<String?> errorMessage,
      Value<String?> episodeId,
      Value<String?> episodeUrl,
      Value<String?> artworkUrl,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ListeningSessionsTableUpdateCompanionBuilder =
    ListeningSessionsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> artist,
      Value<String?> sourceApp,
      Value<String> saveMethod,
      Value<int> startTimeSec,
      Value<int?> endTimeSec,
      Value<String?> rangeLabel,
      Value<String> status,
      Value<String?> summaryStyle,
      Value<String?> bullet1,
      Value<String?> bullet2,
      Value<String?> bullet3,
      Value<String?> bullet4,
      Value<String?> bullet5,
      Value<String?> quote1,
      Value<String?> quote2,
      Value<String?> quote3,
      Value<String?> chaptersJson,
      Value<String?> errorMessage,
      Value<String?> episodeId,
      Value<String?> episodeUrl,
      Value<String?> artworkUrl,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ListeningSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ListeningSessionsTable> {
  $$ListeningSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceApp => $composableBuilder(
    column: $table.sourceApp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saveMethod => $composableBuilder(
    column: $table.saveMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startTimeSec => $composableBuilder(
    column: $table.startTimeSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endTimeSec => $composableBuilder(
    column: $table.endTimeSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rangeLabel => $composableBuilder(
    column: $table.rangeLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryStyle => $composableBuilder(
    column: $table.summaryStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bullet1 => $composableBuilder(
    column: $table.bullet1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bullet2 => $composableBuilder(
    column: $table.bullet2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bullet3 => $composableBuilder(
    column: $table.bullet3,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bullet4 => $composableBuilder(
    column: $table.bullet4,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bullet5 => $composableBuilder(
    column: $table.bullet5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quote1 => $composableBuilder(
    column: $table.quote1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quote2 => $composableBuilder(
    column: $table.quote2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quote3 => $composableBuilder(
    column: $table.quote3,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeUrl => $composableBuilder(
    column: $table.episodeUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ListeningSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ListeningSessionsTable> {
  $$ListeningSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceApp => $composableBuilder(
    column: $table.sourceApp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saveMethod => $composableBuilder(
    column: $table.saveMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startTimeSec => $composableBuilder(
    column: $table.startTimeSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endTimeSec => $composableBuilder(
    column: $table.endTimeSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rangeLabel => $composableBuilder(
    column: $table.rangeLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryStyle => $composableBuilder(
    column: $table.summaryStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bullet1 => $composableBuilder(
    column: $table.bullet1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bullet2 => $composableBuilder(
    column: $table.bullet2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bullet3 => $composableBuilder(
    column: $table.bullet3,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bullet4 => $composableBuilder(
    column: $table.bullet4,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bullet5 => $composableBuilder(
    column: $table.bullet5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quote1 => $composableBuilder(
    column: $table.quote1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quote2 => $composableBuilder(
    column: $table.quote2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quote3 => $composableBuilder(
    column: $table.quote3,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeUrl => $composableBuilder(
    column: $table.episodeUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ListeningSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListeningSessionsTable> {
  $$ListeningSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get sourceApp =>
      $composableBuilder(column: $table.sourceApp, builder: (column) => column);

  GeneratedColumn<String> get saveMethod => $composableBuilder(
    column: $table.saveMethod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startTimeSec => $composableBuilder(
    column: $table.startTimeSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endTimeSec => $composableBuilder(
    column: $table.endTimeSec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rangeLabel => $composableBuilder(
    column: $table.rangeLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get summaryStyle => $composableBuilder(
    column: $table.summaryStyle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bullet1 =>
      $composableBuilder(column: $table.bullet1, builder: (column) => column);

  GeneratedColumn<String> get bullet2 =>
      $composableBuilder(column: $table.bullet2, builder: (column) => column);

  GeneratedColumn<String> get bullet3 =>
      $composableBuilder(column: $table.bullet3, builder: (column) => column);

  GeneratedColumn<String> get bullet4 =>
      $composableBuilder(column: $table.bullet4, builder: (column) => column);

  GeneratedColumn<String> get bullet5 =>
      $composableBuilder(column: $table.bullet5, builder: (column) => column);

  GeneratedColumn<String> get quote1 =>
      $composableBuilder(column: $table.quote1, builder: (column) => column);

  GeneratedColumn<String> get quote2 =>
      $composableBuilder(column: $table.quote2, builder: (column) => column);

  GeneratedColumn<String> get quote3 =>
      $composableBuilder(column: $table.quote3, builder: (column) => column);

  GeneratedColumn<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<String> get episodeUrl => $composableBuilder(
    column: $table.episodeUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ListeningSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ListeningSessionsTable,
          ListeningSession,
          $$ListeningSessionsTableFilterComposer,
          $$ListeningSessionsTableOrderingComposer,
          $$ListeningSessionsTableAnnotationComposer,
          $$ListeningSessionsTableCreateCompanionBuilder,
          $$ListeningSessionsTableUpdateCompanionBuilder,
          (
            ListeningSession,
            BaseReferences<
              _$AppDatabase,
              $ListeningSessionsTable,
              ListeningSession
            >,
          ),
          ListeningSession,
          PrefetchHooks Function()
        > {
  $$ListeningSessionsTableTableManager(
    _$AppDatabase db,
    $ListeningSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListeningSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListeningSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListeningSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String?> sourceApp = const Value.absent(),
                Value<String> saveMethod = const Value.absent(),
                Value<int> startTimeSec = const Value.absent(),
                Value<int?> endTimeSec = const Value.absent(),
                Value<String?> rangeLabel = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> summaryStyle = const Value.absent(),
                Value<String?> bullet1 = const Value.absent(),
                Value<String?> bullet2 = const Value.absent(),
                Value<String?> bullet3 = const Value.absent(),
                Value<String?> bullet4 = const Value.absent(),
                Value<String?> bullet5 = const Value.absent(),
                Value<String?> quote1 = const Value.absent(),
                Value<String?> quote2 = const Value.absent(),
                Value<String?> quote3 = const Value.absent(),
                Value<String?> chaptersJson = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<String?> episodeUrl = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListeningSessionsCompanion(
                id: id,
                title: title,
                artist: artist,
                sourceApp: sourceApp,
                saveMethod: saveMethod,
                startTimeSec: startTimeSec,
                endTimeSec: endTimeSec,
                rangeLabel: rangeLabel,
                status: status,
                summaryStyle: summaryStyle,
                bullet1: bullet1,
                bullet2: bullet2,
                bullet3: bullet3,
                bullet4: bullet4,
                bullet5: bullet5,
                quote1: quote1,
                quote2: quote2,
                quote3: quote3,
                chaptersJson: chaptersJson,
                errorMessage: errorMessage,
                episodeId: episodeId,
                episodeUrl: episodeUrl,
                artworkUrl: artworkUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String artist,
                Value<String?> sourceApp = const Value.absent(),
                required String saveMethod,
                required int startTimeSec,
                Value<int?> endTimeSec = const Value.absent(),
                Value<String?> rangeLabel = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> summaryStyle = const Value.absent(),
                Value<String?> bullet1 = const Value.absent(),
                Value<String?> bullet2 = const Value.absent(),
                Value<String?> bullet3 = const Value.absent(),
                Value<String?> bullet4 = const Value.absent(),
                Value<String?> bullet5 = const Value.absent(),
                Value<String?> quote1 = const Value.absent(),
                Value<String?> quote2 = const Value.absent(),
                Value<String?> quote3 = const Value.absent(),
                Value<String?> chaptersJson = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<String?> episodeUrl = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ListeningSessionsCompanion.insert(
                id: id,
                title: title,
                artist: artist,
                sourceApp: sourceApp,
                saveMethod: saveMethod,
                startTimeSec: startTimeSec,
                endTimeSec: endTimeSec,
                rangeLabel: rangeLabel,
                status: status,
                summaryStyle: summaryStyle,
                bullet1: bullet1,
                bullet2: bullet2,
                bullet3: bullet3,
                bullet4: bullet4,
                bullet5: bullet5,
                quote1: quote1,
                quote2: quote2,
                quote3: quote3,
                chaptersJson: chaptersJson,
                errorMessage: errorMessage,
                episodeId: episodeId,
                episodeUrl: episodeUrl,
                artworkUrl: artworkUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ListeningSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ListeningSessionsTable,
      ListeningSession,
      $$ListeningSessionsTableFilterComposer,
      $$ListeningSessionsTableOrderingComposer,
      $$ListeningSessionsTableAnnotationComposer,
      $$ListeningSessionsTableCreateCompanionBuilder,
      $$ListeningSessionsTableUpdateCompanionBuilder,
      (
        ListeningSession,
        BaseReferences<
          _$AppDatabase,
          $ListeningSessionsTable,
          ListeningSession
        >,
      ),
      ListeningSession,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ListeningSessionsTableTableManager get listeningSessions =>
      $$ListeningSessionsTableTableManager(_db, _db.listeningSessions);
}
