import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/reminders/presentation/screens/home_screen.dart';

void main() {
  late MockReminderRepository repository;

  setUp(() {
    repository = MockReminderRepository(preloadSampleData: false);
  });

  tearDown(() {
    repository.dispose();
  });

  Widget wrap({
    ReminderRepository? repo,
    bool notifications = true,
    bool exactAlarms = true,
  }) {
    return ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo ?? repository),
        reminderAlarmSchedulerProvider.overrideWithValue(
          _StubAlarmScheduler(
            notifications: notifications,
            exactAlarms: exactAlarms,
          ),
        ),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  testWidgets('does not nag when delivery is healthy', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Reminders can’t be shown right now'), findsNothing);
    expect(find.text('Reminders may arrive late'), findsNothing);
  });

  testWidgets('says so when notifications are blocked', (tester) async {
    await tester.pumpWidget(wrap(notifications: false));
    await tester.pumpAndSettle();

    expect(find.text('Reminders can’t be shown right now'), findsOneWidget);
    expect(find.text('Allow notifications'), findsOneWidget);
    // The reassurance matters: the data is not lost.
    expect(find.textContaining('still saved on this device'), findsOneWidget);
  });

  testWidgets('says so when exact alarms are limited', (tester) async {
    await tester.pumpWidget(wrap(exactAlarms: false));
    await tester.pumpAndSettle();

    expect(find.text('Reminders may arrive late'), findsOneWidget);
    expect(find.text('Review settings'), findsOneWidget);
  });

  testWidgets('offers a way out of the error state', (tester) async {
    await tester.pumpWidget(wrap(repo: _FailingRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Your reminders didn’t load'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Nothing has been lost'), findsOneWidget);
  });

  testWidgets('shows a labelled loading state, not a bare spinner', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(repo: _SilentRepository()));
    await tester.pump();

    expect(find.text('Reading your reminders…'), findsOneWidget);
  });

  testWidgets('stays usable at 200% text with a delivery notice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: wrap(notifications: false),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing may clip or throw at double text size. The notice and the empty
    // state both have to survive a small screen.
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reminders can’t be shown right now'), findsOneWidget);
  });
}

class _StubAlarmScheduler implements ReminderAlarmScheduler {
  _StubAlarmScheduler({required this.notifications, required this.exactAlarms});

  final bool notifications;
  final bool exactAlarms;

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarms;

  @override
  Future<bool> canPostNotifications() async => notifications;

  @override
  Future<bool> requestExactAlarmPermission() async => exactAlarms;

  @override
  Future<bool> requestNotificationPermission() async => notifications;

  @override
  Future<void> schedule(ReminderSchedule schedule) async {}

  @override
  Future<void> cancel(String reminderId) async {}

  @override
  Future<void> cancelAll() async {}
}

class _FailingRepository implements ReminderRepository {
  @override
  Stream<List<Reminder>> watchReminders() =>
      Stream<List<Reminder>>.error(StateError('database unavailable'));

  @override
  Future<List<Reminder>> getReminders() async =>
      throw StateError('database unavailable');

  @override
  Future<Reminder?> getReminderById(String id) async => null;

  @override
  Future<void> saveReminder(Reminder reminder) async {}

  @override
  Future<void> deleteReminder(String id) async {}

  @override
  Future<void> toggleReminderStatus(String id) async {}

  @override
  Future<void> clearAllReminders() async {}
}

class _SilentRepository implements ReminderRepository {
  @override
  Stream<List<Reminder>> watchReminders() =>
      const Stream<List<Reminder>>.empty();

  @override
  Future<List<Reminder>> getReminders() async => const [];

  @override
  Future<Reminder?> getReminderById(String id) async => null;

  @override
  Future<void> saveReminder(Reminder reminder) async {}

  @override
  Future<void> deleteReminder(String id) async {}

  @override
  Future<void> toggleReminderStatus(String id) async {}

  @override
  Future<void> clearAllReminders() async {}
}
