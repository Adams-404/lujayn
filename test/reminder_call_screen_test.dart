import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/theme/app_theme.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/features/reminders/data/services/noop_voice_playback_service.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_ringtone_service.dart';
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
  late _FakeRingtone ringtone;

  setUp(() {
    repository = MockReminderRepository(preloadSampleData: false);
    scheduler = _RecordingAlarmScheduler();
    speech = _FakeSpeech();
    speechPreferenceStore = _FakeSpeechPreferenceStore();
    ringtone = _FakeRingtone();
  });

  tearDown(() {
    repository.dispose();
  });

  /// The call screen is a tall column. A 600 px test window would push the
  /// answer and decline buttons out of reach, so every test uses a phone-sized
  /// portrait window instead. Reduce-motion is on because the ringing badge
  /// pulses forever, which would stop `pumpAndSettle` from ever settling.
  void useCallScreenWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

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

  Widget wrap(Widget child, {AppThemeChoice? themeChoice}) {
    return ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
        reminderAlarmSchedulerProvider.overrideWithValue(scheduler),
        reminderSpeechServiceProvider.overrideWithValue(speech),
        reminderRingtoneServiceProvider.overrideWithValue(ringtone),
        speechPreferenceStoreProvider.overrideWithValue(speechPreferenceStore),
        voiceNoteStorageServiceProvider.overrideWithValue(_FakeStorage()),
        voicePlaybackServiceProvider.overrideWithValue(
          NoopVoicePlaybackService(),
        ),
      ],
      child: MaterialApp(
        theme: themeChoice != null ? AppTheme.forChoice(themeChoice) : null,
        home: child,
      ),
    );
  }

  testWidgets('shows voice note player when reminder has voice note', (
    tester,
  ) async {
    useCallScreenWindow(tester);
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
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    expect(find.text('INCOMING CALL'), findsOneWidget);
    expect(find.text('Take evening medication'), findsOneWidget);
    expect(find.text('With a full glass of water'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Snooze for 10 minutes'), findsOneWidget);
  });

  testWidgets('starts ringing as soon as the reminder is presented', (
    tester,
  ) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    expect(ringtone.started, ['due']);
  });

  testWidgets('snoozing schedules a separate alarm and stops ringing', (
    tester,
  ) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Snooze for 10 minutes'));
    await tester.pumpAndSettle();

    expect(scheduler.scheduled.single.reminderId, 'due::snooze');
    expect(ringtone.stopCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('declining dismisses a one-time reminder and stops ringing', (
    tester,
  ) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(
      (await repository.getReminderById(reminder.id))!.status,
      ReminderStatus.completed,
    );
    expect(ringtone.stopCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('an unanswered call turns into an honest missed call', (
    tester,
  ) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    // The ring timeout is what stops a phone ringing in someone's pocket.
    await tester.pump(const Duration(seconds: 61));

    expect(find.text('MISSED CALL'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Answer'), findsNothing);
  });

  testWidgets('completing a one-time reminder cancels its alarm', (
    tester,
  ) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Answer'));
    await tester.pump();
    await tester.tap(find.text('Keypad'));
    await tester.pump();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(
      (await repository.getReminderById(reminder.id))!.status,
      ReminderStatus.completed,
    );
    expect(scheduler.cancelled, contains('due'));
  });

  testWidgets('explains a reminder that no longer exists', (tester) async {
    useCallScreenWindow(tester);
    await tester.pumpWidget(wrap(const ReminderCallScreen(reminderId: 'gone')));
    await tester.pumpAndSettle();

    expect(find.text('Reminder not found'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('renders incoming call simulation with caller persona', (
    tester,
  ) async {
    useCallScreenWindow(tester);
    final now = DateTime.now();
    final reminder = Reminder(
      id: 'persona-call',
      title: 'Pick up dry cleaning',
      callerName: 'Mom ❤️',
      callerNumber: 'Mobile • (555) 019-2831',
      callerIcon: 'family',
      scheduledDateTime: now,
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    expect(find.text('INCOMING CALL'), findsOneWidget);
    expect(find.text('Mom ❤️'), findsOneWidget);
    expect(find.text('Mobile • (555) 019-2831'), findsOneWidget);
    expect(find.text('Pick up dry cleaning'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
  });

  testWidgets('renders incoming call simulation with caller profile photo', (
    tester,
  ) async {
    useCallScreenWindow(tester);
    final now = DateTime.now();
    final reminder = Reminder(
      id: 'photo-call',
      title: 'Water the plants',
      callerName: 'Mom ❤️',
      callerNumber: 'Mobile',
      callerIcon: 'family',
      callerImagePath: 'mom_avatar.jpg',
      scheduledDateTime: now,
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    expect(find.text('Mom ❤️'), findsOneWidget);
    expect(find.text('Mobile'), findsOneWidget);
    expect(find.text('Water the plants'), findsOneWidget);
  });

  testWidgets('answering connects, stops ringing and offers the keypad', (
    tester,
  ) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Answer'));
    await tester.pump();

    expect(find.textContaining('CONNECTED'), findsOneWidget);
    expect(find.text('In call'), findsOneWidget);
    expect(find.text('Keypad'), findsOneWidget);
    expect(find.text('Hang up'), findsOneWidget);
    expect(ringtone.stopCalls, greaterThanOrEqualTo(1));

    await tester.tap(find.text('Keypad'));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('Done'), findsWidgets);
  });

  testWidgets('autoAnswer opens call screen directly in connected state', (
    tester,
  ) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(
      wrap(ReminderCallScreen(reminderId: reminder.id, autoAnswer: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keypad'), findsOneWidget);
    expect(find.text('Answer'), findsNothing);
    expect(find.text('Decline'), findsNothing);
    expect(ringtone.started, isEmpty);
  });

  testWidgets('dialpad key 1 marks reminder completed', (tester) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Answer'));
    await tester.pump();
    await tester.tap(find.text('Keypad'));
    await tester.pump();

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(
      (await repository.getReminderById(reminder.id))!.status,
      ReminderStatus.completed,
    );
    expect(scheduler.cancelled, contains('due'));
  });

  testWidgets('dialpad key 2 snoozes the reminder', (tester) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Answer'));
    await tester.pump();
    await tester.tap(find.text('Keypad'));
    await tester.pump();

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();

    expect(scheduler.scheduled.single.reminderId, 'due::snooze');
  });

  testWidgets('hang up button ends the call', (tester) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Answer'));
    await tester.pump();

    expect(find.text('Hang up'), findsOneWidget);
    await tester.tap(find.text('Hang up'));
    await tester.pumpAndSettle();

    // Hanging up keeps the reminder active but releases the ring and speech.
    expect(ringtone.stopCalls, greaterThanOrEqualTo(1));
    expect(speech.stops, greaterThanOrEqualTo(1));
  });

  testWidgets('answering call speaks message with dialpad instruction', (
    tester,
  ) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    await tester.pumpWidget(wrap(ReminderCallScreen(reminderId: reminder.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Answer'));
    await tester.pump();
    await tester.pump();

    expect(speech.spoken, [
      'Take evening medication. With a full glass of water. Press 1 for done, 2 to reschedule, or 3 to keep active.',
    ]);
  });

  testWidgets('call screen renders across all five themes', (tester) async {
    useCallScreenWindow(tester);
    final reminder = dueReminder();
    await repository.saveReminder(reminder);

    for (final theme in AppThemeChoice.values) {
      await tester.pumpWidget(
        wrap(ReminderCallScreen(reminderId: reminder.id), themeChoice: theme),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReminderCallScreen), findsOneWidget);
      expect(find.text('Answer'), findsOneWidget);
    }
  });

  group('reading a reminder aloud', () {
    testWidgets('speaks the title and its note when asked', (tester) async {
      useCallScreenWindow(tester);
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
      useCallScreenWindow(tester);
      final reminder = dueReminder();
      await repository.saveReminder(reminder);

      await tester.pumpWidget(
        wrap(ReminderCallScreen(reminderId: reminder.id)),
      );
      await tester.pumpAndSettle();

      expect(speech.spoken, isEmpty);
    });

    testWidgets('speaks automatically when the setting is on', (tester) async {
      useCallScreenWindow(tester);
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
      useCallScreenWindow(tester);
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
      useCallScreenWindow(tester);
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
      useCallScreenWindow(tester);
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

class _FakeRingtone implements ReminderRingtoneService {
  final List<String> started = [];
  int stopCalls = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> startRinging(String reminderId) async {
    started.add(reminderId);
  }

  @override
  Future<void> stopRinging() async {
    stopCalls++;
  }

  @override
  Future<List<RingtoneOption>> availableRingtones() async => const [];

  @override
  Future<String?> selectedRingtoneId() async => null;

  @override
  Future<void> selectRingtone(String? id) async {}

  @override
  Future<void> previewRingtone(String? id) async {}

  @override
  Future<void> stopPreview() async {}
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
