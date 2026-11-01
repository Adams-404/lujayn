import '../../domain/services/voice_note_storage_service.dart';

/// No-op voice note storage service for tests and unsupported platforms.
class NoopVoiceNoteStorageService implements VoiceNoteStorageService {
  const NoopVoiceNoteStorageService();

  @override
  Future<String> getRecordingsDirectory() async => '/mock/recordings';

  @override
  Future<String> resolvePath(String fileName) async => fileName;

  @override
  Future<String> generateNewRecordingPath({String? reminderId}) async =>
      '/mock/recordings/note.m4a';

  @override
  Future<void> deleteRecording(String fileName) async {}

  @override
  Future<int> cleanupOrphanedRecordings(List<String> activeFileNames) async =>
      0;

  @override
  Future<void> clearAllRecordings() async {}
}
