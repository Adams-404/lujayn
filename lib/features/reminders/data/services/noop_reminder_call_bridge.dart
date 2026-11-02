import '../../domain/services/reminder_call_bridge.dart';

/// Fallback for platforms without an alarm-driven call surface.
class NoopReminderCallBridge implements ReminderCallBridge {
  const NoopReminderCallBridge();

  @override
  Future<ReminderCallRequest?> takeLaunchRequest() async => null;

  @override
  Stream<ReminderCallRequest> get requests => const Stream.empty();

  @override
  Future<List<String>> takeDeclinedReminderIds() async => const [];
}
