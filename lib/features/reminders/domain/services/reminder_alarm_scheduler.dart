import 'reminder_schedule_planner.dart';

/// Platform contract for scheduling local reminder alarms.
abstract interface class ReminderAlarmScheduler {
  /// Whether Android currently allows exact alarms for this application.
  Future<bool> canScheduleExactAlarms();

  /// Opens Android's exact-alarm settings when access is not already granted.
  Future<bool> requestExactAlarmPermission();

  /// Replaces any existing alarm for [schedule.reminderId].
  Future<void> schedule(ReminderSchedule schedule);

  /// Cancels the alarm identified by [reminderId].
  Future<void> cancel(String reminderId);

  /// Cancels every alarm previously registered by this application.
  Future<void> cancelAll();
}
