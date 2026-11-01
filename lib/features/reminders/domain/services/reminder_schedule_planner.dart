import '../models/reminder.dart';
import '../models/reminder_status.dart';
import '../models/recurrence_rule.dart';

/// A single alarm occurrence derived from a persisted reminder.
class ReminderSchedule {
  const ReminderSchedule({
    required this.reminderId,
    required this.title,
    this.description,
    required this.recurrence,
    required this.scheduledAt,
  });

  final String reminderId;
  final String title;
  final String? description;
  final RecurrenceRule recurrence;
  final DateTime scheduledAt;
}

/// Converts persisted reminders into the next alarm occurrence.
///
/// This class is deliberately platform-independent so recurrence and
/// eligibility rules can be tested without Android or a device.
class ReminderSchedulePlanner {
  const ReminderSchedulePlanner();

  ReminderSchedule? plan(Reminder reminder, {required DateTime now}) {
    if (reminder.status != ReminderStatus.active) return null;

    final nextOccurrence = reminder.recurrence.calculateNextOccurrence(
      reminder.scheduledDateTime,
      after: now,
    );

    if (!nextOccurrence.isAfter(now)) return null;

    return ReminderSchedule(
      reminderId: reminder.id,
      title: reminder.title,
      description: reminder.description,
      recurrence: reminder.recurrence,
      scheduledAt: nextOccurrence,
    );
  }

  List<ReminderSchedule> planAll(
    Iterable<Reminder> reminders, {
    required DateTime now,
  }) {
    return reminders
        .map((reminder) => plan(reminder, now: now))
        .whereType<ReminderSchedule>()
        .toList(growable: false);
  }
}
