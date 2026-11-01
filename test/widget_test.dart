import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/app.dart';
import 'package:lujayn/app/theme/app_theme.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themePreferenceStoreProvider.overrideWithValue(
              _MemoryThemePreferenceStore(),
            ),
          ],
          child: const LujaynApp(),
        ),
      );
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

      await tester.pumpWidget(const ProviderScope(child: LujaynApp()));
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

      await tester.pumpWidget(const ProviderScope(child: LujaynApp()));
      await tester.pumpAndSettle();

      // Tap FAB
      await tester.tap(find.text('Add reminder'));
      await tester.pumpAndSettle();

      // Verify form screen
      expect(find.text('What would you like to remember?'), findsOneWidget);
      expect(find.text('Notes or details (optional)'), findsOneWidget);
      expect(find.text('Repeat schedule'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Try saving without entering title -> validation fails
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter what you need to remember'),
        findsOneWidget,
      );

      // Enter a valid title
      await tester.enterText(
        find.byType(TextFormField).first,
        'Evening chamomile tea',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should return to Home screen and display the new reminder
      expect(find.text('Upcoming reminders'), findsOneWidget);
      expect(find.text('Evening chamomile tea'), findsOneWidget);
    });
  });
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
