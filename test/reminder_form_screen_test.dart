import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/data/services/noop_voice_playback_service.dart';
import 'package:lujayn/features/reminders/data/services/noop_voice_recording_service.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/domain/services/voice_note_storage_service.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/reminders/presentation/screens/reminder_form_screen.dart';
import 'package:lujayn/features/reminders/presentation/widgets/voice_note_player_widget.dart';

class _FakeFormStorage implements VoiceNoteStorageService {
  @override
  Future<void> clearAllRecordings() async {}
  @override
  Future<int> cleanupOrphanedRecordings(List<String> activeFileNames) async =>
      0;
  @override
  Future<void> deleteRecording(String fileName) async {}
  @override
  Future<String> generateNewRecordingPath({String? reminderId}) async =>
      '/mock/path.m4a';
  @override
  Future<String> getRecordingsDirectory() async => '/mock/recordings';
  @override
  Future<String> resolvePath(String fileName) async => '/mock/$fileName';
}

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

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
        reminderAlarmSchedulerProvider.overrideWithValue(scheduler),
        voiceNoteStorageServiceProvider.overrideWithValue(_FakeFormStorage()),
        voiceRecordingServiceProvider.overrideWithValue(
          const NoopVoiceRecordingService(),
        ),
        voicePlaybackServiceProvider.overrideWithValue(
          NoopVoicePlaybackService(),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  Reminder reminderAt(DateTime when, {RecurrenceRule? recurrence}) {
    return Reminder(
      id: 'form-reminder',
      title: 'Collect the parcel',
      scheduledDateTime: when,
      recurrence: recurrence ?? RecurrenceRule.none,
      createdAt: when,
      updatedAt: when,
    );
  }

  testWidgets('refuses a one-time reminder set in the past', (tester) async {
    final past = DateTime.now().subtract(const Duration(hours: 2));

    await tester.pumpWidget(
      wrap(ReminderFormScreen(initialReminder: reminderAt(past))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Choose a time in the future, or make this a repeating reminder.',
      ),
      findsOneWidget,
    );
    // Nothing was stored and no alarm was scheduled.
    expect(await repository.getReminders(), isEmpty);
    expect(scheduler.scheduled, isEmpty);
  });

  testWidgets('accepts a repeating reminder whose first time has passed', (
    tester,
  ) async {
    final past = DateTime.now().subtract(const Duration(hours: 2));

    await tester.pumpWidget(
      wrap(
        ReminderFormScreen(
          initialReminder: reminderAt(past, recurrence: RecurrenceRule.daily),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The planner advances a repeating reminder, so this is a valid save.
    expect(scheduler.scheduled, isNotEmpty);
    expect(
      scheduler.scheduled.single.scheduledAt.isAfter(DateTime.now()),
      isTrue,
    );
  });

  testWidgets(
    'editing reminder with voice note renders preview player with duration',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final future = DateTime.now().add(const Duration(hours: 3));
      final reminder = reminderAt(future).copyWith(
        voiceNotePath: 'voice_clip.m4a',
        voiceNoteDuration: const Duration(seconds: 18),
      );

      await tester.pumpWidget(
        wrap(ReminderFormScreen(initialReminder: reminder)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VoiceNotePlayerWidget), findsOneWidget);
      expect(find.text('0:18'), findsOneWidget);
    },
  );
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
