import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utilities/date_formatters.dart';
import '../../../settings/presentation/controllers/settings_providers.dart';
import '../../domain/models/reminder.dart';
import '../../domain/services/reminder_speech_service.dart';
import '../controllers/reminder_providers.dart';
import '../widgets/caller_persona_selector.dart';
import '../widgets/voice_note_player_widget.dart';

/// The focused, call-style surface shown when a reminder becomes due.
///
/// Android may present this as a full-screen intent or as a notification the
/// user taps, depending on the OS version, permissions and OEM restrictions.
/// The layout therefore never assumes it is already the only thing on screen.
class ReminderCallScreen extends ConsumerWidget {
  const ReminderCallScreen({super.key, required this.reminderId});

  final String reminderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remindersAsync = ref.watch(remindersStreamProvider);

    return PopScope(
      // Back closes the alert without dismissing the reminder, so the user is
      // never forced to choose between two destructive-looking outcomes.
      canPop: true,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: remindersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _CallMessage(
              title: 'Reminder unavailable',
              message: 'Lujayn could not read this reminder right now.',
              actionLabel: 'Close',
              onAction: () => Navigator.of(context).maybePop(),
            ),
            data: (reminders) {
              final reminder = reminders
                  .where((item) => item.id == reminderId)
                  .firstOrNull;
              if (reminder == null) {
                return _CallMessage(
                  title: 'Reminder not found',
                  message:
                      'This reminder may have been deleted on another screen.',
                  actionLabel: 'Close',
                  onAction: () => Navigator.of(context).maybePop(),
                );
              }
              return _CallBody(reminder: reminder);
            },
          ),
        ),
      ),
    );
  }
}

class _CallBody extends ConsumerStatefulWidget {
  const _CallBody({required this.reminder});

  final Reminder reminder;

  @override
  ConsumerState<_CallBody> createState() => _CallBodyState();
}

class _CallBodyState extends ConsumerState<_CallBody> {
  ReminderSpeechService? _speech;
  bool _speechAvailable = false;
  bool _speaking = false;
  bool _isAnswered = false;
  int _callSeconds = 0;
  Timer? _callTimer;

  Reminder get _reminder => widget.reminder;

  @override
  void initState() {
    super.initState();
    // Ask after the first frame: the screen should be visible before it starts
    // talking, and providers must not be read during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareSpeech());
  }

  @override
  void dispose() {
    // Leaving the screen must never leave a voice talking to an empty room.
    _callTimer?.cancel();
    _speech?.stop();
    super.dispose();
  }

