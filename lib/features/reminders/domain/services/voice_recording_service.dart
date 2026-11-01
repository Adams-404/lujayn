/// Abstract contract for recording voice notes for reminders on-device.
///
/// Implementations must never upload audio anywhere.
abstract class VoiceRecordingService {
  /// Whether microphone permission has already been granted.
  Future<bool> hasPermission();

  /// Requests microphone permission from the user.
  Future<bool> requestPermission();

  /// Starts recording audio to [targetFilePath].
  Future<void> startRecording(String targetFilePath);

  /// Stops recording and returns the path to the recorded file.
  Future<String?> stopRecording();

  /// Cancels and discards the in-progress recording.
  Future<void> cancelRecording();

  /// Whether a recording is currently active.
  Future<bool> isRecording();
}
