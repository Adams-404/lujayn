import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../reminders/data/services/app_support_caller_image_service.dart';
import '../../../reminders/domain/models/recurrence_rule.dart';
import '../../../reminders/domain/models/reminder.dart';
import '../../../reminders/domain/models/reminder_status.dart';
import '../../../reminders/domain/repositories/reminder_repository.dart';
import '../../../reminders/domain/services/caller_image_service.dart';
import '../../../reminders/domain/services/reminder_alarm_scheduler.dart';
import '../../../reminders/domain/services/reminder_schedule_planner.dart';
import '../../../reminders/domain/services/voice_note_storage_service.dart';
import '../../domain/models/backup_manifest.dart';
import '../../domain/services/backup_vault_service.dart';

/// Production-ready backup vault using AES-256-GCM and PBKDF2-HMAC-SHA256.
///
/// Encrypts reminders, voice recordings, and caller photos into an offline,
/// self-contained `.lujaynbackup` package without any network or cloud dependency.
class AesBackupVaultService implements BackupVaultService {
  AesBackupVaultService({
    required this.reminderRepository,
    required this.voiceNoteStorage,
    required this.callerImageService,
    required this.alarmScheduler,
    ReminderSchedulePlanner? schedulePlanner,
    Future<Directory> Function()? baseDirectoryResolver,
    int? pbkdf2Iterations,
  }) : _schedulePlanner = schedulePlanner ?? const ReminderSchedulePlanner(),
       _baseDirectoryResolver =
           baseDirectoryResolver ?? getApplicationDocumentsDirectory,
       _pbkdf2Iterations = pbkdf2Iterations ?? defaultPbkdf2Iterations;

  final ReminderRepository reminderRepository;
  final VoiceNoteStorageService voiceNoteStorage;
  final CallerImageService callerImageService;
  final ReminderAlarmScheduler alarmScheduler;
  final ReminderSchedulePlanner _schedulePlanner;
  final Future<Directory> Function() _baseDirectoryResolver;
  final int _pbkdf2Iterations;

  static const int defaultPbkdf2Iterations = 100000;
  static const String backupExtension = '.lujaynbackup';
  static const String envelopeFormat = 'lujayn_encrypted_backup';
  static const int envelopeVersion = 1;

  final _aesGcm = AesGcm.with256bits();
  final _random = Random.secure();
  static const _uuid = Uuid();