  void _answerCall() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isAnswered = true;
      _callSeconds = 0;
    });
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callSeconds++);
      } else {
        timer.cancel();
      }
    });

    if (_speechAvailable) {
      if (_speaking) {
        _speech?.stop();
        _speaking = false;
      }
      _speak();
    }
  }

  void _hangUp() {
    HapticFeedback.mediumImpact();
    _callTimer?.cancel();
    _speech?.stop();
    if (mounted) Navigator.of(context).maybePop();
  }

  String get _formattedCallDuration {
    final minutes = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _prepareSpeech() async {
    final speech = ref.read(reminderSpeechServiceProvider);
    final available = await speech.isAvailable();
    if (!mounted) return;
    setState(() {
      _speech = speech;
      _speechAvailable = available;
    });

    final autoSpeak =
        ref.read(spokenRemindersEnabledProvider).asData?.value ?? false;
    if (available && autoSpeak) await _speak();
  }

  Future<void> _speak() async {
    final speech = _speech;
    if (speech == null || !_speechAvailable || _speaking) return;
    HapticFeedback.lightImpact();
    setState(() => _speaking = true);
    try {
      await speech.speak(_spokenText);
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _stopSpeech() async {
    HapticFeedback.lightImpact();
    await _speech?.stop();
    if (mounted) setState(() => _speaking = false);
  }

  /// What the user hears: the reminder itself, then the note that goes with it.
  /// When answered, an interactive dialpad prompt is added.
  /// Recurrence summaries are deliberately left out — they are visual context,
  /// not something useful to hear while the alert is ringing.
  String get _spokenText {
    final note = _reminder.description;
    final base = (note == null || note.trim().isEmpty)
        ? _reminder.title
        : '${_reminder.title}. $note';
    if (_isAnswered) {
      return '$base. Press 1 for done, 2 to reschedule, or 3 to keep active.';
    }
    return base;
  }

  Future<void> _snooze() async {
    HapticFeedback.mediumImpact();
    await ref.read(reminderActionControllerProvider).snooze(_reminder.id);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _dismiss() async {
    HapticFeedback.mediumImpact();
    await ref
        .read(reminderActionControllerProvider)
        .dismissOccurrence(_reminder.id);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final time = AppDateFormatters.formatTime(_reminder.scheduledDateTime);
    final autoSpeak =
        ref.watch(spokenRemindersEnabledProvider).asData?.value ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Text(
            _isAnswered
                ? 'CONNECTED • $_formattedCallDuration'
                : 'INCOMING CALL',
            style: theme.textTheme.labelMedium?.copyWith(
              color: _isAnswered ? colors.primary : colors.onSurfaceVariant,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isAnswered ? 'In call' : time,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 36),
                  if (_reminder.hasCallerPersona) ...[
                    _CallerBadge(
                      label: _initials(_reminder.callerName ?? _reminder.title),
                      icon: iconForCallerIcon(_reminder.callerIcon),
                      imagePath: _reminder.callerImagePath,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _reminder.callerName ?? _reminder.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (_reminder.callerNumber case final num?
                        when num.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        num,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.circle),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Text(
                        _reminder.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else ...[
                    _CallerBadge(
                      label: _initials(_reminder.title),
                      imagePath: _reminder.callerImagePath,
                    ),
                    const SizedBox(height: 26),
                    Text(
                      _reminder.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                  if (_reminder.description case final note?
                      when note.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      note,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    _reminder.recurrence.summary,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (_isAnswered) ...[
                    const SizedBox(height: 20),
                    Material(
                      color: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.surface),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            Text(
                              'Dialpad — press a key to respond:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: _KeypadButton(
                                    keyNumber: '1',
                                    label: 'Done',
                                    color: colors.primary,
                                    onPressed: _dismiss,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _KeypadButton(
                                    keyNumber: '2',
                                    label: 'Reschedule',
                                    color: colors.secondary,
                                    onPressed: _snooze,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _KeypadButton(
                                    keyNumber: '3',
                                    label: 'Keep Active',
                                    color: colors.outline,
                                    onPressed: _hangUp,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_reminder.hasVoiceNote) ...[
                    const SizedBox(height: 14),
                    VoiceNotePlayerWidget(
                      fileNameOrPath: _reminder.voiceNotePath!,
                      totalDuration: _reminder.voiceNoteDuration,
                      autoPlay: autoSpeak || _isAnswered,
                    ),
                  ] else if (_speechAvailable) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _speaking ? _stopSpeech : _speak,
                      icon: Icon(
                        _speaking
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_rounded,
                      ),
                      label: Text(
                        _speaking
                            ? 'Stop reading'
                            : (_isAnswered ? 'Repeat message' : 'Read aloud'),
                      ),
                    ),
                  ] else if (autoSpeak) ...[
                    // The setting is on but the device cannot speak. Say so
                    // rather than failing silently.
                    const SizedBox(height: 12),
                    Text(
                      'Reading aloud is on, but this device has no speech '
                      'engine installed.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isAnswered) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _hangUp,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.call_end_rounded),
                label: const Text('Hang up'),
              ),
            ),
          ] else ...[
            TextButton.icon(
              onPressed: _snooze,
              icon: const Icon(Icons.snooze_rounded),
              label: const Text('Snooze for 10 minutes'),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _IncomingCallAction(
                  icon: Icons.call_end_rounded,
                  label: 'Decline',
                  color: const Color(0xFFFF6B6B),
                  onPressed: _dismiss,
                ),
                _IncomingCallAction(
                  icon: Icons.call_rounded,
                  label: 'Answer',
                  color: const Color(0xFF43C879),
                  onPressed: _answerCall,
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Android may show this as a notification instead of a full screen '
            'when battery or notification settings restrict Lujayn.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String title) {
    final words = title
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .toList();
    if (words.isEmpty) return '?';
    return words.map((word) => word.substring(0, 1).toUpperCase()).join();
  }
}

class _CallerBadge extends ConsumerStatefulWidget {
  const _CallerBadge({required this.label, this.icon, this.imagePath});

  final String label;
  final IconData? icon;
  final String? imagePath;

  @override
  ConsumerState<_CallerBadge> createState() => _CallerBadgeState();
}

class _CallerBadgeState extends ConsumerState<_CallerBadge> {
  String? _resolvedPath;

  @override
  void initState() {
    super.initState();
    if (widget.imagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
    }
  }

  @override
  void didUpdateWidget(_CallerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      if (widget.imagePath != null) {
        _resolve();
      } else {
        setState(() => _resolvedPath = null);
      }
    }
  }

  Future<void> _resolve() async {
    if (widget.imagePath == null) return;
    final service = ref.read(callerImageServiceProvider);
    final resolved = await service.resolvePath(widget.imagePath!);
    if (mounted) setState(() => _resolvedPath = resolved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final file = _resolvedPath != null ? File(_resolvedPath!) : null;
    final hasImage = file != null && file.existsSync();

    return Semantics(
      label: hasImage ? 'Caller profile picture' : 'Reminder icon',
      child: Container(
        width: 112,
        height: 112,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.primaryContainer,
          border: Border.all(color: colors.outlineVariant, width: 2),
          image: hasImage
              ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
              : null,
        ),
        child: hasImage
            ? null
            : (widget.icon != null
                  ? Icon(
                      widget.icon,
                      size: 52,
                      color: colors.onPrimaryContainer,
                    )
                  : Text(
                      widget.label,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    )),
      ),
    );
  }
}

class _CallMessage extends StatelessWidget {
  const _CallMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alarm_off_rounded, size: 48, color: colors.primary),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingCallAction extends StatelessWidget {
  const _IncomingCallAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
            ),
            child: Icon(icon, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.keyNumber,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String keyNumber;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            keyNumber,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
