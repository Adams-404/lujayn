import '../../domain/services/reminder_speech_service.dart';

/// Fallback used on platforms without a speech engine and in tests.
///
/// It reports itself unavailable rather than silently pretending to speak, so
/// the interface can hide the control instead of offering a dead button.
class NoopReminderSpeechService implements ReminderSpeechService {
  const NoopReminderSpeechService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
