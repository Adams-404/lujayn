import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/theme/app_theme.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/features/reminders/presentation/widgets/caller_persona_selector.dart';

void main() {
  Widget wrap(Widget child, {AppThemeChoice theme = AppThemeChoice.silver}) {
    return MaterialApp(
      theme: AppTheme.forChoice(theme),
      home: Scaffold(body: SingleChildScrollView(child: child)),
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
          onChanged: ({callerName, callerNumber, callerIcon}) {},
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
          onChanged: ({callerName, callerNumber, callerIcon}) {
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
          onChanged: ({callerName, callerNumber, callerIcon}) {
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

  testWidgets('renders across all five themes without error', (tester) async {
    for (final theme in AppThemeChoice.values) {
      await tester.pumpWidget(
        wrap(
          CallerPersonaSelector(
            initialName: 'Mom ❤️',
            initialNumber: 'Mobile',
            initialIcon: 'family',
            onChanged: ({callerName, callerNumber, callerIcon}) {},
          ),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