  Future<Directory> getBackupDirectory() async {
    final base = await _baseDirectoryResolver();
    final dir = Directory(p.join(base.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<List<String>> listAvailableBackups() async {
    final dir = await getBackupDirectory();
    final entities = await dir.list().toList();
    final files =
        entities
            .whereType<File>()
            .where((file) => file.path.endsWith(backupExtension))
            .toList()
          ..sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );

    return files.map((f) => f.path).toList();
  }

  @override
  Future<BackupExportResult> createBackup({
    required String passphrase,
    String? targetDirectoryPath,
  }) async {
    if (passphrase.trim().isEmpty) {
      throw const InvalidBackupPassphraseException(
        'Passphrase cannot be empty.',
      );
    }

    final reminders = await reminderRepository.getReminders();
    final archive = Archive();

    int recordingCount = 0;
    int photoCount = 0;

    // 1. Package audio notes
    for (final reminder in reminders) {
      if (reminder.hasVoiceNote) {
        try {
          final resolvedPath = await voiceNoteStorage.resolvePath(
            reminder.voiceNotePath!,
          );
          final file = File(resolvedPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final arcName = 'recordings/${p.basename(resolvedPath)}';
            archive.addFile(ArchiveFile(arcName, bytes.length, bytes));
            recordingCount++;
          }
        } catch (_) {
          // Skip missing recordings gracefully without aborting backup
        }
      }

      // 2. Package caller profile images
      if (reminder.callerImagePath != null &&
          reminder.callerImagePath!.isNotEmpty) {
        try {
          final file = File(reminder.callerImagePath!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final arcName =
                'caller_images/${p.basename(reminder.callerImagePath!)}';
            archive.addFile(ArchiveFile(arcName, bytes.length, bytes));
            photoCount++;
          }
        } catch (_) {
          // Skip missing images gracefully
        }
      }
    }

    // 3. Create manifest
    final manifest = BackupManifest(
      format: BackupManifest.currentFormat,
      version: BackupManifest.currentVersion,
      createdAt: DateTime.now().toUtc(),
      appVersion: '1.0.0',
      reminderCount: reminders.length,
      recordingCount: recordingCount,
      callerPhotoCount: photoCount,
    );

    final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    // 4. Package reminders list
    final remindersJson = jsonEncode(
      reminders.map(_serializeReminder).toList(),
    );
    final remindersBytes = utf8.encode(remindersJson);
    archive.addFile(
      ArchiveFile('reminders.json', remindersBytes.length, remindersBytes),
    );

    // 5. Zip encode in memory
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    // 6. Encrypt with AES-256-GCM + PBKDF2
    final encryptedEnvelope = await _encryptData(
      Uint8List.fromList(zipBytes),
      passphrase,
    );

    // 7. Write to output file
    final Directory outDir = targetDirectoryPath != null
        ? Directory(targetDirectoryPath)
        : await getBackupDirectory();

    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final filePath = p.join(
      outDir.path,
      'lujayn_backup_$timestamp$backupExtension',
    );
    final outFile = File(filePath);
    await outFile.writeAsString(jsonEncode(encryptedEnvelope), flush: true);

    final size = await outFile.length();
    return BackupExportResult(
      filePath: filePath,
      fileSizeBytes: size,
      manifest: manifest,
    );
  }

  @override
  Future<BackupManifest> inspectBackup({
    required String filePath,
    required String passphrase,
  }) async {
    final archive = await _decryptBackupFile(filePath, passphrase);
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const InvalidBackupFileException(
        'Backup archive is missing manifest.json.',
      );
    }

    try {
      final json = jsonDecode(utf8.decode(manifestFile.content as List<int>));
      if (json is! Map<String, dynamic>) {
        throw const InvalidBackupFileException('Malformed manifest in backup.');
      }
      final manifest = BackupManifest.fromJson(json);
      if (!manifest.isValid) {
        throw InvalidBackupFileException(
          'Unsupported backup version: ${manifest.version}',
        );
      }
      return manifest;
    } catch (e) {
      if (e is InvalidBackupFileException) rethrow;
      throw InvalidBackupFileException('Cannot read manifest: $e');
    }
  }

  @override
  Future<BackupRestoreResult> restoreBackup({
    required String filePath,
    required String passphrase,
    required RestoreMode mode,
  }) async {
    final archive = await _decryptBackupFile(filePath, passphrase);

    // Read manifest
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const InvalidBackupFileException('Missing manifest in backup.');
    }
    final manifestJson = jsonDecode(
      utf8.decode(manifestFile.content as List<int>),
    );
    final manifest = BackupManifest.fromJson(
      manifestJson as Map<String, dynamic>,
    );

    // Read reminders
    final remindersFile = archive.findFile('reminders.json');
    if (remindersFile == null) {
      throw const InvalidBackupFileException('Missing reminders in backup.');
    }
    final remindersListJson = jsonDecode(
      utf8.decode(remindersFile.content as List<int>),
    );
    if (remindersListJson is! List) {
      throw const InvalidBackupFileException('Malformed reminders in backup.');
    }

    final backupReminders = remindersListJson
        .whereType<Map<String, dynamic>>()
        .map(_deserializeReminder)
        .toList();

    // Restore audio recordings
    final recordingsDir = await voiceNoteStorage.getRecordingsDirectory();
    for (final file in archive.files) {
      if (file.name.startsWith('recordings/') && !file.name.endsWith('/')) {
        final baseName = p.basename(file.name);
        final targetPath = p.join(recordingsDir, baseName);
        final outFile = File(targetPath);
        await outFile.writeAsBytes(file.content as List<int>, flush: true);
      }
    }

    // Restore caller images
    String? imagesDir;
    try {
      final imgService = callerImageService;
      if (imgService is AppSupportCallerImageService) {
        imagesDir = await imgService.getImagesDirectory();
      }
    } catch (_) {
      // Fallback if callerImageService doesn't expose directory directly
      final base = await _baseDirectoryResolver();
      imagesDir = p.join(base.path, 'caller_images');
      final dir = Directory(imagesDir);
      if (!await dir.exists()) await dir.create(recursive: true);
    }

    if (imagesDir != null) {
      for (final file in archive.files) {
        if (file.name.startsWith('caller_images/') &&
            !file.name.endsWith('/')) {
          final baseName = p.basename(file.name);
          final targetPath = p.join(imagesDir, baseName);
          final outFile = File(targetPath);
          await outFile.writeAsBytes(file.content as List<int>, flush: true);
        }
      }
    }

    // Apply reminders to repository
    final now = DateTime.now();
    if (mode == RestoreMode.replace) {
      final existing = await reminderRepository.getReminders();
      for (final rem in existing) {
        try {
          await alarmScheduler.cancel(rem.id);
        } catch (_) {}
      }
      await reminderRepository.clearAllReminders();

      for (final reminder in backupReminders) {
        final adjusted = _remapLocalPaths(reminder, recordingsDir, imagesDir);
        await reminderRepository.saveReminder(adjusted);
        final planned = _schedulePlanner.plan(adjusted, now: now);
        if (planned != null) {
          try {
            await alarmScheduler.schedule(planned);
          } catch (_) {}
        }
      }
    } else {
      // Merge mode
      final existing = await reminderRepository.getReminders();
      final existingIds = existing.map((r) => r.id).toSet();

      for (final reminder in backupReminders) {
        final isConflict = existingIds.contains(reminder.id);
        final restoredId = isConflict ? _uuid.v4() : reminder.id;
        final adjusted = _remapLocalPaths(
          reminder.copyWith(id: restoredId),
          recordingsDir,
          imagesDir,
        );
        await reminderRepository.saveReminder(adjusted);
        final planned = _schedulePlanner.plan(adjusted, now: now);
        if (planned != null) {
          try {
            await alarmScheduler.schedule(planned);
          } catch (_) {}
        }
      }
    }

    return BackupRestoreResult(
      restoredCount: backupReminders.length,
      mode: mode,
      manifest: manifest,
    );
  }

