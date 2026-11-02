import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/domain/services/natural_language_reminder_parser.dart';

void main() {
  const parser = NaturalLanguageReminderParser();
  final fixedNow = DateTime(2026, 11, 2, 10, 0); // Monday Nov 2, 2026 10:00 AM

  group('NaturalLanguageReminderParser', () {
    test('parses "Remind me to call Mum tomorrow at 6"', () {
      final draft = parser.parse(
        'Remind me to call Mum tomorrow at 6',
        now: fixedNow,
      );

      expect(draft.title.toLowerCase(), contains('call mum'));
      expect(draft.callerName, equals('Mom'));
      expect(draft.callerIcon, equals('favorite_rounded'));
      expect(draft.scheduledDateTime?.year, equals(2026));
      expect(draft.scheduledDateTime?.month, equals(11));
      expect(draft.scheduledDateTime?.day, equals(3)); // Tomorrow
      expect(draft.scheduledDateTime?.hour, equals(18)); // 6 PM
      expect(draft.recurrence, equals(RecurrenceRule.none));
      expect(draft.isAmbiguous, isFalse);
    });

    test('parses "Every Monday and Thursday at 8, take my vitamins"', () {
      final draft = parser.parse(
        'Every Monday and Thursday at 8, take my vitamins',
        now: fixedNow,
      );

      expect(draft.title.toLowerCase(), contains('take my vitamins'));
      expect(draft.recurrence.type, equals(RecurrenceType.customDays));
      expect(
        draft.recurrence.daysOfWeek,
        equals([DateTime.monday, DateTime.thursday]),
      );
      expect(draft.scheduledDateTime?.hour, equals(8));
      expect(draft.isAmbiguous, isFalse);
    });

    test('parses "Daily at noon check mail"', () {
      final draft = parser.parse('Daily at noon check mail', now: fixedNow);

      expect(draft.title.toLowerCase(), contains('check mail'));
      expect(draft.recurrence, equals(RecurrenceRule.daily));
      expect(draft.scheduledDateTime?.hour, equals(12));
      expect(draft.scheduledDateTime?.minute, equals(0));
    });

    test('parses "Dentist appointment next Friday at 2:30 pm"', () {
      final draft = parser.parse(
        'Dentist appointment next Friday at 2:30 pm',
        now: fixedNow,
      );

      expect(draft.title.toLowerCase(), contains('dentist appointment'));
      expect(draft.scheduledDateTime?.weekday, equals(DateTime.friday));
      expect(draft.scheduledDateTime?.hour, equals(14));
      expect(draft.scheduledDateTime?.minute, equals(30));
    });

    test('parses relative time "Walk the dog in 30 minutes"', () {
      final draft = parser.parse('Walk the dog in 30 minutes', now: fixedNow);

      expect(draft.title.toLowerCase(), contains('walk the dog'));
      expect(
        draft.scheduledDateTime,
        equals(fixedNow.add(const Duration(minutes: 30))),
      );
      expect(draft.recurrence, equals(RecurrenceRule.none));
    });

    test('handles empty or blank input as ambiguous', () {
      final draft = parser.parse('   ', now: fixedNow);

      expect(draft.title, isEmpty);
      expect(draft.isAmbiguous, isTrue);
      expect(draft.confidence, equals(0.0));
    });

    test('provides explanations for interpreted components', () {
      final draft = parser.parse(
        'Call doctor tomorrow in the afternoon',
        now: fixedNow,
      );

      expect(draft.explanations, isNotEmpty);
      expect(draft.callerName, equals('Doctor'));
      expect(draft.callerIcon, equals('local_hospital_rounded'));
    });
  });
}
