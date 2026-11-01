import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/theme/app_theme.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/data/services/noop_voice_playback_service.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';
import 'package:lujayn/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/domain/services/voice_note_storage_service.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/reminders/presentation/screens/reminder_detail_screen.dart';
import 'package:lujayn/features/reminders/presentation/widgets/voice_note_player_widget.dart';

class _FakeDetailStorage implements VoiceNoteStorageService {
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

  setUp(() {
    repository = MockReminderRepository(preloadSampleData: false);
  });

  tearDown(() {
    repository.dispose();
  });

  Widget wrap({
    required String reminderId,
    ReminderRepository? repo,
    AppThemeChoice themeChoice = AppThemeChoice.silver,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo ?? repository),
        reminderAlarmSchedulerProvider.overrideWithValue(
          const _StubAlarmScheduler(),
        ),
        voiceNoteStorageServiceProvider.overrideWithValue(_FakeDetailStorage()),
        voicePlaybackServiceProvider.overrideWithValue(
          NoopVoicePlaybackService(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.forChoice(themeChoice),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: ReminderDetailScreen(reminderId: reminderId),
        ),
      ),
    );
  }

  final testReminder = Reminder(
    id: 'test-reminder-1',
    title: 'Evening Blood Pressure Check',
    description: 'Use the left arm cuff and rest 5 minutes first.',
    scheduledDateTime: DateTime(2026, 11, 10, 19, 30),
    recurrence: const RecurrenceRule(type: RecurrenceType.daily),
    status: ReminderStatus.active,
    createdAt: DateTime(2026, 11, 1, 8, 0),
    updatedAt: DateTime(2026, 11, 1, 8, 0),
  );

  testWidgets('displays reminder details cleanly', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await repository.saveReminder(testReminder);

    await tester.pumpWidget(wrap(reminderId: testReminder.id));
    await tester.pumpAndSettle();

    expect(find.text('Evening Blood Pressure Check'), findsOneWidget);
    expect(
      find.text('Use the left arm cuff and rest 5 minutes first.'),
      findsOneWidget,
    );
    expect(find.text('Active Reminder'), findsOneWidget);
    expect(find.text('Daily'), findsWidgets);
    expect(find.text('Scheduled For'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Mark as Completed'), findsOneWidget);
    expect(find.text('Delete Reminder'), findsOneWidget);
  });

  testWidgets('renders voice note player when reminder has voice note', (
    tester,
  ) async {
    final withVoice = testReminder.copyWith(
      id: 'voice-detail-1',
      voiceNotePath: 'med_instructions.m4a',
      voiceNoteDuration: const Duration(seconds: 22),
    );
    await repository.saveReminder(withVoice);

    await tester.pumpWidget(wrap(reminderId: withVoice.id));
    await tester.pumpAndSettle();

    expect(find.byType(VoiceNotePlayerWidget), findsOneWidget);
    expect(find.text('0:22'), findsOneWidget);
  });

  testWidgets('toggles status to completed and back', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await repository.saveReminder(testReminder);

    await tester.pumpWidget(wrap(reminderId: testReminder.id));
    await tester.pumpAndSettle();

    // Mark as completed
    await tester.tap(find.text('Mark as Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Mark as Active'), findsOneWidget);

    // Mark back to active
    await tester.tap(find.text('Mark as Active'));
    await tester.pumpAndSettle();

    expect(find.text('Active Reminder'), findsOneWidget);
    expect(find.text('Mark as Completed'), findsOneWidget);
  });

  testWidgets('delete button opens confirmation and deletes on confirm', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await repository.saveReminder(testReminder);

    await tester.pumpWidget(wrap(reminderId: testReminder.id));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete Reminder'));
    await tester.pumpAndSettle();

    // Verify dialog appeared
    expect(find.text('Delete reminder?'), findsOneWidget);
    expect(
      find.text('Remove “Evening Blood Pressure Check” from your reminders?'),
      findsOneWidget,
    );

    // Cancel first
    await tester.tap(find.text('Keep reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Delete reminder?'), findsNothing);
    expect(await repository.getReminderById(testReminder.id), isNotNull);

    // Open dialog again and confirm delete
    await tester.tap(find.text('Delete Reminder'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await repository.getReminderById(testReminder.id), isNull);
  });

  testWidgets('renders not found state when reminder does not exist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(reminderId: 'non-existent-id'));
    await tester.pumpAndSettle();

    expect(find.text('Reminder not found'), findsOneWidget);
    expect(find.text('Back to reminders'), findsOneWidget);
  });

  testWidgets('renders cleanly without overflow at 200% text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await repository.saveReminder(
      testReminder.copyWith(
        recurrence: const RecurrenceRule(
          type: RecurrenceType.customDays,
          daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        ),
      ),
    );

    await tester.pumpWidget(wrap(reminderId: testReminder.id, textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Evening Blood Pressure Check'), findsOneWidget);
  });

  testWidgets('renders across all five themes without error', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await repository.saveReminder(testReminder);

    for (final themeChoice in [
      AppThemeChoice.silver,
      AppThemeChoice.paper,
      AppThemeChoice.sage,
      AppThemeChoice.dusk,
      AppThemeChoice.amoled,
    ]) {
      await tester.pumpWidget(
        wrap(reminderId: testReminder.id, themeChoice: themeChoice),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Evening Blood Pressure Check'), findsOneWidget);
    }
  });
}

class _StubAlarmScheduler implements ReminderAlarmScheduler {
  const _StubAlarmScheduler();

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
