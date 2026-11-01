import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('ReminderRecord')
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get scheduledDateTime => dateTime()();
  TextColumn get recurrenceType => text()();
  TextColumn get recurrenceDays => text().withDefault(const Constant('[]'))();
  TextColumn get status => text()();
  TextColumn get voiceNotePath => text().nullable()();
  IntColumn get voiceNoteDurationMs => integer().nullable()();
  TextColumn get callerName => text().nullable()();
  TextColumn get callerNumber => text().nullable()();
  TextColumn get callerIcon => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local SQLite database for user reminders.
///
/// Enum values are stored by their stable names, never by enum indexes.
/// This keeps persisted data safe if enum declaration order changes.
@DriftDatabase(tables: [Reminders])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'lujayn'));

  /// In-memory or file-backed database constructor for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(reminders, reminders.voiceNotePath);
        await migrator.addColumn(reminders, reminders.voiceNoteDurationMs);
      }
      if (from < 3) {
        await migrator.addColumn(reminders, reminders.callerName);
        await migrator.addColumn(reminders, reminders.callerNumber);
        await migrator.addColumn(reminders, reminders.callerIcon);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
