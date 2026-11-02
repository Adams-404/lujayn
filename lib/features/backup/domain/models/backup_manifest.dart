/// Metadata describing a Lujayn encrypted backup payload.
class BackupManifest {
  const BackupManifest({
    required this.format,
    required this.version,
    required this.createdAt,
    required this.appVersion,
    required this.reminderCount,
    required this.recordingCount,
    required this.callerPhotoCount,
  });

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      format: json['format'] as String? ?? 'lujayn_backup',
      version: json['version'] as int? ?? 1,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      appVersion: json['appVersion'] as String? ?? '1.0.0',
      reminderCount: json['reminderCount'] as int? ?? 0,
      recordingCount: json['recordingCount'] as int? ?? 0,
      callerPhotoCount: json['callerPhotoCount'] as int? ?? 0,
    );
  }

  static const String currentFormat = 'lujayn_backup';
  static const int currentVersion = 1;

  final String format;
  final int version;
  final DateTime createdAt;
  final String appVersion;
  final int reminderCount;
  final int recordingCount;
  final int callerPhotoCount;

  bool get isValid => format == currentFormat && version <= currentVersion;

  Map<String, dynamic> toJson() => {
    'format': format,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'appVersion': appVersion,
    'reminderCount': reminderCount,
    'recordingCount': recordingCount,
    'callerPhotoCount': callerPhotoCount,
  };
}

/// Mode to apply when restoring reminders from a backup file.
enum RestoreMode {
  /// Keep existing reminders; only insert non-duplicate reminders from backup.
  merge,

  /// Wipe existing reminders and replace with the exact backup contents.
  replace,
}

/// Result of an export operation.
class BackupExportResult {
  const BackupExportResult({
    required this.filePath,
    required this.fileSizeBytes,
    required this.manifest,
  });

  final String filePath;
  final int fileSizeBytes;
  final BackupManifest manifest;
}

/// Result of a restore operation.
class BackupRestoreResult {
  const BackupRestoreResult({
    required this.restoredCount,
    required this.mode,
    required this.manifest,
  });

  final int restoredCount;
  final RestoreMode mode;
  final BackupManifest manifest;
}

/// Thrown when an invalid or corrupt backup file is provided.
class InvalidBackupFileException implements Exception {
  const InvalidBackupFileException([
    this.message = 'Invalid or corrupt backup file.',
  ]);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when the passphrase supplied to decrypt a backup is wrong.
class InvalidBackupPassphraseException implements Exception {
  const InvalidBackupPassphraseException([
    this.message = 'Incorrect passphrase. Unable to decrypt backup.',
  ]);
  final String message;

  @override
  String toString() => message;
}
