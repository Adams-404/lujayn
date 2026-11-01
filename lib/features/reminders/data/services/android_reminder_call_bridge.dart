import 'package:flutter/services.dart';

import '../../domain/models/reminder_alarm_id.dart';
import '../../domain/services/reminder_call_bridge.dart';

/// Android bridge for reminders the system opened from an alarm notification.
class AndroidReminderCallBridge implements ReminderCallBridge {
  AndroidReminderCallBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methods =
           methodChannel ?? const MethodChannel('com.lujayn/reminder_alarms'),
       _events =
           eventChannel ??
           const EventChannel('com.lujayn/reminder_call_events');

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  Future<ReminderCallRequest?> takeLaunchRequest() async {
    final payload = await _methods.invokeMapMethod<String, Object?>(
      'takePendingReminderCall',
    );
    return _parse(payload);
  }

  @override
  Stream<ReminderCallRequest> get requests => _events
      .receiveBroadcastStream()
      .map((event) => _parse(event is Map ? event : null))
      .where((request) => request != null)
      .cast<ReminderCallRequest>();

  ReminderCallRequest? _parse(Map<Object?, Object?>? payload) {
    final id = payload?['id'];
    if (id is! String || id.isEmpty) return null;
    return ReminderCallRequest(reminderId: reminderIdFromAlarmId(id));
  }
}
