import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/reminders/presentation/screens/reminder_call_screen.dart';

void main() {
  late MockReminderRepository repository;
  late _RecordingAlarmScheduler scheduler;

  setUp(() {
    repository = MockReminderRepository(preloadSampleData: false);
    scheduler = _RecordingAlarmScheduler();
  });

  tearDown(() {
    repository.dispose();
  });

  Reminder dueReminder({String id = 'due'}) {
    final now = DateTime.now();
    return Reminder(
      id: id,
      title: 'Take evening medication',
      description: 'With a full glass of water',
      scheduledDateTime: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
        reminderAlarmSchedulerProvider.overrideWithValue(scheduler),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('shows the due reminder with both actions', (tester) async {
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    expect(find.text('Take evening medication'), findsOneWidget);
    expect(find.text('With a full glass of water'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Snooze 10 minutes'), findsOneWidget);
  });

  testWidgets('snoozing schedules a separate alarm', (tester) async {
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Snooze 10 minutes'));
    await tester.pumpAndSettle();

    expect(scheduler.scheduled.single.reminderId, 'due::snooze');
  });

  testWidgets('completing a one-time reminder cancels its alarm', (
    tester,
  ) async {
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(
      (await repository.getReminderById(reminder.id))!.status,
      ReminderStatus.completed,
    );
    expect(scheduler.cancelled, contains('due'));
  });

  testWidgets('explains a reminder that no longer exists', (tester) async {
    await tester.pumpWidget(wrap(const ReminderCallScreen(reminderId: 'gone')));
    await tester.pumpAndSettle();

    expect(find.text('Reminder not found'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}

class _RecordingAlarmScheduler implements ReminderAlarmScheduler {
  final List<ReminderSchedule> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<bool> canPostNotifications() async => true;

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
  Future<void> cancelAll() async {}
}
