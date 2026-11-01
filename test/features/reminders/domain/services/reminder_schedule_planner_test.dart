import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';

void main() {
  group('ReminderSchedulePlanner', () {
    const planner = ReminderSchedulePlanner();
    final now = DateTime(2026, 11, 1, 10);

    Reminder reminder({
      String id = 'reminder-1',
      DateTime? scheduledAt,
      RecurrenceRule recurrence = RecurrenceRule.none,
      ReminderStatus status = ReminderStatus.active,
    }) {
      return Reminder(
        id: id,
        title: 'Test reminder',
        scheduledDateTime: scheduledAt ?? now.add(const Duration(hours: 2)),
        recurrence: recurrence,
        status: status,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('plans a future one-time reminder unchanged', () {
      final scheduledAt = now.add(const Duration(hours: 2));

      final result = planner.plan(
        reminder(scheduledAt: scheduledAt),
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.scheduledAt, scheduledAt);
      expect(result.reminderId, 'reminder-1');
    });

    test('does not schedule a past one-time reminder', () {
      final result = planner.plan(
        reminder(scheduledAt: now.subtract(const Duration(minutes: 1))),
        now: now,
      );

      expect(result, isNull);
    });

    test('advances a missed daily reminder to its next occurrence', () {
      final result = planner.plan(
        reminder(
          scheduledAt: now.subtract(const Duration(days: 1)),
          recurrence: RecurrenceRule.daily,
        ),
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.scheduledAt, DateTime(2026, 11, 1, 10).add(
        const Duration(days: 1),
      ));
    });

    test('does not schedule completed or inactive reminders', () {
      final completed = planner.plan(
        reminder(status: ReminderStatus.completed),
        now: now,
      );
      final dismissed = planner.plan(
        reminder(status: ReminderStatus.dismissed),
        now: now,
      );

      expect(completed, isNull);
      expect(dismissed, isNull);
    });

    test('plans only eligible reminders in a collection', () {
      final result = planner.planAll(
        [
          reminder(id: 'future'),
          reminder(
            id: 'completed',
            status: ReminderStatus.completed,
          ),
          reminder(
            id: 'past',
            scheduledAt: now.subtract(const Duration(minutes: 1)),
          ),
        ],
        now: now,
      );

      expect(result.map((schedule) => schedule.reminderId), ['future']);
    });
  });
}
