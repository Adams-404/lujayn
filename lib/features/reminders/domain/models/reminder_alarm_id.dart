/// Android alarm ids are a reminder id plus an optional delivery suffix.
///
/// A snooze is a separate one-off alarm so a recurring series keeps its
/// original anchor time. That means the platform can hand back an id the
/// reminder store has never seen, and the presentation layer must map it to
/// the reminder the user actually created.
const _snoozeSuffix = '::snooze';

/// The alarm id used for a snooze of [reminderId].
String snoozeAlarmId(String reminderId) => '$reminderId$_snoozeSuffix';

/// The reminder id behind an alarm id, with any delivery suffix removed.
String reminderIdFromAlarmId(String alarmId) {
  final index = alarmId.indexOf(_snoozeSuffix);
  return index == -1 ? alarmId : alarmId.substring(0, index);
}
