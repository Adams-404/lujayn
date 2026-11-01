import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';

void main() {
  group('RecurrenceRule.calculateNextOccurrence', () {
    test('a one-time reminder returns its own time', () {
      final when = DateTime(2026, 3, 4, 8, 30);
      expect(
        RecurrenceRule.none.calculateNextOccurrence(
          when,
          after: DateTime(2027, 1, 1),
        ),
        when,
      );
    });

    test('daily advances to the next day once the time has passed', () {
      final base = DateTime(2026, 3, 4, 8, 30);
      final next = RecurrenceRule.daily.calculateNextOccurrence(
        base,
        after: DateTime(2026, 3, 4, 9),
      );
      expect(next, DateTime(2026, 3, 5, 8, 30));
    });

    test('daily keeps the wall-clock time across a DST boundary', () {
      // Europe/London springs forward on 2026-03-29.
      final base = DateTime(2026, 3, 27, 8, 0);
      final next = RecurrenceRule.daily.calculateNextOccurrence(
        base,
        after: DateTime(2026, 3, 28, 9, 0),
      );
      expect(next.hour, 8);
      expect(next.minute, 0);
      expect(next, DateTime(2026, 3, 29, 8, 0));
    });

    test('weekly advances by whole weeks', () {
      final base = DateTime(2026, 3, 2, 7, 0);
      final next = RecurrenceRule.weekly.calculateNextOccurrence(
        base,
        after: DateTime(2026, 3, 2, 8),
      );
      expect(next, DateTime(2026, 3, 9, 7, 0));
    });

    test('weekdays skips the weekend', () {
      // 2026-03-06 is a Friday.
      final base = DateTime(2026, 3, 6, 9, 0);
      final next = RecurrenceRule.weekdays.calculateNextOccurrence(
        base,
        after: DateTime(2026, 3, 6, 10),
      );
      expect(next.weekday, DateTime.monday);
      expect(next, DateTime(2026, 3, 9, 9, 0));
    });

    test('custom days picks the next configured weekday', () {
      // 2026-03-02 is a Monday; configured for Wednesday and Saturday.
      final rule = const RecurrenceRule(
        type: RecurrenceType.customDays,
        daysOfWeek: [DateTime.wednesday, DateTime.saturday],
      );
      final next = rule.calculateNextOccurrence(
        DateTime(2026, 3, 2, 6, 0),
        after: DateTime(2026, 3, 2, 7),
      );
      expect(next.weekday, DateTime.wednesday);
      expect(next, DateTime(2026, 3, 4, 6, 0));
    });

    test('an empty custom day list does not search', () {
      final base = DateTime(2026, 3, 2, 6, 0);
      final rule = const RecurrenceRule(type: RecurrenceType.customDays);
      expect(
        rule.calculateNextOccurrence(base, after: DateTime(2026, 6, 1)),
        base,
      );
    });

    test('an out-of-range custom day list is treated as no recurrence', () {
      final base = DateTime(2026, 3, 2, 6, 0);
      final rule = const RecurrenceRule(
        type: RecurrenceType.customDays,
        daysOfWeek: [0, 8, 99],
      );
      // No valid weekday exists, so there is no next occurrence. The call must
      // return rather than search forever.
      expect(
        rule.calculateNextOccurrence(base, after: DateTime(2026, 3, 2, 7)),
        base,
      );
    });

    test('a reminder beyond the lookahead is dropped, not re-armed', () {
      final base = DateTime(1990, 1, 1, 9, 0);
      final now = DateTime(2026, 3, 2, 7);
      final next = RecurrenceRule.daily.calculateNextOccurrence(
        base,
        after: now,
      );
      // Bounded search gives up instead of walking 13,000 days.
      expect(next.isAfter(now), isFalse);
    });
  });
}
