import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';

void main() {
  group('ReminderActionNotifier alarm synchronization', () {
    late MockReminderRepository repository;
    late _FakeReminderAlarmScheduler scheduler;
    late ReminderActionNotifier actions;

    setUp(() {
      repository = MockReminderRepository(preloadSampleData: false);
      scheduler = _FakeReminderAlarmScheduler();
      actions = ReminderActionNotifier(
        repository,
        scheduler,
        const ReminderSchedulePlanner(),
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test('schedules a reminder after it is persisted', () async {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 'scheduled',
        title: 'Call Mum',
        scheduledDateTime: now.add(const Duration(hours: 2)),
        createdAt: now,
        updatedAt: now,
      );

      await actions.createOrUpdateReminder(reminder);

      expect(await repository.getReminderById(reminder.id), reminder);
      expect(scheduler.scheduled.single.reminderId, reminder.id);
    });

    test('cancels on completion and reschedules when reactivated', () async {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 'toggle',
        title: 'Read',
        scheduledDateTime: now.add(const Duration(hours: 2)),
        createdAt: now,
        updatedAt: now,
      );
      await actions.createOrUpdateReminder(reminder);

      await actions.toggleStatus(reminder.id);
      expect(scheduler.cancelled, contains(reminder.id));

      await actions.toggleStatus(reminder.id);
      expect(
        scheduler.scheduled.where((item) => item.reminderId == reminder.id),
        hasLength(2),
      );
    });

    test('cancels the alarm when a reminder is deleted', () async {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 'delete',
        title: 'Delete me',
        scheduledDateTime: now.add(const Duration(hours: 2)),
        createdAt: now,
        updatedAt: now,
      );
      await actions.createOrUpdateReminder(reminder);

      await actions.deleteReminder(reminder.id);

      expect(await repository.getReminderById(reminder.id), isNull);
      expect(scheduler.cancelled, contains(reminder.id));
    });

    test('clears all alarms when all reminders are cleared', () async {
      await actions.clearAll();

      expect(scheduler.cancelAllCalls, 1);
    });

    test(
      'snooze schedules a separate alarm without moving the reminder',
      () async {
        final now = DateTime.now();
        final reminder = Reminder(
          id: 'snooze',
          title: 'Drink water',
          scheduledDateTime: now.add(const Duration(hours: 2)),
          recurrence: RecurrenceRule.daily,
          createdAt: now,
          updatedAt: now,
        );
        await actions.createOrUpdateReminder(reminder);

        await actions.snooze(
          reminder.id,
          duration: const Duration(minutes: 10),
        );

        final snoozed = scheduler.scheduled.last;
        expect(snoozed.reminderId, 'snooze::snooze');
        expect(snoozed.recurrence, RecurrenceRule.none);
        expect(
          snoozed.scheduledAt.difference(DateTime.now()).inMinutes,
          inInclusiveRange(9, 10),
        );
        expect(
          (await repository.getReminderById(reminder.id))!.scheduledDateTime,
          reminder.scheduledDateTime,
        );
      },
    );

    test(
      'dismissing a one-time reminder completes it and cancels alarms',
      () async {
        final now = DateTime.now();
        final reminder = Reminder(
          id: 'dismiss-once',
          title: 'Post the letter',
          scheduledDateTime: now.add(const Duration(minutes: 1)),
          createdAt: now,
          updatedAt: now,
        );
        await actions.createOrUpdateReminder(reminder);

        await actions.dismissOccurrence(reminder.id);

        final stored = await repository.getReminderById(reminder.id);
        expect(stored!.status, ReminderStatus.completed);
        expect(stored.completedAt, isNotNull);
        expect(scheduler.cancelled, contains('dismiss-once'));
        expect(scheduler.cancelled, contains('dismiss-once::snooze'));
      },
    );

    test('dismissing a recurring reminder keeps the series active', () async {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 'dismiss-repeat',
        title: 'Take vitamins',
        scheduledDateTime: now.add(const Duration(minutes: 1)),
        recurrence: RecurrenceRule.daily,
        createdAt: now,
        updatedAt: now,
      );
      await actions.createOrUpdateReminder(reminder);

      await actions.dismissOccurrence(reminder.id);

      final stored = await repository.getReminderById(reminder.id);
      expect(stored!.status, ReminderStatus.active);
      expect(
        scheduler.scheduled.where(
          (item) => item.reminderId == 'dismiss-repeat',
        ),
        hasLength(2),
      );
      expect(scheduler.cancelled, contains('dismiss-repeat::snooze'));
    });
  });
}

class _FakeReminderAlarmScheduler implements ReminderAlarmScheduler {
  final List<ReminderSchedule> scheduled = [];
  final List<String> cancelled = [];
  int cancelAllCalls = 0;

  @override
  Future<bool> canPostNotifications() async => true;

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<void> schedule(ReminderSchedule schedule) async {
    scheduled.add(schedule);
  }

  @override
  Future<void> cancel(String reminderId) async {
    cancelled.add(reminderId);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
  }
}
