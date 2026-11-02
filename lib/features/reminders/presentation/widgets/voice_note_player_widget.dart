import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/services/voice_playback_service.dart';
import '../controllers/reminder_providers.dart';

/// An accessible, calm playback surface for a recorded voice note.
class VoiceNotePlayerWidget extends ConsumerStatefulWidget {
  const VoiceNotePlayerWidget({
    super.key,
    required this.fileNameOrPath,
    this.totalDuration,
    this.onDelete,
    this.autoPlay = false,
  });

  final String fileNameOrPath;
  final Duration? totalDuration;
  final VoidCallback? onDelete;
  final bool autoPlay;

  @override
  ConsumerState<VoiceNotePlayerWidget> createState() =>
      _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends ConsumerState<VoiceNotePlayerWidget> {
  VoicePlaybackService? _player;
  StreamSubscription<VoicePlaybackState>? _sub;
  VoicePlaybackState _state = const VoicePlaybackState();
  String? _resolvedPath;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final storage = ref.read(voiceNoteStorageServiceProvider);
    final resolved = await storage.resolvePath(widget.fileNameOrPath);
    if (!mounted) return;

    final player = ref.read(voicePlaybackServiceProvider);
    _player = player;
    _resolvedPath = resolved;

    _sub = player.stateStream.listen((state) {
      if (mounted) setState(() => _state = state);
    });

    if (widget.autoPlay) {
      try {
        await player.play(resolved);
      } on Object catch (error) {
        debugPrint('Voice note autoplay failed: $error');
      }
    }
  }

  @override
  void didUpdateWidget(VoiceNotePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.autoPlay && widget.autoPlay && !_state.isPlaying) {
      final path = _resolvedPath;
      if (path != null && _player != null) {
        try {
          _player!.play(path);
        } on Object catch (error) {
          debugPrint('Voice note autoplay update failed: $error');
        }
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player?.stop();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final player = _player;
    final path = _resolvedPath;
    if (player == null || path == null) return;

    HapticFeedback.lightImpact();
    if (_state.isPlaying) {
      await player.pause();
    } else if (_state.isPaused) {
      await player.resume();
    } else {
      await player.play(path);
    }
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isPlaying = _state.isPlaying;

    final effectiveDuration = _state.duration > Duration.zero
        ? _state.duration
        : (widget.totalDuration ?? Duration.zero);
    final currentPos = _state.position;

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.surface),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Semantics(
              label: isPlaying ? 'Pause voice note' : 'Play voice note',
              button: true,
              child: IconButton(
                onPressed: _togglePlay,
                iconSize: 28,
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                ),
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isPlaying ? 'Playing voice note' : 'Voice note',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        isPlaying
                            ? '${_formatDuration(currentPos)} / ${_formatDuration(effectiveDuration)}'
                            : _formatDuration(effectiveDuration),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                      activeTrackColor: colors.primary,
                      inactiveTrackColor: colors.outlineVariant,
                      thumbColor: colors.primary,
                    ),
                    child: Slider(
                      value: _state.progressFraction,
                      onChanged: (val) {
                        if (effectiveDuration > Duration.zero) {
                          final target = Duration(
                            milliseconds:
                                (val * effectiveDuration.inMilliseconds)
                                    .round(),
                          );
                          _player?.seek(target);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onDelete != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Semantics(
                label: 'Delete voice note',
                button: true,
                child: IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onDelete!();
                  },
                  icon: Icon(Icons.delete_outline_rounded, color: colors.error),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
