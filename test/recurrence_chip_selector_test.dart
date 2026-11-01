import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/presentation/widgets/recurrence_chip_selector.dart';

void main() {
  testWidgets('custom recurrence lets the user choose individual weekdays', (
    tester,
  ) async {
    var selectedRule = RecurrenceRule.none;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RecurrenceChipSelector(
                selectedRule: selectedRule,
                onChanged: (rule) => setState(() => selectedRule = rule),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Custom days'));
    await tester.pumpAndSettle();

    expect(selectedRule.type, RecurrenceType.customDays);
    expect(selectedRule.daysOfWeek, [DateTime.monday]);
    expect(find.text('Select repeating days:'), findsOneWidget);

    await tester.tap(find.text('T').first);
    await tester.pumpAndSettle();

    expect(selectedRule.daysOfWeek, [DateTime.monday, DateTime.tuesday]);
  });
}
