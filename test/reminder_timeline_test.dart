import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/theme/app_theme.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/reminders/presentation/screens/home_screen.dart';

void main() {
  testWidgets('home presents the next reminder and a readable timeline', (
    tester,
  ) async {
    final repository = MockReminderRepository(preloadSampleData: true);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.forChoice(AppThemeChoice.silver),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsAtLeastNWidgets(1));
    expect(find.text('NEXT REMINDER'), findsOneWidget);
    expect(find.text('Add reminder'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('ALL REMINDERS'), findsOneWidget);
  });

  testWidgets(
    'home header and segmented filter bar render across all five themes without error',
    (tester) async {
      for (final choice in AppThemeChoice.values) {
        final repository = MockReminderRepository(preloadSampleData: true);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              reminderRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              theme: AppTheme.forChoice(choice),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Today'), findsAtLeastNWidgets(1));
        expect(find.text('Upcoming'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
        expect(find.text('All'), findsOneWidget);
        expect(tester.takeException(), isNull);

        repository.dispose();
      }
    },
  );

  testWidgets(
    'home header and segmented filter bar render without overflow at 200% text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repository = MockReminderRepository(preloadSampleData: true);
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [reminderRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: AppTheme.forChoice(AppThemeChoice.amoled),
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Today'), findsAtLeastNWidgets(1));
      expect(find.text('Upcoming'), findsOneWidget);
    },
  );
}
