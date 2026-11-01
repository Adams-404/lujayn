import '../../domain/services/reminder_alarm_scheduler.dart';
import '../../domain/services/reminder_schedule_planner.dart';

/// Safe fallback for platforms without the Android alarm bridge.
class NoopReminderAlarmScheduler implements ReminderAlarmScheduler {
  const NoopReminderAlarmScheduler();

  @override
  Future<bool> canScheduleExactAlarms() async => false;

  @override
  Future<bool> requestExactAlarmPermission() async => false;

  @override
  Future<void> schedule(ReminderSchedule schedule) async {}

  @override
  Future<void> cancel(String reminderId) async {}

  @override
  Future<void> cancelAll() async {}
}
