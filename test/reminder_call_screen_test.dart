import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/data/services/noop_voice_playback_service.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_speech_service.dart';
import 'package:lujayn/features/reminders/domain/services/voice_note_storage_service.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/reminders/presentation/screens/reminder_call_screen.dart';
import 'package:lujayn/features/reminders/presentation/widgets/voice_note_player_widget.dart';
import 'package:lujayn/features/settings/presentation/controllers/settings_providers.dart';

class _FakeStorage implements VoiceNoteStorageService {
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
  late _FakeSpeech speech;
  late _FakeSpeechPreferenceStore speechPreferenceStore;

  setUp(() {
    repository = MockReminderRepository(preloadSampleData: false);
    scheduler = _RecordingAlarmScheduler();
    speech = _FakeSpeech();
    speechPreferenceStore = _FakeSpeechPreferenceStore();
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
        reminderSpeechServiceProvider.overrideWithValue(speech),
        speechPreferenceStoreProvider.overrideWithValue(speechPreferenceStore),
        voiceNoteStorageServiceProvider.overrideWithValue(_FakeStorage()),
        voicePlaybackServiceProvider.overrideWithValue(
          NoopVoicePlaybackService(),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('shows voice note player when reminder has voice note', (
    tester,
  ) async {
    final now = DateTime.now();
    final reminder = Reminder(
      id: 'voice-call-1',
      title: 'Call Doctor',
      scheduledDateTime: now,
      voiceNotePath: 'doctor_note.m4a',
      voiceNoteDuration: const Duration(seconds: 15),
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    expect(find.byType(VoiceNotePlayerWidget), findsOneWidget);
    expect(find.text('0:15'), findsOneWidget);
  });

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

  group('reading a reminder aloud', () {
    testWidgets('speaks the title and its note when asked', (tester) async {
      final reminder = dueReminder();
      await repository.saveReminder(reminder);

      await tester.pumpWidget(
        wrap(ReminderCallScreen(reminderId: reminder.id)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Read aloud'));
      await tester.tap(find.text('Read aloud'));
      await tester.pumpAndSettle();

      expect(speech.spoken, [
        'Take evening medication. With a full glass of water',
      ]);
    });

    testWidgets('stays quiet until asked by default', (tester) async {
      final reminder = dueReminder();
      await repository.saveReminder(reminder);

      await tester.pumpWidget(
        wrap(ReminderCallScreen(reminderId: reminder.id)),
      );
      await tester.pumpAndSettle();

      expect(speech.spoken, isEmpty);
    });

    testWidgets('speaks automatically when the setting is on', (tester) async {
      speechPreferenceStore.enabled = true;
      final reminder = dueReminder();
      await repository.saveReminder(reminder);

      await tester.pumpWidget(
        wrap(ReminderCallScreen(reminderId: reminder.id)),
      );
      await tester.pumpAndSettle();

      expect(speech.spoken, [
        'Take evening medication. With a full glass of water',
      ]);
    });

    testWidgets('hides the control when the device cannot speak', (
      tester,
    ) async {
      speech.available = false;
      final reminder = dueReminder();
      await repository.saveReminder(reminder);

      await tester.pumpWidget(
        wrap(ReminderCallScreen(reminderId: reminder.id)),
      );
      await tester.pumpAndSettle();

      // No dead button, and no unexplained silence either.
      expect(find.text('Read aloud'), findsNothing);
      expect(find.textContaining('no speech engine installed'), findsNothing);
    });

    testWidgets('explains when the setting is on but the device cannot speak', (
      tester,
    ) async {
      speech.available = false;
      speechPreferenceStore.enabled = true;
      final reminder = dueReminder();
      await repository.saveReminder(reminder);

      await tester.pumpWidget(
        wrap(ReminderCallScreen(reminderId: reminder.id)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('no speech engine installed'), findsOneWidget);
    });

    testWidgets('stops speaking when the alert is closed', (tester) async {
      final reminder = dueReminder();
      await repository.saveReminder(reminder);

      await tester.pumpWidget(
        wrap(ReminderCallScreen(reminderId: reminder.id)),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(speech.stops, greaterThanOrEqualTo(1));
    });
  });
}

class _FakeSpeech implements ReminderSpeechService {
  bool available = true;
  final List<String> spoken = [];
  int stops = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class _FakeSpeechPreferenceStore implements SpeechPreferenceStore {
  bool? enabled;

  @override
  Future<bool?> readSpokenRemindersEnabled() async => enabled;

  @override
  Future<void> writeSpokenRemindersEnabled(bool value) async {
    enabled = value;
  }
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
