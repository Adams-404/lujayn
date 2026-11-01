import '../../domain/services/voice_recording_service.dart';

/// No-op recording service for tests and unsupported platforms.
class NoopVoiceRecordingService implements VoiceRecordingService {
  const NoopVoiceRecordingService({this.permissionGranted = true});

  final bool permissionGranted;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> startRecording(String targetFilePath) async {}

  @override
  Future<String?> stopRecording() async => null;

  @override
  Future<void> cancelRecording() async {}

  @override
  Future<bool> isRecording() async => false;
}
