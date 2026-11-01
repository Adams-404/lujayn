import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/services/voice_note_storage_service.dart';

/// App-private storage for reminder voice recordings.
///
/// Saves audio in `<app support>/recordings/` so the OS cache-cleaner will
/// never delete user voice recordings. Stored filenames are relative basenames.
class AppSupportVoiceNoteStorage implements VoiceNoteStorageService {
  AppSupportVoiceNoteStorage({
    Future<Directory> Function()? baseDirectoryResolver,
  }) : _baseDirectoryResolver =
           baseDirectoryResolver ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDirectoryResolver;
  static const _uuid = Uuid();

  @override
  Future<String> getRecordingsDirectory() async {
    final base = await _baseDirectoryResolver();
    final dir = Directory(p.join(base.path, 'recordings'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  @override
  Future<String> resolvePath(String fileName) async {
    if (p.isAbsolute(fileName)) return fileName;
    final recordingsDir = await getRecordingsDirectory();
    return p.join(recordingsDir, p.basename(fileName));
  }

  @override
  Future<String> generateNewRecordingPath({String? reminderId}) async {
    final recordingsDir = await getRecordingsDirectory();
    final uniqueId = _uuid.v4();
    final prefix = reminderId != null ? 'rem_${reminderId}_' : 'rec_';
    return p.join(recordingsDir, '$prefix$uniqueId.m4a');
  }

  @override
  Future<void> deleteRecording(String fileName) async {
    try {
      final fullPath = await resolvePath(fileName);
      final file = File(fullPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Deletion is best-effort.
    }
  }

  @override
  Future<int> cleanupOrphanedRecordings(List<String> activeFileNames) async {
    try {
      final recordingsDirPath = await getRecordingsDirectory();
      final dir = Directory(recordingsDirPath);
      if (!await dir.exists()) return 0;

      final activeBasenames = activeFileNames.map(p.basename).toSet();
      var cleanedCount = 0;

      await for (final entity in dir.list()) {
        if (entity is File) {
          final baseName = p.basename(entity.path);
          if (!activeBasenames.contains(baseName)) {
            await entity.delete();
            cleanedCount++;
          }
        }
      }
      return cleanedCount;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> clearAllRecordings() async {
    try {
      final recordingsDirPath = await getRecordingsDirectory();
      final dir = Directory(recordingsDirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
