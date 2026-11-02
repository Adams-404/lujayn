import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/theme/app_theme.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/features/reminders/domain/models/natural_language_draft.dart';
import 'package:lujayn/features/reminders/presentation/widgets/natural_language_draft_sheet.dart';

void main() {
  Widget buildSubject({
    required void Function(NaturalLanguageDraft) onDraftConfirmed,
    AppThemeChoice themeChoice = AppThemeChoice.system,
    double textScaleFactor = 1.0,
  }) {
    return MaterialApp(
      theme: AppTheme.forChoice(themeChoice),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScaleFactor),
            size: const Size(600, 1000),
          ),
          child: NaturalLanguageDraftSheet(onDraftConfirmed: onDraftConfirmed),
        ),
      ),
    );
  }

  testWidgets('renders input and initial state', (tester) async {
    await tester.pumpWidget(buildSubject(onDraftConfirmed: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Draft with plain language'), findsOneWidget);
    expect(find.text('Call Mum tomorrow at 6'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
    'typing updates interpreted draft preview and triggers confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      NaturalLanguageDraft? confirmed;
      await tester.pumpWidget(
        buildSubject(onDraftConfirmed: (draft) => confirmed = draft),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Remind me to call Mum tomorrow at 6');
      await tester.pumpAndSettle();

      final button = find.text('Open in Reminder Form to Confirm');
      expect(button, findsOneWidget);

      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(confirmed, isNotNull);
      expect(confirmed!.callerName, equals('Mom'));
    },
  );

  testWidgets('renders without overflow at 200% text scale', (tester) async {
    await tester.pumpWidget(
      buildSubject(onDraftConfirmed: (_) {}, textScaleFactor: 2.0),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  for (final themeChoice in AppThemeChoice.values) {
    testWidgets('renders across theme ${themeChoice.name} without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(onDraftConfirmed: (_) {}, themeChoice: themeChoice),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
