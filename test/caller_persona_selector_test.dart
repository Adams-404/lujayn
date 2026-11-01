import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/theme/app_theme.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/features/reminders/data/services/noop_caller_image_service.dart';
import 'package:lujayn/features/reminders/domain/services/caller_image_service.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/reminders/presentation/widgets/caller_persona_selector.dart';

void main() {
  Widget wrap(
    Widget child, {
    AppThemeChoice theme = AppThemeChoice.silver,
    CallerImageService? callerImageService,
  }) {
    return ProviderScope(
      overrides: [
        if (callerImageService != null)
          callerImageServiceProvider.overrideWithValue(callerImageService),
      ],
      child: MaterialApp(
        theme: AppTheme.forChoice(theme),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  testWidgets('renders idle state with None chip selected by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        CallerPersonaSelector(
          initialName: null,
          initialNumber: null,
          initialIcon: null,
          onChanged:
              ({callerName, callerNumber, callerIcon, callerImagePath}) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Simulated Caller'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Family / Mom'), findsOneWidget);
    expect(find.text('Doctor / Clinic'), findsOneWidget);
    expect(find.text('Caller Name'), findsNothing);
  });

  testWidgets('selecting Family / Mom preset populates fields and notifies', (
    tester,
  ) async {
    String? capturedName;
    String? capturedNumber;
    String? capturedIcon;

    await tester.pumpWidget(
      wrap(
        CallerPersonaSelector(
          initialName: null,
          initialNumber: null,
          initialIcon: null,
          onChanged: ({callerName, callerNumber, callerIcon, callerImagePath}) {
            capturedName = callerName;
            capturedNumber = callerNumber;
            capturedIcon = callerIcon;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Family / Mom'));
    await tester.pumpAndSettle();

    expect(capturedName, 'Mom ❤️');
    expect(capturedNumber, 'Mobile');
    expect(capturedIcon, 'family');

    expect(find.text('Caller Name'), findsOneWidget);
    expect(find.text('Mom ❤️'), findsOneWidget);
    expect(find.text('Mobile'), findsOneWidget);
  });

  testWidgets('clearing persona resets state and notifies nulls', (
    tester,
  ) async {
    String? capturedName = 'Initial';

    await tester.pumpWidget(
      wrap(
        CallerPersonaSelector(
          initialName: 'Dr. Collins',
          initialNumber: 'Clinic',
          initialIcon: 'medical',
          onChanged: ({callerName, callerNumber, callerIcon, callerImagePath}) {
            capturedName = callerName;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dr. Collins'), findsOneWidget);

    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();

    expect(capturedName, isNull);
    expect(find.text('Caller Name'), findsNothing);
  });

  testWidgets(
    'picking and removing caller profile image updates state and notifies',
    (tester) async {
      String? capturedImagePath;
      const stubService = NoopCallerImageService(
        stubImagePath: 'custom_avatar.jpg',
      );

      await tester.pumpWidget(
        wrap(
          CallerPersonaSelector(
            initialName: 'Mom ❤️',
            initialNumber: 'Mobile',
            initialIcon: 'family',
            onChanged:
                ({callerName, callerNumber, callerIcon, callerImagePath}) {
                  capturedImagePath = callerImagePath;
                },
          ),
          callerImageService: stubService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose photo'), findsOneWidget);
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();

      expect(capturedImagePath, 'custom_avatar.jpg');
      expect(find.text('Change photo'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(capturedImagePath, isNull);
      expect(find.text('Choose photo'), findsOneWidget);
    },
  );

  testWidgets('renders across all five themes without error', (tester) async {
    for (final theme in AppThemeChoice.values) {
      await tester.pumpWidget(
        wrap(
          CallerPersonaSelector(
            initialName: 'Mom ❤️',
            initialNumber: 'Mobile',
            initialIcon: 'family',
            onChanged:
                ({callerName, callerNumber, callerIcon, callerImagePath}) {},
          ),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
