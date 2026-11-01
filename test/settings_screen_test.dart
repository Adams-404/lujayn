import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/theme/app_theme.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/data/services/noop_voice_note_storage_service.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/settings/presentation/controllers/settings_providers.dart';
import 'package:lujayn/features/settings/presentation/screens/settings_screen.dart';

void main() {
  late MockReminderRepository repository;
  late _MemoryThemeStore themeStore;
  late _MemorySpeechStore speechStore;

  setUp(() {
    repository = MockReminderRepository(preloadSampleData: true);
    themeStore = _MemoryThemeStore();
    speechStore = _MemorySpeechStore();
  });

  tearDown(() {
    repository.dispose();
  });

  Widget wrap({
    AppThemeChoice themeChoice = AppThemeChoice.silver,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
        reminderAlarmSchedulerProvider.overrideWithValue(
          const _StubAlarmScheduler(),
        ),
        voiceNoteStorageServiceProvider.overrideWithValue(
          const NoopVoiceNoteStorageService(),
        ),
        themePreferenceStoreProvider.overrideWithValue(themeStore),
        speechPreferenceStoreProvider.overrideWithValue(speechStore),
      ],
      child: MaterialApp(
        theme: AppTheme.forChoice(themeChoice),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const SettingsScreen(),
        ),
      ),
    );
  }

  testWidgets('renders all settings sections and controls', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Privacy by default'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('VOICE & AUDIO'), findsOneWidget);
    expect(find.text('DELIVERY & PERMISSIONS'), findsOneWidget);
    expect(find.text('DATA & PRIVACY'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);

    expect(find.text('Reminder voice'), findsOneWidget);
    expect(find.text('Read reminders aloud'), findsOneWidget);
    expect(find.text('Product principles'), findsOneWidget);
    expect(find.text('Data persistence'), findsOneWidget);
    expect(find.text('Clear all reminders'), findsOneWidget);
    expect(find.text('Lujayn'), findsOneWidget);
  });

  testWidgets('can open and close Product Principles dialog', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Product principles'));
    await tester.pumpAndSettle();

    expect(find.text('Product Principles'), findsOneWidget);
    expect(find.text('1. Privacy by default'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('1. Privacy by default'), findsNothing);
  });

  testWidgets('clear all reminders confirmation flow works', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect((await repository.getReminders()).isNotEmpty, isTrue);

    // Tap clear all reminders
    await tester.tap(find.text('Clear all reminders'));
    await tester.pumpAndSettle();

    expect(find.text('Clear all reminders?'), findsOneWidget);

    // Cancel first
    await tester.tap(find.text('Keep reminders'));
    await tester.pumpAndSettle();

    expect(find.text('Clear all reminders?'), findsNothing);
    expect((await repository.getReminders()).isNotEmpty, isTrue);

    // Open again and confirm
    await tester.tap(find.text('Clear all reminders'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect((await repository.getReminders()).isEmpty, isTrue);
  });

  testWidgets('renders cleanly without overflow at 200% text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('renders across all five themes without error', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final themeChoice in [
      AppThemeChoice.silver,
      AppThemeChoice.paper,
      AppThemeChoice.sage,
      AppThemeChoice.dusk,
      AppThemeChoice.amoled,
    ]) {
      await tester.pumpWidget(wrap(themeChoice: themeChoice));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Settings'), findsOneWidget);
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

class _MemoryThemeStore implements ThemePreferenceStore {
  String? value;

  @override
  Future<String?> readThemeChoice() async => value;

  @override
  Future<void> writeThemeChoice(String value) async {
    this.value = value;
  }
}

class _MemorySpeechStore implements SpeechPreferenceStore {
  bool? enabled;

  @override
  Future<bool?> readSpokenRemindersEnabled() async => enabled;

  @override
  Future<void> writeSpokenRemindersEnabled(bool value) async {
    enabled = value;
  }
}
