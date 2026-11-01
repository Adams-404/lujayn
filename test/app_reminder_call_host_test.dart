import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/app.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_call_bridge.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/settings/presentation/controllers/settings_providers.dart';

void main() {
  late MockReminderRepository repository;

  setUp(() {
    repository = MockReminderRepository(preloadSampleData: false);
  });

  tearDown(() {
    repository.dispose();
  });

  Reminder dueReminder(String id) {
    final now = DateTime.now();
    return Reminder(
      id: id,
      title: 'Water the plants',
      scheduledDateTime: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget app({required ReminderCallBridge bridge}) {
    return ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
        reminderAlarmSchedulerProvider.overrideWithValue(_NoopAlarmScheduler()),
        reminderCallBridgeProvider.overrideWithValue(bridge),
        themePreferenceStoreProvider.overrideWithValue(
          _MemoryThemePreferenceStore(),
        ),
      ],
      child: const LujaynApp(),
    );
  }

  testWidgets('a launch request opens the call surface after first frame', (
    tester,
  ) async {
    await repository.saveReminder(dueReminder('launch'));
    final bridge = _FakeCallBridge(launch: 'launch');

    await tester.pumpWidget(app(bridge: bridge));
    await tester.pumpAndSettle();

    expect(find.text('Snooze 10 minutes'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('a request raised while running opens the call surface', (
    tester,
  ) async {
    await repository.saveReminder(dueReminder('live'));
    final bridge = _FakeCallBridge(launch: null);

    await tester.pumpWidget(app(bridge: bridge));
    await tester.pumpAndSettle();
    expect(find.text('Snooze 10 minutes'), findsNothing);

    bridge.emit(const ReminderCallRequest(reminderId: 'live'));
    await tester.pumpAndSettle();

    expect(find.text('Snooze 10 minutes'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('the same reminder is never stacked twice', (tester) async {
    await repository.saveReminder(dueReminder('once'));
    final bridge = _FakeCallBridge(launch: 'once');

    await tester.pumpWidget(app(bridge: bridge));
    await tester.pumpAndSettle();

    bridge.emit(const ReminderCallRequest(reminderId: 'once'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
  });
}

class _FakeCallBridge implements ReminderCallBridge {
  _FakeCallBridge({required this.launch});

  final String? launch;
  final _controller = StreamController<ReminderCallRequest>.broadcast();

  void emit(ReminderCallRequest request) => _controller.add(request);

  @override
  Future<ReminderCallRequest?> takeLaunchRequest() async =>
      launch == null ? null : ReminderCallRequest(reminderId: launch!);

  @override
  Stream<ReminderCallRequest> get requests => _controller.stream;
}

class _NoopAlarmScheduler implements ReminderAlarmScheduler {
  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<bool> canPostNotifications() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<void> schedule(ReminderSchedule schedule) async {}

  @override
  Future<void> cancel(String reminderId) async {}

  @override
  Future<void> cancelAll() async {}
}

class _MemoryThemePreferenceStore implements ThemePreferenceStore {
  String? value;

  @override
  Future<String?> readThemeChoice() async => value;

  @override
  Future<void> writeThemeChoice(String value) async {
    this.value = value;
  }
}
