import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_alarm_id.dart';

void main() {
  group('ReminderAlarmId', () {
    test('a snooze alarm id maps back to its reminder', () {
      expect(snoozeAlarmId('abc'), 'abc::snooze');
      expect(reminderIdFromAlarmId('abc::snooze'), 'abc');
    });

    test('a plain reminder id is unchanged', () {
      expect(reminderIdFromAlarmId('abc'), 'abc');
    });

    test('an id that only looks like a suffix is not mangled', () {
      expect(reminderIdFromAlarmId('::snooze'), '');
      expect(reminderIdFromAlarmId('a::snooze::snooze'), 'a');
    });
  });
}