  Reminder _remapLocalPaths(
    Reminder reminder,
    String recordingsDir,
    String? imagesDir,
  ) {
    String? newVoicePath = reminder.voiceNotePath;
    if (newVoicePath != null && newVoicePath.isNotEmpty) {
      newVoicePath = p.basename(newVoicePath);
    }

    String? newImagePath = reminder.callerImagePath;
    if (newImagePath != null && newImagePath.isNotEmpty && imagesDir != null) {
      newImagePath = p.join(imagesDir, p.basename(newImagePath));
    }

    return reminder.copyWith(
      voiceNotePath: newVoicePath,
      callerImagePath: newImagePath,
    );
  }

  Future<Archive> _decryptBackupFile(String filePath, String passphrase) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw InvalidBackupFileException('File not found: $filePath');
    }

    String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      throw InvalidBackupFileException('Could not read backup file: $e');
    }

    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const InvalidBackupFileException(
          'Invalid backup file structure.',
        );
      }
      envelope = decoded;
    } catch (_) {
      throw const InvalidBackupFileException('Backup file is not valid JSON.');
    }

    if (envelope['format'] != envelopeFormat) {
      throw InvalidBackupFileException(
        'Unknown backup format: ${envelope['format']}',
      );
    }

    final kdf = envelope['kdf'] as Map<String, dynamic>? ?? {};
    final cipher = envelope['cipher'] as Map<String, dynamic>? ?? {};
    final rawData = envelope['data'] as String?;

    if (rawData == null ||
        kdf['salt'] == null ||
        cipher['nonce'] == null ||
        cipher['tag'] == null) {
      throw const InvalidBackupFileException(
        'Incomplete backup envelope headers.',
      );
    }

    final salt = base64Decode(kdf['salt'] as String);
    final iterations = (kdf['iterations'] as int?) ?? _pbkdf2Iterations;
    final nonce = base64Decode(cipher['nonce'] as String);
    final tag = base64Decode(cipher['tag'] as String);
    final ciphertext = base64Decode(rawData);

    // Key derivation
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );

    final secretKey = SecretKey(utf8.encode(passphrase));
    final derivedKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );

    // Decrypt
    final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(tag));

    Uint8List decryptedBytes;
    try {
      final bytesList = await _aesGcm.decrypt(secretBox, secretKey: derivedKey);
      decryptedBytes = Uint8List.fromList(bytesList);
    } on SecretBoxAuthenticationError {
      throw const InvalidBackupPassphraseException();
    } catch (_) {
      throw const InvalidBackupPassphraseException();
    }

    // Decode zip
    final zipDecoder = ZipDecoder();
    try {
      final archive = zipDecoder.decodeBytes(decryptedBytes);
      return archive;
    } catch (e) {
      throw InvalidBackupFileException('Corrupt zip contents in backup: $e');
    }
  }

  Future<Map<String, dynamic>> _encryptData(
    Uint8List plainBytes,
    String passphrase,
  ) async {
    final salt = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      salt[i] = _random.nextInt(256);
    }

    final nonce = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      nonce[i] = _random.nextInt(256);
    }

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );

    final secretKey = SecretKey(utf8.encode(passphrase));
    final derivedKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );

    final secretBox = await _aesGcm.encrypt(
      plainBytes,
      secretKey: derivedKey,
      nonce: nonce,
    );

    return {
      'format': envelopeFormat,
      'version': envelopeVersion,
      'kdf': {
        'algorithm': 'PBKDF2-HMAC-SHA256',
        'iterations': _pbkdf2Iterations,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'algorithm': 'AES-256-GCM',
        'nonce': base64Encode(nonce),
        'tag': base64Encode(secretBox.mac.bytes),
      },
      'data': base64Encode(secretBox.cipherText),
    };
  }

  Map<String, dynamic> _serializeReminder(Reminder reminder) => {
    'id': reminder.id,
    'title': reminder.title,
    'description': reminder.description,
    'scheduledDateTime': reminder.scheduledDateTime.toIso8601String(),
    'recurrenceType': reminder.recurrence.type.name,
    'recurrenceDays': reminder.recurrence.daysOfWeek,
    'status': reminder.status.name,
    'voiceNotePath': reminder.voiceNotePath,
    'voiceNoteDurationMs': reminder.voiceNoteDuration?.inMilliseconds,
    'callerName': reminder.callerName,
    'callerNumber': reminder.callerNumber,
    'callerIcon': reminder.callerIcon,
    'callerImagePath': reminder.callerImagePath,
    'createdAt': reminder.createdAt.toIso8601String(),
    'updatedAt': reminder.updatedAt.toIso8601String(),
    'completedAt': reminder.completedAt?.toIso8601String(),
  };

  Reminder _deserializeReminder(Map<String, dynamic> map) {
    final recTypeStr = map['recurrenceType'] as String? ?? 'none';
    final recType = RecurrenceType.values.firstWhere(
      (e) => e.name == recTypeStr,
      orElse: () => RecurrenceType.none,
    );

    final daysList =
        (map['recurrenceDays'] as List<dynamic>?)
            ?.whereType<num>()
            .map((e) => e.toInt())
            .toList() ??
        const <int>[];

    final statusStr = map['status'] as String? ?? 'active';
    final status = ReminderStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ReminderStatus.active,
    );

    final durationMs = map['voiceNoteDurationMs'] as int?;

    return Reminder(
      id: map['id'] as String? ?? _uuid.v4(),
      title: map['title'] as String? ?? 'Untitled Reminder',
      description: map['description'] as String?,
      scheduledDateTime: DateTime.parse(
        map['scheduledDateTime'] as String? ??
            DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      ),
      recurrence: RecurrenceRule(type: recType, daysOfWeek: daysList),
      status: status,
      voiceNotePath: map['voiceNotePath'] as String?,
      voiceNoteDuration: durationMs != null
          ? Duration(milliseconds: durationMs)
          : null,
      callerName: map['callerName'] as String?,
      callerNumber: map['callerNumber'] as String?,
      callerIcon: map['callerIcon'] as String?,
      callerImagePath: map['callerImagePath'] as String?,
      createdAt: DateTime.parse(
        map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
    );
  }
}
