import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/app.dart';
import 'package:lujayn/core/widgets/responsive_center.dart';
import 'package:lujayn/app/theme/app_theme.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/core/database/app_database.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/data/repositories/drift_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/settings/presentation/controllers/settings_providers.dart';

void main() {
  group('Theme selection', () {
    test('AMOLED uses a true black app background', () {
      final theme = AppTheme.forChoice(AppThemeChoice.amoled);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(theme.colorScheme.surface, const Color(0xFF050505));
    });

    test('the five named palettes have distinct accent colours', () {
      final choices = [
        AppThemeChoice.silver,
        AppThemeChoice.paper,
        AppThemeChoice.sage,
        AppThemeChoice.dusk,
        AppThemeChoice.amoled,
      ];
      final accents = choices.map(AppTheme.accentFor).toSet();
      expect(accents.length, 5);
    });

    test('selected theme is restored from local preferences', () async {
      final store = _MemoryThemePreferenceStore();
      final firstContainer = ProviderContainer(
        overrides: [themePreferenceStoreProvider.overrideWithValue(store)],
      );
      expect(
        await firstContainer.read(themeChoiceProvider.future),
        AppThemeChoice.system,
      );
      await firstContainer
          .read(themeChoiceProvider.notifier)
          .select(AppThemeChoice.amoled);
      firstContainer.dispose();

      final restartedContainer = ProviderContainer(
        overrides: [themePreferenceStoreProvider.overrideWithValue(store)],
      );
      expect(
        await restartedContainer.read(themeChoiceProvider.future),
        AppThemeChoice.amoled,
      );
      restartedContainer.dispose();
    });
  });
  group('DriftReminderRepository Tests', () {
    test('persists reminder data after the database is reopened', () async {
      final directory = await Directory.systemTemp.createTemp('lujayn-db-');
      final file = File('${directory.path}/reminders.sqlite');
      final reminder = Reminder(
        id: 'persistent-reminder',
        title: 'Take evening medication',
        description: 'With water after dinner',
        scheduledDateTime: DateTime(2026, 11, 3, 20, 15),
        recurrence: RecurrenceRule(
          type: RecurrenceType.customDays,
          daysOfWeek: [1, 3, 5],
        ),
        status: ReminderStatus.snoozed,
        createdAt: DateTime(2026, 11, 1, 8),
        updatedAt: DateTime(2026, 11, 1, 8),
      );

      final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));
      final firstRepository = DriftReminderRepository(firstDatabase);
      await firstRepository.saveReminder(reminder);
      await firstDatabase.close();

      final reopenedDatabase = AppDatabase.forTesting(NativeDatabase(file));
      final reopenedRepository = DriftReminderRepository(reopenedDatabase);
      final restored = await reopenedRepository.getReminderById(
        'persistent-reminder',
      );

      expect(restored, equals(reminder));
      await reopenedDatabase.close();
      await directory.delete(recursive: true);
    });

    test(
      'streams changes and orders active reminders before completed ones',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final repository = DriftReminderRepository(database);
        final now = DateTime(2026, 11, 1, 10);

        final completed = Reminder(
          id: 'completed',
          title: 'Already done',
          scheduledDateTime: now.subtract(const Duration(hours: 1)),
          status: ReminderStatus.completed,
          createdAt: now,
          updatedAt: now,
          completedAt: now,
        );
        final active = Reminder(
          id: 'active',
          title: 'Still to do',
          scheduledDateTime: now.add(const Duration(hours: 1)),
          createdAt: now,
          updatedAt: now,
        );

        await repository.saveReminder(completed);
        await repository.saveReminder(active);
        final streamed = await repository.watchReminders().first;

        expect(streamed.map((item) => item.id), ['active', 'completed']);
        await database.close();
      },
    );

    test('toggles completion and deletes a reminder', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DriftReminderRepository(database);
      final now = DateTime(2026, 11, 1, 9);
      final reminder = Reminder(
        id: 'toggle-me',
        title: 'Water the plants',
        scheduledDateTime: now,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveReminder(reminder);
      await repository.toggleReminderStatus(reminder.id);
      final completed = await repository.getReminderById(reminder.id);
      expect(completed?.status, ReminderStatus.completed);
      expect(completed?.completedAt, isNotNull);

      await repository.deleteReminder(reminder.id);
      expect(await repository.getReminderById(reminder.id), isNull);
      await database.close();
    });
  });

  group('RecurrenceRule Unit Tests', () {
    test('One-time reminder does not change scheduled date', () {
      final scheduled = DateTime(2026, 11, 1, 9, 0);
      final next = RecurrenceRule.none.calculateNextOccurrence(scheduled);
      expect(next, equals(scheduled));
      expect(RecurrenceRule.none.isRecurring, isFalse);
    });

    test('Daily recurrence advances to the next day after reference', () {
      final scheduled = DateTime(2026, 11, 1, 8, 0);
      final reference = DateTime(2026, 11, 1, 12, 0);

      final next = RecurrenceRule.daily.calculateNextOccurrence(
        scheduled,
        after: reference,
      );

      expect(next.year, equals(2026));
      expect(next.month, equals(11));
      expect(next.day, equals(2));
      expect(next.hour, equals(8));
      expect(next.minute, equals(0));
    });

    test('Weekdays recurrence skips Saturday and Sunday', () {
      // Friday Nov 6, 2026 at 20:00
      final friday = DateTime(2026, 11, 6, 20, 0);
      expect(friday.weekday, equals(DateTime.friday));

      final reference = DateTime(2026, 11, 6, 21, 0);

      final next = RecurrenceRule.weekdays.calculateNextOccurrence(
        friday,
        after: reference,
      );

      // Should advance to Monday Nov 9, 2026
      expect(next.weekday, equals(DateTime.monday));
      expect(next.day, equals(9));
      expect(next.hour, equals(20));
    });

    test('Weekly recurrence advances exactly 7 days', () {
      final base = DateTime(2026, 11, 1, 10, 0);
      final reference = DateTime(2026, 11, 1, 11, 0);

      final next = RecurrenceRule.weekly.calculateNextOccurrence(
        base,
        after: reference,
      );

      expect(next, equals(DateTime(2026, 11, 8, 10, 0)));
    });
  });

  group('MockReminderRepository Tests', () {
    late MockReminderRepository repository;

    setUp(() {
      repository = MockReminderRepository(preloadSampleData: true);
    });

    tearDown(() {
      repository.dispose();
    });

    test('Preloads 5 curated sample reminders', () async {
      final reminders = await repository.getReminders();
      expect(reminders.length, equals(5));
      expect(reminders.any((r) => r.title.contains('blood pressure')), isTrue);
    });

    test('Toggles reminder status between active and completed', () async {
      final reminders = await repository.getReminders();
      final target = reminders.firstWhere((r) => r.isActive);

      await repository.toggleReminderStatus(target.id);

      final updated = await repository.getReminderById(target.id);
      expect(updated, isNotNull);
      expect(updated!.status, equals(ReminderStatus.completed));
      expect(updated.completedAt, isNotNull);

      // Toggle back to active
      await repository.toggleReminderStatus(target.id);
      final reverted = await repository.getReminderById(target.id);
      expect(reverted!.status, equals(ReminderStatus.active));
      expect(reverted.completedAt, isNull);
    });

    test('Can save a new reminder and retrieve it', () async {
      final newReminder = Reminder(
        id: 'test-123',
        title: 'Meditation practice',
        scheduledDateTime: DateTime(2026, 11, 1, 19, 0),
        recurrence: RecurrenceRule.daily,
        status: ReminderStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.saveReminder(newReminder);
      final found = await repository.getReminderById('test-123');
      expect(found, isNotNull);
      expect(found!.title, equals('Meditation practice'));
    });

    test('Can delete a reminder', () async {
      final reminders = await repository.getReminders();
      final idToDelete = reminders.first.id;

      await repository.deleteReminder(idToDelete);
      final found = await repository.getReminderById(idToDelete);
      expect(found, isNull);
    });

    test('Reset reloads the initial sample data', () async {
      await repository.clearAllReminders();
      expect((await repository.getReminders()).length, equals(0));

      await repository.resetToSampleData();
      expect((await repository.getReminders()).length, equals(5));
    });
  });

  group('Lujayn Application Shell & Navigation Widget Tests', () {
    testWidgets('App renders the Today timeline and primary action', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      // Check header and titles
      expect(find.text('Today'), findsAtLeastNWidgets(1));
      expect(find.text('NEXT REMINDER'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);

      // Check Floating Action Button
      expect(find.text('Add reminder'), findsOneWidget);

      // Check Navigation Bar items
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Check that sample reminders appear
      expect(find.text('Morning blood pressure check'), findsOneWidget);
      expect(find.text('Call Mom'), findsOneWidget);
    });

    testWidgets('Can navigate to Settings screen and open Product Principles', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      // Tap Settings navigation tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Verify Settings screen loaded
      expect(find.text('Privacy by default'), findsOneWidget);
      expect(find.text('Product principles'), findsOneWidget);
      expect(find.text('Data persistence'), findsOneWidget);

      // Tap Product Principles
      await tester.tap(find.text('Product principles'));
      await tester.pumpAndSettle();

      // Verify modal dialog appeared with principles
      expect(find.text('Product Principles'), findsOneWidget);
      expect(find.text('1. Privacy by default'), findsOneWidget);
      expect(find.text('2. Local-first'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('1. Privacy by default'), findsNothing);
    });

    testWidgets('Can open New Reminder screen from FAB', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      // Tap FAB
      await tester.tap(find.text('Add reminder'));
      await tester.pumpAndSettle();

      // Temporary layout diagnostics for the failing form navigation test.
      final formFinder = find.byType(Form);
      final listFinder = find.byType(ListView);
      final centerFinder = find.byType(ResponsiveCenter);
      debugPrint('FORM DIAGNOSTIC: Form count=${formFinder.evaluate().length}');
      debugPrint('FORM DIAGNOSTIC: ListView count=${listFinder.evaluate().length}');
      debugPrint(
        'FORM DIAGNOSTIC: ResponsiveCenter count=${centerFinder.evaluate().length}',
      );
      if (formFinder.evaluate().isNotEmpty) {
        debugPrint('FORM DIAGNOSTIC: Form size=${tester.getSize(formFinder)}');
      }
      if (listFinder.evaluate().isNotEmpty) {
        debugPrint('FORM DIAGNOSTIC: ListView size=${tester.getSize(listFinder)}');
      }
      debugPrint(
        'FORM DIAGNOSTIC: heading count=${find.text('What do you need to remember?').evaluate().length}',
      );

      // Verify the form content is laid out and the title is required.
      expect(find.text('New reminder'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter what you need to remember'),
        findsOneWidget,
      );
    });
  });
}

Widget _testApp() {
  return ProviderScope(
    overrides: [
      themePreferenceStoreProvider.overrideWithValue(
        _MemoryThemePreferenceStore(),
      ),
      reminderRepositoryProvider.overrideWith((ref) {
        final repository = MockReminderRepository(preloadSampleData: true);
        ref.onDispose(repository.dispose);
        return repository;
      }),
    ],
    child: const LujaynApp(),
  );
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
