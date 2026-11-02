import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reminders/presentation/controllers/reminder_providers.dart';
import '../../data/services/aes_backup_vault_service.dart';
import '../../domain/models/backup_manifest.dart';
import '../../domain/services/backup_vault_service.dart';

/// Provider for the encrypted backup vault service.
final backupVaultServiceProvider = Provider<BackupVaultService>((ref) {
  return AesBackupVaultService(
    reminderRepository: ref.watch(reminderRepositoryProvider),
    voiceNoteStorage: ref.watch(voiceNoteStorageServiceProvider),
    callerImageService: ref.watch(callerImageServiceProvider),
    alarmScheduler: ref.watch(reminderAlarmSchedulerProvider),
  );
});

/// Lists local backup files available for restoration.
final availableBackupsProvider = FutureProvider<List<String>>((ref) async {
  final vault = ref.watch(backupVaultServiceProvider);
  return vault.listAvailableBackups();
});

/// Operation state for backup/restore UI workflows.
sealed class BackupOpState {
  const BackupOpState();
}

class BackupOpIdle extends BackupOpState {
  const BackupOpIdle();
}

class BackupOpLoading extends BackupOpState {
  const BackupOpLoading(this.message);
  final String message;
}

class BackupOpExportSuccess extends BackupOpState {
  const BackupOpExportSuccess(this.result);
  final BackupExportResult result;
}

class BackupOpRestoreSuccess extends BackupOpState {
  const BackupOpRestoreSuccess(this.result);
  final BackupRestoreResult result;
}

class BackupOpInspected extends BackupOpState {
  const BackupOpInspected({required this.filePath, required this.manifest});
  final String filePath;
  final BackupManifest manifest;
}

class BackupOpError extends BackupOpState {
  const BackupOpError(this.message);
  final String message;
}

/// Controller managing backup export, inspection, and restoration actions.
class BackupController extends Notifier<BackupOpState> {
  @override
  BackupOpState build() => const BackupOpIdle();

  BackupVaultService get _vault => ref.read(backupVaultServiceProvider);

  void reset() => state = const BackupOpIdle();

  Future<void> createBackup(String passphrase) async {
    if (passphrase.trim().length < 6) {
      state = const BackupOpError(
        'Passphrase must be at least 6 characters long.',
      );
      return;
    }

    state = const BackupOpLoading('Encrypting reminders and attachments...');
    try {
      final result = await _vault.createBackup(passphrase: passphrase);
      ref.invalidate(availableBackupsProvider);
      state = BackupOpExportSuccess(result);
    } catch (e) {
      state = BackupOpError(e.toString());
    }
  }

  Future<void> inspectBackup(String filePath, String passphrase) async {
    if (passphrase.trim().isEmpty) {
      state = const BackupOpError('Please enter the backup passphrase.');
      return;
    }

    state = const BackupOpLoading('Decrypting backup metadata...');
    try {
      final manifest = await _vault.inspectBackup(
        filePath: filePath,
        passphrase: passphrase,
      );
      state = BackupOpInspected(filePath: filePath, manifest: manifest);
    } on InvalidBackupPassphraseException {
      state = const BackupOpError('Incorrect passphrase. Decryption failed.');
    } on InvalidBackupFileException catch (e) {
      state = BackupOpError(e.message);
    } catch (e) {
      state = BackupOpError('Failed to inspect backup: $e');
    }
  }

  Future<void> restoreBackup({
    required String filePath,
    required String passphrase,
    required RestoreMode mode,
  }) async {
    state = const BackupOpLoading('Restoring reminders and audio...');
    try {
      final result = await _vault.restoreBackup(
        filePath: filePath,
        passphrase: passphrase,
        mode: mode,
      );
      // Invalidate reminders list so the UI refreshes immediately
      ref.invalidate(remindersStreamProvider);
      state = BackupOpRestoreSuccess(result);
    } on InvalidBackupPassphraseException {
      state = const BackupOpError('Incorrect passphrase. Decryption failed.');
    } on InvalidBackupFileException catch (e) {
      state = BackupOpError(e.message);
    } catch (e) {
      state = BackupOpError('Failed to restore backup: $e');
    }
  }
}

final backupControllerProvider =
    NotifierProvider<BackupController, BackupOpState>(BackupController.new);
