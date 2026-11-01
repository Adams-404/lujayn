/// Platform contract for reading a reminder aloud.
///
/// Speech is an accessibility aid first and a convenience second, so it must
/// never be the only way to receive a reminder. Every method is safe to call
/// when the platform has no speech engine: [isAvailable] reports that honestly
/// and the rest become no-ops.
abstract interface class ReminderSpeechService {
  /// Whether this device can speak at all right now.
  ///
  /// A device can lose its engine (uninstalled, disabled, or no language data
  /// downloaded), so this is asked before offering speech rather than assumed
  /// once at startup.
  Future<bool> isAvailable();

  /// Speaks [text], replacing anything already being spoken.
  Future<void> speak(String text);

  /// Stops any speech in progress. Must be safe to call when nothing is playing.
  Future<void> stop();
}
