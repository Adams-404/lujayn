import 'package:flutter/services.dart';

import '../../domain/services/reminder_alarm_scheduler.dart';
import '../../domain/services/reminder_schedule_planner.dart';

/// Android implementation backed by the native AlarmManager bridge.
class AndroidReminderAlarmScheduler implements ReminderAlarmScheduler {
  AndroidReminderAlarmScheduler({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.lujayn/reminder_alarms');

  final MethodChannel _channel;

  @override
  Future<bool> canScheduleExactAlarms() async {
    return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ??
        false;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    return await _channel.invokeMethod<bool>('requestExactAlarmPermission') ??
        false;
  }

  @override
  Future<bool> canPostNotifications() async {
    return await _channel.invokeMethod<bool>('canPostNotifications') ?? false;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        false;
  }

  @override
  Future<void> schedule(ReminderSchedule schedule) {
    return _channel.invokeMethod<void>('schedule', {
      'id': schedule.reminderId,
      'title': schedule.title,
      'description': schedule.description,
      'scheduledAtMillis': schedule.scheduledAt.millisecondsSinceEpoch,
      'localYear': schedule.scheduledAt.year,
      'localMonth': schedule.scheduledAt.month,
      'localDay': schedule.scheduledAt.day,
      'localHour': schedule.scheduledAt.hour,
      'localMinute': schedule.scheduledAt.minute,
      'recurrenceType': schedule.recurrence.type.name,
      'daysOfWeek': schedule.recurrence.daysOfWeek,
    });
  }

  @override
  Future<void> cancel(String reminderId) {
    return _channel.invokeMethod<void>('cancel', {'id': reminderId});
  }

  @override
  Future<void> cancelAll() {
    return _channel.invokeMethod<void>('cancelAll');
  }
}
