import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/backup/data/services/aes_backup_vault_service.dart';
import 'package:lujayn/features/backup/domain/models/backup_manifest.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';
import 'package:lujayn/features/reminders/domain/services/caller_image_service.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/domain/services/voice_note_storage_service.dart';
import 'package:path/path.dart' as p;

class _TestVoiceNoteStorage implements VoiceNoteStorageService {
  _TestVoiceNoteStorage(this.baseDir);
  final Directory baseDir;

  @override
  Future<String> getRecordingsDirectory() async {
    final dir = Directory(p.join(baseDir.path, 'recordings'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  @override
  Future<String> resolvePath(String fileName) async {
    final dir = await getRecordingsDirectory();
    return p.join(dir, p.basename(fileName));
  }

  @override
  Future<String> generateNewRecordingPath({String? reminderId}) async {
    final dir = await getRecordingsDirectory();
    return p.join(dir, 'rec_$reminderId.m4a');
  }

  @override
  Future<void> deleteRecording(String fileName) async {}
  @override
  Future<void> clearAllRecordings() async {}
  @override
  Future<int> cleanupOrphanedRecordings(List<String> activeFileNames) async =>
      0;
}

class _TestCallerImageService implements CallerImageService {
  _TestCallerImageService(this.baseDir);
  final Directory baseDir;

  Future<String> getImagesDirectory() async {
    final dir = Directory(p.join(baseDir.path, 'caller_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  @override
  Future<String> resolvePath(String fileNameOrPath) async {
    if (p.isAbsolute(fileNameOrPath)) return fileNameOrPath;
    final dir = await getImagesDirectory();
    return p.join(dir, p.basename(fileNameOrPath));
  }

  @override
  Future<void> deleteImage(String fileNameOrPath) async {}

  @override
  Future<void> clearAllImages() async {}

  @override
  Future<String?> pickAndStoreImage() async => null;
}

class _TestAlarmScheduler implements ReminderAlarmScheduler {
  final List<String> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<bool> canPostNotifications() async => true;
  @override
  Future<bool> canScheduleExactAlarms() async => true;
  @override
  Future<bool> requestExactAlarmPermission() async => true;
  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<void> schedule(ReminderSchedule schedule) async {
    scheduled.add(schedule.reminderId);
  }

  @override
  Future<void> cancel(String reminderId) async {
    cancelled.add(reminderId);
  }

  @override
  Future<void> cancelAll() async {}
}

void main() {
  late Directory tempDir;
  late MockReminderRepository repository;
  late _TestVoiceNoteStorage voiceStorage;
  late _TestCallerImageService callerImageService;
  late _TestAlarmScheduler alarmScheduler;
  late AesBackupVaultService vault;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lujayn_backup_test_');
    repository = MockReminderRepository(preloadSampleData: false);
    voiceStorage = _TestVoiceNoteStorage(tempDir);
    callerImageService = _TestCallerImageService(tempDir);
    alarmScheduler = _TestAlarmScheduler();

    vault = AesBackupVaultService(
      reminderRepository: repository,
      voiceNoteStorage: voiceStorage,
      callerImageService: callerImageService,
      alarmScheduler: alarmScheduler,
      baseDirectoryResolver: () async => tempDir,
      pbkdf2Iterations: 1000, // fast iterations for tests
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'creates encrypted backup and restores round-trip in replace mode',
    () async {
      // 1. Create dummy audio file
      final recDir = await voiceStorage.getRecordingsDirectory();
      final audioFile = File(p.join(recDir, 'note1.m4a'));
      await audioFile.writeAsString('audio bytes payload 123');

      // 2. Create dummy caller image file
      final imgDir = await callerImageService.getImagesDirectory();
      final imgFile = File(p.join(imgDir, 'mum.jpg'));
      await imgFile.writeAsString('image bytes jpeg');

      // 3. Add reminder to repository
      final reminder1 = Reminder(
        id: 'rem-1',
        title: 'Take medicine',
        description: 'With a glass of water',
        scheduledDateTime: DateTime.now().add(const Duration(hours: 2)),
        recurrence: const RecurrenceRule(
          type: RecurrenceType.daily,
          daysOfWeek: [1, 2, 3, 4, 5],
        ),
        status: ReminderStatus.active,
        voiceNotePath: 'note1.m4a',
        voiceNoteDuration: const Duration(seconds: 15),
        callerName: 'Mum',
        callerNumber: '08012345678',
        callerImagePath: imgFile.path,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveReminder(reminder1);

      // 4. Create encrypted backup
      final exportResult = await vault.createBackup(
        passphrase: 'correct-horse-battery',
      );
      expect(File(exportResult.filePath).existsSync(), isTrue);
      expect(exportResult.manifest.reminderCount, equals(1));
      expect(exportResult.manifest.recordingCount, equals(1));
      expect(exportResult.manifest.callerPhotoCount, equals(1));

      // 5. Inspect backup without restoring
      final inspected = await vault.inspectBackup(
        filePath: exportResult.filePath,
        passphrase: 'correct-horse-battery',
      );
      expect(inspected.reminderCount, equals(1));
      expect(inspected.recordingCount, equals(1));
      expect(inspected.callerPhotoCount, equals(1));

      // 6. Clear repository to simulate new phone / clean slate
      await repository.clearAllReminders();
      expect((await repository.getReminders()).isEmpty, isTrue);

      // 7. Restore from backup
      final restoreResult = await vault.restoreBackup(
        filePath: exportResult.filePath,
        passphrase: 'correct-horse-battery',
        mode: RestoreMode.replace,
      );
      expect(restoreResult.restoredCount, equals(1));

      // 8. Verify reminder content
      final restoredReminders = await repository.getReminders();
      expect(restoredReminders.length, equals(1));
      final restored = restoredReminders.first;
      expect(restored.id, equals('rem-1'));
      expect(restored.title, equals('Take medicine'));
      expect(restored.description, equals('With a glass of water'));
      expect(restored.recurrence.type, equals(RecurrenceType.daily));
      expect(restored.recurrence.daysOfWeek, equals([1, 2, 3, 4, 5]));
      expect(restored.callerName, equals('Mum'));

      // 9. Verify audio note file was restored
      final restoredAudioPath = await voiceStorage.resolvePath(
        restored.voiceNotePath!,
      );
      expect(File(restoredAudioPath).existsSync(), isTrue);
      expect(
        await File(restoredAudioPath).readAsString(),
        equals('audio bytes payload 123'),
      );

      // 10. Verify image was restored
      expect(File(restored.callerImagePath!).existsSync(), isTrue);
      expect(
        await File(restored.callerImagePath!).readAsString(),
        equals('image bytes jpeg'),
      );

      // 11. Verify future alarm was scheduled
      expect(alarmScheduler.scheduled.contains('rem-1'), isTrue);
    },
  );

  test(
    'restoring with wrong passphrase throws InvalidBackupPassphraseException',
    () async {
      final reminder = Reminder(
        id: 'rem-secret',
        title: 'Top Secret Reminder',
        scheduledDateTime: DateTime.now().add(const Duration(hours: 1)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveReminder(reminder);

      final exportResult = await vault.createBackup(
        passphrase: 'correct-passphrase-123',
      );

      expect(
        () => vault.inspectBackup(
          filePath: exportResult.filePath,
          passphrase: 'wrong-passphrase',
        ),
        throwsA(isA<InvalidBackupPassphraseException>()),
      );

      expect(
        () => vault.restoreBackup(
          filePath: exportResult.filePath,
          passphrase: 'wrong-passphrase',
          mode: RestoreMode.replace,
        ),
        throwsA(isA<InvalidBackupPassphraseException>()),
      );
    },
  );

  test('restoring corrupted or tampered backup throws an error', () async {
    final reminder = Reminder(
      id: 'rem-tamper',
      title: 'Tamper test',
      scheduledDateTime: DateTime.now().add(const Duration(hours: 1)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.saveReminder(reminder);

    final exportResult = await vault.createBackup(passphrase: 'my-secret-key');

    // Corrupt the file by writing junk
    final file = File(exportResult.filePath);
    await file.writeAsString('not a valid json envelope');

    expect(
      () => vault.inspectBackup(
        filePath: exportResult.filePath,
        passphrase: 'my-secret-key',
      ),
      throwsA(isA<InvalidBackupFileException>()),
    );
  });

  test(
    'restoring in merge mode preserves existing reminders without collisions',
    () async {
      final existingReminder = Reminder(
        id: 'existing-rem',
        title: 'Existing Reminder',
        scheduledDateTime: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveReminder(existingReminder);

      final backupReminder = Reminder(
        id: 'existing-rem', // colliding ID
        title: 'Imported Reminder with same ID',
        scheduledDateTime: DateTime.now().add(const Duration(days: 2)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      // Create a temporary vault to export the backup
      final tempRepo = MockReminderRepository(preloadSampleData: false);
      await tempRepo.saveReminder(backupReminder);

      final tempVault = AesBackupVaultService(
        reminderRepository: tempRepo,
        voiceNoteStorage: voiceStorage,
        callerImageService: callerImageService,
        alarmScheduler: alarmScheduler,
        baseDirectoryResolver: () async => tempDir,
        pbkdf2Iterations: 1000,
      );

      final exportResult = await tempVault.createBackup(
        passphrase: 'merge-passphrase',
      );

      // Restore into repository with merge mode
      await vault.restoreBackup(
        filePath: exportResult.filePath,
        passphrase: 'merge-passphrase',
        mode: RestoreMode.merge,
      );

      final all = await repository.getReminders();
      expect(all.length, equals(2));
      expect(all.any((r) => r.title == 'Existing Reminder'), isTrue);
      expect(
        all.any((r) => r.title == 'Imported Reminder with same ID'),
        isTrue,
      );
    },
  );

  test('lists available backups in descending chronological order', () async {
    await repository.saveReminder(
      Reminder(
        id: 'rem-list',
        title: 'Test',
        scheduledDateTime: DateTime.now().add(const Duration(hours: 1)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await vault.createBackup(passphrase: 'list-pass');
    final backups = await vault.listAvailableBackups();
    expect(backups.length, equals(1));
    expect(backups.first.endsWith('.lujaynbackup'), isTrue);
  });
}
