import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../reminders/data/services/flutter_reminder_speech_service.dart';
import '../../../reminders/domain/services/reminder_speech_service.dart';
import '../../domain/models/voice_install_progress.dart';
import '../../domain/models/voice_pack.dart';
import '../../domain/models/voice_selection.dart';
import '../../domain/services/voice_preview_service.dart';
import '../controllers/voice_providers.dart';

/// Lets the user choose how Lujayn speaks, including downloading a better
/// voice once and using it forever without a connection.
class VoiceSettingsScreen extends ConsumerStatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  ConsumerState<VoiceSettingsScreen> createState() =>
      _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends ConsumerState<VoiceSettingsScreen> {
  VoicePreviewService? _preview;
  ReminderSpeechService? _deviceVoice;
  String? _previewingId;
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    _preview = ref.read(voicePreviewServiceProvider);
    _deviceVoice = FlutterReminderSpeechService();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _preview?.stopPreview();
    _deviceVoice?.stop();
    super.dispose();
  }

  Future<void> _previewVoice(VoiceOption voice) async {
    final preview = _preview;
    if (preview == null) {
      _say('Voice previews are not available on this device.');
      return;
    }
    if (_previewingId == voice.id) {
      await _stopPreview();
      return;
    }

    await _stopPreview();
    if (!mounted) return;
    setState(() => _previewingId = voice.id);

    try {
      await preview.preview(voice);
      if (!mounted || _previewingId != voice.id) return;
      // Inference runs away from Flutter's UI isolate. The stop control stays
      // active while a model loads or generates its sample.
      _previewTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && _previewingId == voice.id) {
          setState(() => _previewingId = null);
        }
      });
    } on Object catch (error) {
      if (!mounted) return;
      if (_previewingId == voice.id) {
        setState(() => _previewingId = null);
      }
      _say(
        error is StateError
            ? error.message
            : 'That voice could not be played on this device.',
      );
    }
  }

  Future<void> _previewDeviceVoice() async {
    final device = _deviceVoice;
    if (device == null) return;
    await _stopPreview();
    if (!mounted) return;
    setState(() => _previewingId = 'device');
    try {
      await device.speak(voicePreviewText);
      if (!mounted || _previewingId != 'device') return;
      _previewTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && _previewingId == 'device') {
          setState(() => _previewingId = null);
        }
      });
    } on Object {
      if (!mounted) return;
      setState(() => _previewingId = null);
      _say('This device’s speech engine could not play the sample.');
    }
  }

  Future<void> _stopPreview() async {
    _previewTimer?.cancel();
    final activePreview = _previewingId;
    if (activePreview == 'device') {
      await _deviceVoice?.stop();
    } else if (activePreview != null) {
      await _preview?.stopPreview();
    }
    if (mounted) setState(() => _previewingId = null);
  }

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryAsync = ref.watch(voiceLibraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminder voice')),
      body: libraryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => EmptyStateView(
          icon: Icons.record_voice_over_outlined,
          title: 'Voice settings didn’t load',
          description:
              'Lujayn could not read the voice settings on this device. '
              'Your reminders are unaffected.',
          actionLabel: 'Try again',
          actionIcon: Icons.refresh_rounded,
          onAction: () => ref.invalidate(voiceLibraryProvider),
        ),
        data: (library) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Lujayn can speak with your phone’s own voice, or with a more '
              'natural voice you download once. Tap any voice to hear it before '
              'choosing. Downloads stay on this device and keep working with no '
              'connection.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _SectionTitle('This phone’s voice'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: _VoiceTile(
                title: 'Device voice',
                subtitle:
                    'Android’s built-in text-to-speech. No download and no '
                    'extra storage.',
                selected: library.selection is DeviceVoice,
                previewing: _previewingId == 'device',
                onPreview: _previewDeviceVoice,
                onTap: () {
                  ref
                      .read(voiceLibraryProvider.notifier)
                      .select(VoiceSelection.device);
                  _previewDeviceVoice();
                },
              ),
            ),
            for (final pack in ref.watch(voiceCatalogProvider)) ...[
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle(pack.name),
              _PackCard(
                pack: pack,
                library: library,
                previewingId: _previewingId,
                onPreview: _previewVoice,
                onSelect: (voice) {
                  ref
                      .read(voiceLibraryProvider.notifier)
                      .select(PackVoice(voice));
                  _previewVoice(voice);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PackCard extends ConsumerWidget {
  const _PackCard({
    required this.pack,
    required this.library,
    required this.previewingId,
    required this.onPreview,
    required this.onSelect,
  });

  final VoicePack pack;
  final VoiceLibraryState library;
  final String? previewingId;
  final ValueChanged<VoiceOption> onPreview;
  final ValueChanged<VoiceOption> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final notifier = ref.read(voiceLibraryProvider.notifier);
    final installed = library.isInstalled(pack.id);
    final installing = library.isInstalling(pack.id);
    final progress = library.progress[pack.id];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${pack.downloadLabel} download',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      pack.licence,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  pack.summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (!installed) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Needs about ${pack.installedLabel} of storage.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (installing) _InstallProgress(progress: progress!),
          if (!installed && !installing)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (progress?.isFailed ?? false) ...[
                    Text(
                      progress!.message ??
                          'The voice could not be installed. Please try again.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      notifier.dismissProgress(pack.id);
                      notifier.install(pack);
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      progress?.isFailed ?? false ? 'Try again' : 'Download',
                    ),
                  ),
                ],
              ),
            ),
          if (installed) ...[
            const Divider(height: 1),
            for (final group in _groups(pack))
              ..._voiceRows(context, ref, group.$1, group.$2),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _confirmRemove(context, ref, notifier),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text('Remove download (frees ${pack.installedLabel})'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    VoiceLibraryNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this voice?'),
        content: Text(
          'The ${pack.name} voices will be deleted from this device. '
          'You can download them again later. Your reminders are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      HapticFeedback.mediumImpact();
      await notifier.remove(pack);
    }
  }

  List<(String, List<VoiceOption>)> _groups(VoicePack pack) {
    return [
      ('Female', pack.femaleVoices.toList()),
      ('Male', pack.maleVoices.toList()),
    ].where((group) => group.$2.isNotEmpty).toList();
  }

  List<Widget> _voiceRows(
    BuildContext context,
    WidgetRef ref,
    String label,
    List<VoiceOption> voices,
  ) {
    final theme = Theme.of(context);
    final selectedId = switch (library.selection) {
      PackVoice(voice: final selected) => selected.id,
      DeviceVoice() => null,
    };
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxs,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      for (final voice in voices)
        _VoiceTile(
          title: voice.name,
          subtitle: voice.accent,
          selected: selectedId == voice.id,
          previewing: previewingId == voice.id,
          onPreview: () => onPreview(voice),
          onTap: () => onSelect(voice),
        ),
    ];
  }
}

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.previewing = false,
    this.onPreview,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool previewing;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListTile(
      onTap: () {
        if (!selected) {
          HapticFeedback.selectionClick();
        }
        onTap();
      },
      selected: selected,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.35),
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? colors.primary : colors.outline,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            Semantics(
              label: 'In use',
              child: Icon(Icons.graphic_eq_rounded, color: colors.primary),
            ),
          if (onPreview != null)
            IconButton(
              onPressed: onPreview,
              tooltip: previewing ? 'Stop preview' : 'Preview $title',
              icon: Icon(
                previewing
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
                color: colors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _InstallProgress extends StatelessWidget {
  const _InstallProgress({required this.progress});

  final VoiceInstallProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = progress.fraction;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: AppSpacing.xs),
          Text(
            fraction == null
                ? progress.stageLabel
                : '${progress.stageLabel} · ${(fraction * 100).round()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxs,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
