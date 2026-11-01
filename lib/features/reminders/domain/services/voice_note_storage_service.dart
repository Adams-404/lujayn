/// Abstract contract for managing local voice note files on disk.
///
/// Keeps audio files in app-private storage, stores only stable relative
/// file names in persistence, and cleans up orphaned files.
abstract class VoiceNoteStorageService {
  /// Root directory for recordings in app-private storage.
  Future<String> getRecordingsDirectory();

  /// Resolves a stored relative filename into a full filesystem path.
  Future<String> resolvePath(String fileName);

  /// Generates a unique destination path for a new voice note.
  Future<String> generateNewRecordingPath({String? reminderId});

  /// Deletes a recording by its filename or path if it exists on disk.
  Future<void> deleteRecording(String fileName);

  /// Deletes any file in the recordings directory not referenced in [activeFileNames].
  ///
  /// Returns the number of orphaned files cleaned up.
  Future<int> cleanupOrphanedRecordings(List<String> activeFileNames);

  /// Removes all voice note recordings from disk.
  Future<void> clearAllRecordings();
}
