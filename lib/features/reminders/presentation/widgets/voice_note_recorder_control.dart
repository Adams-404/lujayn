import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../app/theme/app_spacing.dart';
import '../controllers/reminder_providers.dart';
import 'voice_note_player_widget.dart';

/// Interactive surface for recording, previewing, and managing a reminder's voice note.
class VoiceNoteRecorderControl extends ConsumerStatefulWidget {
  const VoiceNoteRecorderControl({
    super.key,
    required this.initialVoiceNotePath,
    required this.initialDuration,
    required this.onChanged,
  });

  final String? initialVoiceNotePath;
  final Duration? initialDuration;
  final void Function(String? relativePath, Duration? duration) onChanged;

  @override
  ConsumerState<VoiceNoteRecorderControl> createState() =>
      _VoiceNoteRecorderControlState();
}

class _VoiceNoteRecorderControlState
    extends ConsumerState<VoiceNoteRecorderControl> {
  String? _voiceNotePath;
  Duration? _voiceNoteDuration;
  bool _isRecording = false;
  bool _permissionDenied = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _activeRecordingPath;

  @override
  void initState() {
    super.initState();
    _voiceNotePath = widget.initialVoiceNotePath;
    _voiceNoteDuration = widget.initialDuration;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_isRecording) {
      ref.read(voiceRecordingServiceProvider).cancelRecording();
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    final recordingService = ref.read(voiceRecordingServiceProvider);
    final hasPermission = await recordingService.hasPermission();
    if (!mounted) return;

    if (!hasPermission) {
      // Explain microphone usage plainly before asking
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Record your reminder'),
          content: const Text(
            'Lujayn needs microphone access to record your voice note. '
            'The recording stays strictly on this device and is never sent anywhere.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (proceed != true) return;

      final granted = await recordingService.requestPermission();
      if (!granted) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }
    }

    if (mounted) {
      setState(() {
        _permissionDenied = false;
      });
    }

    final storage = ref.read(voiceNoteStorageServiceProvider);
    final targetPath = await storage.generateNewRecordingPath();

    try {
      await recordingService.startRecording(targetPath);
      HapticFeedback.mediumImpact();
      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _activeRecordingPath = targetPath;
        _elapsedSeconds = 0;
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _elapsedSeconds++);
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start recording. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final recordingService = ref.read(voiceRecordingServiceProvider);
    HapticFeedback.mediumImpact();

    try {
      final path = await recordingService.stopRecording();
      final finalPath = path ?? _activeRecordingPath;
      final duration = Duration(seconds: _elapsedSeconds);

      if (finalPath != null && await File(finalPath).exists()) {
        final relative = p.basename(finalPath);
        if (mounted) {
          setState(() {
            _isRecording = false;
            _voiceNotePath = relative;
            _voiceNoteDuration = duration;
            _activeRecordingPath = null;
          });
        }
        widget.onChanged(relative, duration);
      } else {
        if (mounted) {
          setState(() {
            _isRecording = false;
            _activeRecordingPath = null;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _activeRecordingPath = null;
        });
      }
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    HapticFeedback.lightImpact();
    final recordingService = ref.read(voiceRecordingServiceProvider);
    await recordingService.cancelRecording();

    final activePath = _activeRecordingPath;
    if (activePath != null) {
      final file = File(activePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _activeRecordingPath = null;
        _elapsedSeconds = 0;
      });
    }
  }

  void _deleteRecording() {
    setState(() {
      _voiceNotePath = null;
      _voiceNoteDuration = null;
    });
    widget.onChanged(null, null);
  }

  static String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // 1. If already recorded, show player preview + delete option
    if (_voiceNotePath != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VoiceNotePlayerWidget(
            fileNameOrPath: _voiceNotePath!,
            totalDuration: _voiceNoteDuration,
            onDelete: _deleteRecording,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Recorded voice note will play when this reminder alerts.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    // 2. If actively recording, show pulsing indicator, timer, and controls
    if (_isRecording) {
      return Material(
        color: colors.errorContainer.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
          side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.error,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Recording... ${_formatDuration(_elapsedSeconds)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.error,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              TextButton(
                onPressed: _cancelRecording,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: colors.onSurfaceVariant,
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton.icon(
                onPressed: _stopRecording,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    // 3. If permission was denied, show an honest non-blocking explanation
    if (_permissionDenied) {
      return Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mic_off_outlined, color: colors.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Microphone permission is off',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'To record voice reminders, allow microphone access in device Settings. '
                'You can still save this reminder with text.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _startRecording,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Default idle state: button to record voice note
    return OutlinedButton.icon(
      onPressed: _startRecording,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
      ),
      icon: const Icon(Icons.mic_rounded, size: 22),
      label: const Text('Add voice recording'),
    );
  }
}
