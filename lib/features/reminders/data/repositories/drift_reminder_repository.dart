import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/models/recurrence_rule.dart';
import '../../domain/models/reminder.dart';
import '../../domain/models/reminder_status.dart';
import '../../domain/repositories/reminder_repository.dart';

/// SQLite-backed implementation of [ReminderRepository].
class DriftReminderRepository implements ReminderRepository {
  DriftReminderRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<Reminder>> watchReminders() {
    return _database.select(_database.reminders).watch().map(_sortRecords);
  }

  @override
  Future<List<Reminder>> getReminders() async {
    final records = await _database.select(_database.reminders).get();
    return _sortRecords(records);
  }

  @override
  Future<Reminder?> getReminderById(String id) async {
    final record = await (_database.select(
      _database.reminders,
    )..where((table) => table.id.equals(id))).getSingleOrNull();

    return record == null ? null : _toDomain(record);
  }

  @override
  Future<void> saveReminder(Reminder reminder) async {
    await _database
        .into(_database.reminders)
        .insertOnConflictUpdate(_toCompanion(reminder));
  }

  @override
  Future<void> deleteReminder(String id) async {
    await (_database.delete(
      _database.reminders,
    )..where((table) => table.id.equals(id))).go();
  }

  @override
  Future<void> toggleReminderStatus(String id) async {
    final reminder = await getReminderById(id);
    if (reminder == null) return;

    final nextStatus = reminder.isCompleted
        ? ReminderStatus.active
        : ReminderStatus.completed;
    final now = DateTime.now();

    await saveReminder(
      reminder.copyWith(
        status: nextStatus,
        updatedAt: now,
        completedAt: nextStatus == ReminderStatus.completed ? now : null,
        clearCompletedAt: nextStatus == ReminderStatus.active,
      ),
    );
  }

  @override
  Future<void> clearAllReminders() async {
    await _database.delete(_database.reminders).go();
  }

  List<Reminder> _sortRecords(List<ReminderRecord> records) {
    final reminders = records.map(_toDomain).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return a.scheduledDateTime.compareTo(b.scheduledDateTime);
      });
    return reminders;
  }

  RemindersCompanion _toCompanion(Reminder reminder) {
    return RemindersCompanion.insert(
      id: reminder.id,
      title: reminder.title,
      description: Value(reminder.description),
      scheduledDateTime: reminder.scheduledDateTime,
      recurrenceType: reminder.recurrence.type.name,
      recurrenceDays: Value(jsonEncode(reminder.recurrence.daysOfWeek)),
      status: reminder.status.name,
      voiceNotePath: Value(reminder.voiceNotePath),
      voiceNoteDurationMs: Value(reminder.voiceNoteDuration?.inMilliseconds),
      createdAt: reminder.createdAt,
      updatedAt: reminder.updatedAt,
      completedAt: Value(reminder.completedAt),
    );
  }

  Reminder _toDomain(ReminderRecord record) {
    return Reminder(
      id: record.id,
      title: record.title,
      description: record.description,
      scheduledDateTime: record.scheduledDateTime,
      recurrence: RecurrenceRule(
        type: _enumByName(
          RecurrenceType.values,
          record.recurrenceType,
          RecurrenceType.none,
        ),
        daysOfWeek: _decodeDays(record.recurrenceDays),
      ),
      status: _enumByName(
        ReminderStatus.values,
        record.status,
        ReminderStatus.active,
      ),
      voiceNotePath: record.voiceNotePath,
      voiceNoteDuration: record.voiceNoteDurationMs != null
          ? Duration(milliseconds: record.voiceNoteDurationMs!)
          : null,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      completedAt: record.completedAt,
    );
  }

  List<int> _decodeDays(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      return decoded.whereType<num>().map((day) => day.toInt()).toList();
    } on FormatException {
      return const [];
    }
  }

  T _enumByName<T extends Enum>(List<T> values, String name, T fallback) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => fallback,
    );
  }
}
