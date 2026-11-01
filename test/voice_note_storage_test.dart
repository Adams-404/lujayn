import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/data/services/app_support_voice_note_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late AppSupportVoiceNoteStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lujayn_voice_test_');
    storage = AppSupportVoiceNoteStorage(
      baseDirectoryResolver: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('creates recordings directory inside base directory', () async {
    final dirPath = await storage.getRecordingsDirectory();
    expect(await Directory(dirPath).exists(), isTrue);
    expect(p.basename(dirPath), 'recordings');
  });

  test('resolvePath resolves relative file names to recordings dir', () async {
    final resolved = await storage.resolvePath('note_1.m4a');
    final dirPath = await storage.getRecordingsDirectory();
    expect(resolved, p.join(dirPath, 'note_1.m4a'));
  });

  test('resolvePath preserves absolute paths', () async {
    const absolute = '/tmp/custom/file.m4a';
    final resolved = await storage.resolvePath(absolute);
    expect(resolved, absolute);
  });

  test('generateNewRecordingPath creates path ending in .m4a', () async {
    final path = await storage.generateNewRecordingPath(reminderId: 'rem123');
    expect(path.endsWith('.m4a'), isTrue);
    expect(path, contains('rem_rem123_'));
  });

  test('deleteRecording deletes existing file', () async {
    final recordingsDir = await storage.getRecordingsDirectory();
    final testFile = File(p.join(recordingsDir, 'test_del.m4a'));
    await testFile.writeAsString('audio-bytes');
    expect(await testFile.exists(), isTrue);

    await storage.deleteRecording('test_del.m4a');
    expect(await testFile.exists(), isFalse);
  });

  test('cleanupOrphanedRecordings removes only unreferenced files', () async {
    final recordingsDir = await storage.getRecordingsDirectory();
    final active1 = File(p.join(recordingsDir, 'active1.m4a'));
    final active2 = File(p.join(recordingsDir, 'active2.m4a'));
    final orphan1 = File(p.join(recordingsDir, 'orphan1.m4a'));
    final orphan2 = File(p.join(recordingsDir, 'orphan2.m4a'));

    await active1.writeAsString('audio1');
    await active2.writeAsString('audio2');
    await orphan1.writeAsString('orphan1');
    await orphan2.writeAsString('orphan2');

    final cleaned = await storage.cleanupOrphanedRecordings([
      'active1.m4a',
      p.join(recordingsDir, 'active2.m4a'),
    ]);

    expect(cleaned, 2);
    expect(await active1.exists(), isTrue);
    expect(await active2.exists(), isTrue);
    expect(await orphan1.exists(), isFalse);
    expect(await orphan2.exists(), isFalse);
  });

  test('clearAllRecordings removes all files in directory', () async {
    final recordingsDir = await storage.getRecordingsDirectory();
    final file1 = File(p.join(recordingsDir, 'file1.m4a'));
    await file1.writeAsString('data');

    await storage.clearAllRecordings();
    expect(await file1.exists(), isFalse);
  });
}
