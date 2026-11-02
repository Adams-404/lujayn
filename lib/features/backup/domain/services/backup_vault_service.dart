import '../models/backup_manifest.dart';

/// Contract for creating, inspecting, and restoring local encrypted backups.
abstract class BackupVaultService {
  /// Packages reminders, voice recordings, and caller photos into an
  /// encrypted local backup file protected by [passphrase].
  Future<BackupExportResult> createBackup({
    required String passphrase,
    String? targetDirectoryPath,
  });

  /// Reads and validates the manifest of an encrypted backup file at [filePath]
  /// using [passphrase] without committing any data to persistence.
  Future<BackupManifest> inspectBackup({
    required String filePath,
    required String passphrase,
  });

  /// Restores reminders, voice notes, and caller photos from an encrypted backup
  /// at [filePath] using [passphrase] according to [mode].
  Future<BackupRestoreResult> restoreBackup({
    required String filePath,
    required String passphrase,
    required RestoreMode mode,
  });

  /// Returns paths of backup files found in the default local backup directory.
  Future<List<String>> listAvailableBackups();
}
