/// A reminder that the platform wants shown as a focused, call-style alert.
class ReminderCallRequest {
  const ReminderCallRequest({required this.reminderId});

  final String reminderId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderCallRequest && other.reminderId == reminderId;

  @override
  int get hashCode => reminderId.hashCode;
}

/// Hands a due reminder from the platform layer to the presentation layer.
///
/// Android shows a full-screen intent when it is allowed to, and a notification
/// otherwise. Both paths land here, so the app can present one consistent
/// call-style surface without promising behaviour the OS may refuse.
abstract interface class ReminderCallBridge {
  /// The reminder that launched the app, if the app was started by an alarm.
  ///
  /// Reading clears the stored request so it is presented only once.
  Future<ReminderCallRequest?> takeLaunchRequest();

  /// Requests raised while the app is already running.
  Stream<ReminderCallRequest> get requests;
}
