import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../reminders/presentation/controllers/reminder_providers.dart';
import '../../domain/models/backup_manifest.dart';
import '../controllers/backup_providers.dart';

/// Screen allowing users to create and restore AES-256 encrypted local backups.
class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  int _tabIndex = 0; // 0 = Create, 1 = Restore

  // Export fields
  final _createPassphraseController = TextEditingController();
  final _confirmPassphraseController = TextEditingController();
  bool _obscureCreatePassphrase = true;

  // Restore fields
  String? _selectedBackupPath;
  final _restorePassphraseController = TextEditingController();
  final _customPathController = TextEditingController();
  bool _obscureRestorePassphrase = true;
  RestoreMode _restoreMode = RestoreMode.merge;
  bool _useCustomPath = false;

  @override
  void dispose() {
    _createPassphraseController.dispose();
    _confirmPassphraseController.dispose();
    _restorePassphraseController.dispose();
    _customPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final opState = ref.watch(backupControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Encrypted Backup & Restore'),
        elevation: 0,
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.fabClearance,
          ),
          children: [
            // Informational Security Note
            _buildSecurityNotice(theme, colors),
            const SizedBox(height: AppSpacing.md),

            // Segmented tab toggle
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Create Backup'),
                  icon: Icon(Icons.upload_file_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Restore Backup'),
                  icon: Icon(Icons.download_outlined),
                ),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (set) {
                setState(() {
                  _tabIndex = set.first;
                  ref.read(backupControllerProvider.notifier).reset();
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Status / Error Banner
            if (opState is BackupOpError) ...[
              _buildErrorBanner(theme, colors, opState.message),
              const SizedBox(height: AppSpacing.md),
            ],

            if (opState is BackupOpLoading) ...[
              _buildLoadingCard(theme, colors, opState.message),
              const SizedBox(height: AppSpacing.md),
            ],

            if (_tabIndex == 0)
              _buildCreateTab(theme, colors, opState)
            else
              _buildRestoreTab(theme, colors, opState),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNotice(ThemeData theme, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: colors.primary, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100% Local & Encrypted',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Backups are encrypted using AES-256 and PBKDF2 with your passphrase. '
                  'Nothing is ever uploaded to a server or cloud. Keep your passphrase safe; '
                  'there is no way to recover a forgotten passphrase.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(
    ThemeData theme,
    ColorScheme colors,
    String message,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(
    ThemeData theme,
    ColorScheme colors,
    String message,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildCreateTab(
    ThemeData theme,
    ColorScheme colors,
    BackupOpState opState,
  ) {
    final remindersAsync = ref.watch(remindersStreamProvider);
    final remindersList = remindersAsync.asData?.value ?? const [];
    final remindersCount = remindersList.length;
    final recordingsCount = remindersList.where((r) => r.hasVoiceNote).length;

    if (opState is BackupOpExportSuccess) {
      return _buildExportSuccessView(theme, colors, opState.result);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Card
        Card(
          elevation: 0,
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.surface),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Content to be backed up',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$remindersCount reminders',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Icon(
                      Icons.mic_none_outlined,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$recordingsCount voice notes',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Passphrase inputs
        Text(
          'Choose a Backup Passphrase',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'This passphrase will be required to decrypt and restore your reminders.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        TextField(
          controller: _createPassphraseController,
          obscureText: _obscureCreatePassphrase,
          decoration: InputDecoration(
            labelText: 'Passphrase (minimum 6 characters)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureCreatePassphrase
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureCreatePassphrase = !_obscureCreatePassphrase;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        TextField(
          controller: _confirmPassphraseController,
          obscureText: _obscureCreatePassphrase,
          decoration: InputDecoration(
            labelText: 'Confirm Passphrase',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        FilledButton.icon(
          onPressed: opState is BackupOpLoading
              ? null
              : () {
                  final pass = _createPassphraseController.text;
                  final confirm = _confirmPassphraseController.text;
                  if (pass.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Passphrase must be at least 6 characters.',
                        ),
                      ),
                    );
                    return;
                  }
                  if (pass != confirm) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Passphrases do not match.'),
                      ),
                    );
                    return;
                  }
                  ref
                      .read(backupControllerProvider.notifier)
                      .createBackup(pass);
                },
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
          ),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Create Encrypted Backup'),
        ),
      ],
    );
  }

  Widget _buildExportSuccessView(
    ThemeData theme,
    ColorScheme colors,
    BackupExportResult result,
  ) {
    final fileName = p.basename(result.filePath);
    final sizeKb = (result.fileSizeBytes / 1024).toStringAsFixed(1);

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.surface),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: colors.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Backup Created Successfully',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'File: $fileName',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Size: $sizeKb KB • Reminders: ${result.manifest.reminderCount} • Audio: ${result.manifest.recordingCount}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: SelectableText(
                result.filePath,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: result.filePath));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Backup path copied to clipboard.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copy Path'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      _createPassphraseController.clear();
                      _confirmPassphraseController.clear();
                      ref.read(backupControllerProvider.notifier).reset();
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreTab(
    ThemeData theme,
    ColorScheme colors,
    BackupOpState opState,
  ) {
    final availableBackupsAsync = ref.watch(availableBackupsProvider);

    if (opState is BackupOpRestoreSuccess) {
      return _buildRestoreSuccessView(theme, colors, opState.result);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select Backup File',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // List of found backups
        availableBackupsAsync.when(
          data: (files) {
            if (files.isEmpty && !_useCustomPath) {
              return Card(
                elevation: 0,
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.surface),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open_outlined,
                        size: 32,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'No local backups found in standard directory.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _useCustomPath = true;
                          });
                        },
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('Specify exact file path'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                if (!_useCustomPath)
                  ...files.map((filePath) {
                    final fileName = p.basename(filePath);
                    final isSelected = _selectedBackupPath == filePath;
                    return ListTile(
                      onTap: () {
                        setState(() {
                          _selectedBackupPath = filePath;
                        });
                      },
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected ? colors.primary : colors.outline,
                      ),
                      title: Text(
                        fileName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : null,
                        ),
                      ),
                      subtitle: Text(
                        filePath,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                if (!_useCustomPath)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _useCustomPath = true;
                        });
                      },
                      icon: const Icon(Icons.edit_note_outlined, size: 18),
                      label: const Text('Use custom file path'),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('Error reading backups: $e'),
        ),

        if (_useCustomPath) ...[
          TextField(
            controller: _customPathController,
            decoration: InputDecoration(
              labelText: 'Absolute path to .lujaynbackup file',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _useCustomPath = false;
                  });
                },
              ),
            ),
            onChanged: (val) {
              setState(() {
                _selectedBackupPath = val;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        const SizedBox(height: AppSpacing.md),
        Text(
          'Backup Passphrase',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _restorePassphraseController,
          obscureText: _obscureRestorePassphrase,
          decoration: InputDecoration(
            labelText: 'Enter passphrase used to encrypt this backup',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRestorePassphrase
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureRestorePassphrase = !_obscureRestorePassphrase;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Inspect Button
        if (opState is! BackupOpInspected) ...[
          OutlinedButton.icon(
            onPressed:
                (_selectedBackupPath == null ||
                    _restorePassphraseController.text.isEmpty ||
                    opState is BackupOpLoading)
                ? null
                : () {
                    ref
                        .read(backupControllerProvider.notifier)
                        .inspectBackup(
                          _selectedBackupPath!,
                          _restorePassphraseController.text,
                        );
                  },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
            ),
            icon: const Icon(Icons.preview_outlined),
            label: const Text('Inspect Backup Contents'),
          ),
        ],

        // Pre-Restore Preview & Restore Mode
        if (opState is BackupOpInspected) ...[
          const SizedBox(height: AppSpacing.md),
          _buildInspectedPreview(theme, colors, opState),
        ],
      ],
    );
  }

  Widget _buildInspectedPreview(
    ThemeData theme,
    ColorScheme colors,
    BackupOpInspected state,
  ) {
    final manifest = state.manifest;
    final dateStr = DateFormat.yMMMd().add_jm().format(
      manifest.createdAt.toLocal(),
    );

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.surface),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Backup Verified',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Created: $dateStr\n'
              'Reminders: ${manifest.reminderCount} • Voice Notes: ${manifest.recordingCount} • Photos: ${manifest.callerPhotoCount}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const Divider(height: AppSpacing.lg),

            Text(
              'Restore Mode',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            ListTile(
              onTap: () {
                setState(() {
                  _restoreMode = RestoreMode.merge;
                });
              },
              leading: Icon(
                _restoreMode == RestoreMode.merge
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: _restoreMode == RestoreMode.merge
                    ? colors.primary
                    : colors.outline,
              ),
              title: const Text('Merge with existing reminders'),
              subtitle: const Text(
                'Preserves current reminders and adds backup contents without overwriting.',
              ),
            ),
            ListTile(
              onTap: () {
                setState(() {
                  _restoreMode = RestoreMode.replace;
                });
              },
              leading: Icon(
                _restoreMode == RestoreMode.replace
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: _restoreMode == RestoreMode.replace
                    ? colors.primary
                    : colors.outline,
              ),
              title: const Text('Replace all reminders'),
              subtitle: const Text(
                'Clears current reminders on this device before restoring.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            FilledButton.icon(
              onPressed: () {
                if (_restoreMode == RestoreMode.replace) {
                  _showReplaceConfirmationDialog(context, state);
                } else {
                  _performRestore(state);
                }
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
              ),
              icon: const Icon(Icons.restore_outlined),
              label: Text(
                _restoreMode == RestoreMode.replace
                    ? 'Replace & Restore Reminders'
                    : 'Merge & Restore Reminders',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReplaceConfirmationDialog(
    BuildContext context,
    BackupOpInspected state,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace all reminders?'),
        content: const Text(
          'This will delete all existing reminders on this device and replace them with '
          'the reminders in this backup. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _performRestore(state);
            },
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
  }

  void _performRestore(BackupOpInspected state) {
    ref
        .read(backupControllerProvider.notifier)
        .restoreBackup(
          filePath: state.filePath,
          passphrase: _restorePassphraseController.text,
          mode: _restoreMode,
        );
  }

  Widget _buildRestoreSuccessView(
    ThemeData theme,
    ColorScheme colors,
    BackupRestoreResult result,
  ) {
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.surface),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: colors.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Restore Complete',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Successfully restored ${result.restoredCount} reminders in '
              '${result.mode == RestoreMode.merge ? 'merge' : 'replace'} mode.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () {
                _restorePassphraseController.clear();
                ref.read(backupControllerProvider.notifier).reset();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
