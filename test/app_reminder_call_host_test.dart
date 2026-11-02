import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/app.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/data/services/noop_reminder_ringtone_service.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_call_bridge.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_speech_service.dart';
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

  /// The call surface is taller than the default test window, and its ringing
  /// badge animates forever. A tall window with reduced motion keeps the
  /// answer and decline buttons reachable and `pumpAndSettle` finite.
  void useCallScreenWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

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
        reminderRingtoneServiceProvider.overrideWithValue(
          const NoopReminderRingtoneService(),
        ),
        reminderSpeechServiceProvider.overrideWithValue(_SilentSpeech()),
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
    useCallScreenWindow(tester);
    await repository.saveReminder(dueReminder('launch'));
    final bridge = _FakeCallBridge(launch: 'launch');

    await tester.pumpWidget(app(bridge: bridge));
    await tester.pumpAndSettle();

    expect(find.text('Snooze for 10 minutes'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('a request raised while running opens the call surface', (
    tester,
  ) async {
    useCallScreenWindow(tester);
    await repository.saveReminder(dueReminder('live'));
    final bridge = _FakeCallBridge(launch: null);

    await tester.pumpWidget(app(bridge: bridge));
    await tester.pumpAndSettle();
    expect(find.text('Snooze for 10 minutes'), findsNothing);

    bridge.emit(const ReminderCallRequest(reminderId: 'live'));
    await tester.pumpAndSettle();

    expect(find.text('Snooze for 10 minutes'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('the same reminder is never stacked twice', (tester) async {
    useCallScreenWindow(tester);
    await repository.saveReminder(dueReminder('once'));
    final bridge = _FakeCallBridge(launch: 'once');

    await tester.pumpWidget(app(bridge: bridge));
    await tester.pumpAndSettle();

    bridge.emit(const ReminderCallRequest(reminderId: 'once'));
    await tester.pumpAndSettle();

    expect(find.text('Answer'), findsOneWidget);
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

  @override
  Future<List<String>> takeDeclinedReminderIds() async => const [];
}

class _SilentSpeech implements ReminderSpeechService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
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
