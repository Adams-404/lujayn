// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, ReminderRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
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
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledDateTimeMeta = const VerificationMeta(
    'scheduledDateTime',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledDateTime =
      GeneratedColumn<DateTime>(
        'scheduled_date_time',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _recurrenceTypeMeta = const VerificationMeta(
    'recurrenceType',
  );
  @override
  late final GeneratedColumn<String> recurrenceType = GeneratedColumn<String>(
    'recurrence_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recurrenceDaysMeta = const VerificationMeta(
    'recurrenceDays',
  );
  @override
  late final GeneratedColumn<String> recurrenceDays = GeneratedColumn<String>(
    'recurrence_days',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voiceNotePathMeta = const VerificationMeta(
    'voiceNotePath',
  );
  @override
  late final GeneratedColumn<String> voiceNotePath = GeneratedColumn<String>(
    'voice_note_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voiceNoteDurationMsMeta =
      const VerificationMeta('voiceNoteDurationMs');
  @override
  late final GeneratedColumn<int> voiceNoteDurationMs = GeneratedColumn<int>(
    'voice_note_duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    scheduledDateTime,
    recurrenceType,
    recurrenceDays,
    status,
    voiceNotePath,
    voiceNoteDurationMs,
    createdAt,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderRecord> instance, {
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_date_time')) {
      context.handle(
        _scheduledDateTimeMeta,
        scheduledDateTime.isAcceptableOrUnknown(
          data['scheduled_date_time']!,
          _scheduledDateTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledDateTimeMeta);
    }
    if (data.containsKey('recurrence_type')) {
      context.handle(
        _recurrenceTypeMeta,
        recurrenceType.isAcceptableOrUnknown(
          data['recurrence_type']!,
          _recurrenceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recurrenceTypeMeta);
    }
    if (data.containsKey('recurrence_days')) {
      context.handle(
        _recurrenceDaysMeta,
        recurrenceDays.isAcceptableOrUnknown(
          data['recurrence_days']!,
          _recurrenceDaysMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('voice_note_path')) {
      context.handle(
        _voiceNotePathMeta,
        voiceNotePath.isAcceptableOrUnknown(
          data['voice_note_path']!,
          _voiceNotePathMeta,
        ),
      );
    }
    if (data.containsKey('voice_note_duration_ms')) {
      context.handle(
        _voiceNoteDurationMsMeta,
        voiceNoteDurationMs.isAcceptableOrUnknown(
          data['voice_note_duration_ms']!,
          _voiceNoteDurationMsMeta,
        ),
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
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      scheduledDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_date_time'],
      )!,
      recurrenceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_type'],
      )!,
      recurrenceDays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_days'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      voiceNotePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_note_path'],
      ),
      voiceNoteDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}voice_note_duration_ms'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class ReminderRecord extends DataClass implements Insertable<ReminderRecord> {
  final String id;
  final String title;
  final String? description;
  final DateTime scheduledDateTime;
  final String recurrenceType;
  final String recurrenceDays;
  final String status;
  final String? voiceNotePath;
  final int? voiceNoteDurationMs;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  const ReminderRecord({
    required this.id,
    required this.title,
    this.description,
    required this.scheduledDateTime,
    required this.recurrenceType,
    required this.recurrenceDays,
    required this.status,
    this.voiceNotePath,
    this.voiceNoteDurationMs,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['scheduled_date_time'] = Variable<DateTime>(scheduledDateTime);
    map['recurrence_type'] = Variable<String>(recurrenceType);
    map['recurrence_days'] = Variable<String>(recurrenceDays);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || voiceNotePath != null) {
      map['voice_note_path'] = Variable<String>(voiceNotePath);
    }
    if (!nullToAbsent || voiceNoteDurationMs != null) {
      map['voice_note_duration_ms'] = Variable<int>(voiceNoteDurationMs);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      scheduledDateTime: Value(scheduledDateTime),
      recurrenceType: Value(recurrenceType),
      recurrenceDays: Value(recurrenceDays),
      status: Value(status),
      voiceNotePath: voiceNotePath == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceNotePath),
      voiceNoteDurationMs: voiceNoteDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceNoteDurationMs),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory ReminderRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderRecord(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      scheduledDateTime: serializer.fromJson<DateTime>(
        json['scheduledDateTime'],
      ),
      recurrenceType: serializer.fromJson<String>(json['recurrenceType']),
      recurrenceDays: serializer.fromJson<String>(json['recurrenceDays']),
      status: serializer.fromJson<String>(json['status']),
      voiceNotePath: serializer.fromJson<String?>(json['voiceNotePath']),
      voiceNoteDurationMs: serializer.fromJson<int?>(
        json['voiceNoteDurationMs'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'scheduledDateTime': serializer.toJson<DateTime>(scheduledDateTime),
      'recurrenceType': serializer.toJson<String>(recurrenceType),
      'recurrenceDays': serializer.toJson<String>(recurrenceDays),
      'status': serializer.toJson<String>(status),
      'voiceNotePath': serializer.toJson<String?>(voiceNotePath),
      'voiceNoteDurationMs': serializer.toJson<int?>(voiceNoteDurationMs),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  ReminderRecord copyWith({
    String? id,
    String? title,
    Value<String?> description = const Value.absent(),
    DateTime? scheduledDateTime,
    String? recurrenceType,
    String? recurrenceDays,
    String? status,
    Value<String?> voiceNotePath = const Value.absent(),
    Value<int?> voiceNoteDurationMs = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => ReminderRecord(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
    recurrenceType: recurrenceType ?? this.recurrenceType,
    recurrenceDays: recurrenceDays ?? this.recurrenceDays,
    status: status ?? this.status,
    voiceNotePath: voiceNotePath.present
        ? voiceNotePath.value
        : this.voiceNotePath,
    voiceNoteDurationMs: voiceNoteDurationMs.present
        ? voiceNoteDurationMs.value
        : this.voiceNoteDurationMs,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  ReminderRecord copyWithCompanion(RemindersCompanion data) {
    return ReminderRecord(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      scheduledDateTime: data.scheduledDateTime.present
          ? data.scheduledDateTime.value
          : this.scheduledDateTime,
      recurrenceType: data.recurrenceType.present
          ? data.recurrenceType.value
          : this.recurrenceType,
      recurrenceDays: data.recurrenceDays.present
          ? data.recurrenceDays.value
          : this.recurrenceDays,
      status: data.status.present ? data.status.value : this.status,
      voiceNotePath: data.voiceNotePath.present
          ? data.voiceNotePath.value
          : this.voiceNotePath,
      voiceNoteDurationMs: data.voiceNoteDurationMs.present
          ? data.voiceNoteDurationMs.value
          : this.voiceNoteDurationMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderRecord(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('scheduledDateTime: $scheduledDateTime, ')
          ..write('recurrenceType: $recurrenceType, ')
          ..write('recurrenceDays: $recurrenceDays, ')
          ..write('status: $status, ')
          ..write('voiceNotePath: $voiceNotePath, ')
          ..write('voiceNoteDurationMs: $voiceNoteDurationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    scheduledDateTime,
    recurrenceType,
    recurrenceDays,
    status,
    voiceNotePath,
    voiceNoteDurationMs,
    createdAt,
    updatedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderRecord &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.scheduledDateTime == this.scheduledDateTime &&
          other.recurrenceType == this.recurrenceType &&
          other.recurrenceDays == this.recurrenceDays &&
          other.status == this.status &&
          other.voiceNotePath == this.voiceNotePath &&
          other.voiceNoteDurationMs == this.voiceNoteDurationMs &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class RemindersCompanion extends UpdateCompanion<ReminderRecord> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<DateTime> scheduledDateTime;
  final Value<String> recurrenceType;
  final Value<String> recurrenceDays;
  final Value<String> status;
  final Value<String?> voiceNotePath;
  final Value<int?> voiceNoteDurationMs;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.scheduledDateTime = const Value.absent(),
    this.recurrenceType = const Value.absent(),
    this.recurrenceDays = const Value.absent(),
    this.status = const Value.absent(),
    this.voiceNotePath = const Value.absent(),
    this.voiceNoteDurationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    required DateTime scheduledDateTime,
    required String recurrenceType,
    this.recurrenceDays = const Value.absent(),
    required String status,
    this.voiceNotePath = const Value.absent(),
    this.voiceNoteDurationMs = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       scheduledDateTime = Value(scheduledDateTime),
       recurrenceType = Value(recurrenceType),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ReminderRecord> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<DateTime>? scheduledDateTime,
    Expression<String>? recurrenceType,
    Expression<String>? recurrenceDays,
    Expression<String>? status,
    Expression<String>? voiceNotePath,
    Expression<int>? voiceNoteDurationMs,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (scheduledDateTime != null) 'scheduled_date_time': scheduledDateTime,
      if (recurrenceType != null) 'recurrence_type': recurrenceType,
      if (recurrenceDays != null) 'recurrence_days': recurrenceDays,
      if (status != null) 'status': status,
      if (voiceNotePath != null) 'voice_note_path': voiceNotePath,
      if (voiceNoteDurationMs != null)
        'voice_note_duration_ms': voiceNoteDurationMs,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<DateTime>? scheduledDateTime,
    Value<String>? recurrenceType,
    Value<String>? recurrenceDays,
    Value<String>? status,
    Value<String?>? voiceNotePath,
    Value<int?>? voiceNoteDurationMs,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      status: status ?? this.status,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
      voiceNoteDurationMs: voiceNoteDurationMs ?? this.voiceNoteDurationMs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (scheduledDateTime.present) {
      map['scheduled_date_time'] = Variable<DateTime>(scheduledDateTime.value);
    }
    if (recurrenceType.present) {
      map['recurrence_type'] = Variable<String>(recurrenceType.value);
    }
    if (recurrenceDays.present) {
      map['recurrence_days'] = Variable<String>(recurrenceDays.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (voiceNotePath.present) {
      map['voice_note_path'] = Variable<String>(voiceNotePath.value);
    }
    if (voiceNoteDurationMs.present) {
      map['voice_note_duration_ms'] = Variable<int>(voiceNoteDurationMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('scheduledDateTime: $scheduledDateTime, ')
          ..write('recurrenceType: $recurrenceType, ')
          ..write('recurrenceDays: $recurrenceDays, ')
          ..write('status: $status, ')
          ..write('voiceNotePath: $voiceNotePath, ')
          ..write('voiceNoteDurationMs: $voiceNoteDurationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [reminders];
}

typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      required String id,
      required String title,
      Value<String?> description,
      required DateTime scheduledDateTime,
      required String recurrenceType,
      Value<String> recurrenceDays,
      required String status,
      Value<String?> voiceNotePath,
      Value<int?> voiceNoteDurationMs,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> description,
      Value<DateTime> scheduledDateTime,
      Value<String> recurrenceType,
      Value<String> recurrenceDays,
      Value<String> status,
      Value<String?> voiceNotePath,
      Value<int?> voiceNoteDurationMs,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledDateTime => $composableBuilder(
    column: $table.scheduledDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceType => $composableBuilder(
    column: $table.recurrenceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceDays => $composableBuilder(
    column: $table.recurrenceDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceNotePath => $composableBuilder(
    column: $table.voiceNotePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get voiceNoteDurationMs => $composableBuilder(
    column: $table.voiceNoteDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledDateTime => $composableBuilder(
    column: $table.scheduledDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceType => $composableBuilder(
    column: $table.recurrenceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceDays => $composableBuilder(
    column: $table.recurrenceDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceNotePath => $composableBuilder(
    column: $table.voiceNotePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get voiceNoteDurationMs => $composableBuilder(
    column: $table.voiceNoteDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scheduledDateTime => $composableBuilder(
    column: $table.scheduledDateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceType => $composableBuilder(
    column: $table.recurrenceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceDays => $composableBuilder(
    column: $table.recurrenceDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get voiceNotePath => $composableBuilder(
    column: $table.voiceNotePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get voiceNoteDurationMs => $composableBuilder(
    column: $table.voiceNoteDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          ReminderRecord,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (
            ReminderRecord,
            BaseReferences<_$AppDatabase, $RemindersTable, ReminderRecord>,
          ),
          ReminderRecord,
          PrefetchHooks Function()
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> scheduledDateTime = const Value.absent(),
                Value<String> recurrenceType = const Value.absent(),
                Value<String> recurrenceDays = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> voiceNotePath = const Value.absent(),
                Value<int?> voiceNoteDurationMs = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                title: title,
                description: description,
                scheduledDateTime: scheduledDateTime,
                recurrenceType: recurrenceType,
                recurrenceDays: recurrenceDays,
                status: status,
                voiceNotePath: voiceNotePath,
                voiceNoteDurationMs: voiceNoteDurationMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> description = const Value.absent(),
                required DateTime scheduledDateTime,
                required String recurrenceType,
                Value<String> recurrenceDays = const Value.absent(),
                required String status,
                Value<String?> voiceNotePath = const Value.absent(),
                Value<int?> voiceNoteDurationMs = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                title: title,
                description: description,
                scheduledDateTime: scheduledDateTime,
                recurrenceType: recurrenceType,
                recurrenceDays: recurrenceDays,
                status: status,
                voiceNotePath: voiceNotePath,
                voiceNoteDurationMs: voiceNoteDurationMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemindersTable, ReminderRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RemindersTable,
                    ReminderRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      ReminderRecord,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (
        ReminderRecord,
        BaseReferences<_$AppDatabase, $RemindersTable, ReminderRecord>,
      ),
      ReminderRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
}
