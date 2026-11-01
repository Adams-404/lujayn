import 'dart:async';
import '../../domain/models/recurrence_rule.dart';
import '../../domain/models/reminder.dart';
import '../../domain/models/reminder_status.dart';
import '../../domain/repositories/reminder_repository.dart';

/// In-memory mock implementation of [ReminderRepository].
///
/// Used only in tests and previews. Production uses the local Drift SQLite repository.
class MockReminderRepository implements ReminderRepository {
  MockReminderRepository({bool preloadSampleData = true}) {
    if (preloadSampleData) {
      _reminders.addAll(_generateSampleReminders());
    }
    _emit();
  }

  final List<Reminder> _reminders = [];
  final StreamController<List<Reminder>> _streamController =
      StreamController<List<Reminder>>.broadcast();

  void _emit() {
    // Sort reminders chronologically: active first by scheduled time, then completed
    final sorted = List<Reminder>.from(_reminders)
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return a.scheduledDateTime.compareTo(b.scheduledDateTime);
      });
    _streamController.add(List.unmodifiable(sorted));
  }

  @override
  Stream<List<Reminder>> watchReminders() {
    // Emit initial state immediately on listen
    scheduleMicrotask(_emit);
    return _streamController.stream;
  }

  @override
  Future<List<Reminder>> getReminders() async {
    return List.unmodifiable(_reminders);
  }

  @override
  Future<Reminder?> getReminderById(String id) async {
    try {
      return _reminders.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveReminder(Reminder reminder) async {
    final existingIndex = _reminders.indexWhere((r) => r.id == reminder.id);
    if (existingIndex >= 0) {
      _reminders[existingIndex] = reminder.copyWith(updatedAt: DateTime.now());
    } else {
      _reminders.add(reminder);
    }
    _emit();
  }

  @override
  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    _emit();
  }

  @override
  Future<void> toggleReminderStatus(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index >= 0) {
      final current = _reminders[index];
      final newStatus = current.isCompleted
          ? ReminderStatus.active
          : ReminderStatus.completed;

      _reminders[index] = current.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
        completedAt: newStatus == ReminderStatus.completed
            ? DateTime.now()
            : null,
        clearCompletedAt: newStatus == ReminderStatus.active,
      );
      _emit();
    }
  }

  Future<void> resetToSampleData() async {
    _reminders
      ..clear()
      ..addAll(_generateSampleReminders());
    _emit();
  }

  @override
  Future<void> clearAllReminders() async {
    _reminders.clear();
    _emit();
  }

  void dispose() {
    _streamController.close();
  }

  static List<Reminder> _generateSampleReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return [
      Reminder(
        id: 'sample-1',
        title: 'Morning blood pressure check',
        description:
            'Take resting reading before breakfast and note in logbook.',
        scheduledDateTime: DateTime(today.year, today.month, today.day, 8, 0),
        recurrence: RecurrenceRule.daily,
        status: ReminderStatus.active,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Reminder(
        id: 'sample-2',
        title: 'Call Mom',
        description:
            'Check in on how her doctor appointment went and ask about the weekend.',
        scheduledDateTime: DateTime(today.year, today.month, today.day, 18, 30),
        recurrence: RecurrenceRule.none,
        status: ReminderStatus.active,
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
      Reminder(
        id: 'sample-3',
        title: 'Water indoor plants & mist ferns',
        description:
            'Check soil dryness before watering. Use room-temperature water.',
        scheduledDateTime: DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          9,
          30,
        ),
        recurrence: RecurrenceRule.weekly,
        status: ReminderStatus.active,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      Reminder(
        id: 'sample-4',
        title: 'Evening quiet walk & unwind',
        description:
            'Leave phone on silent. 20 minutes of fresh air before bed.',
        scheduledDateTime: DateTime(today.year, today.month, today.day, 21, 0),
        recurrence: RecurrenceRule.weekdays,
        status: ReminderStatus.active,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      Reminder(
        id: 'sample-5',
        title: 'Collect prescription refill',
        description: 'Pharmacy order #8092 ready for pickup at corner clinic.',
        scheduledDateTime: DateTime(today.year, today.month, today.day, 11, 0),
        recurrence: RecurrenceRule.none,
        status: ReminderStatus.completed,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        completedAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }
}
