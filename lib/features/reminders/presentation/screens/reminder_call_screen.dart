import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/date_formatters.dart';
import '../../../settings/presentation/controllers/settings_providers.dart';
import '../../domain/models/reminder.dart';
import '../../domain/services/reminder_speech_service.dart';
import '../controllers/reminder_providers.dart';
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
    _speech?.stop();
    super.dispose();
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
  /// Recurrence summaries are deliberately left out — they are visual context,
  /// not something useful to hear while the alert is ringing.
  String get _spokenText {
    final note = _reminder.description;
    if (note == null || note.trim().isEmpty) return _reminder.title;
    return '${_reminder.title}. $note';
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
            'REMINDER',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 36),
                  _CallerBadge(label: _initials(_reminder.title)),
                  const SizedBox(height: 26),
                  Text(
                    _reminder.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
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
                  if (_reminder.hasVoiceNote) ...[
                    const SizedBox(height: 14),
                    VoiceNotePlayerWidget(
                      fileNameOrPath: _reminder.voiceNotePath!,
                      totalDuration: _reminder.voiceNoteDuration,
                      autoPlay: autoSpeak,
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
                      label: Text(_speaking ? 'Stop reading' : 'Read aloud'),
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _dismiss,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Done'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _snooze,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              icon: const Icon(Icons.snooze_rounded),
              label: const Text('Snooze 10 minutes'),
            ),
          ),
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

class _CallerBadge extends StatelessWidget {
  const _CallerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      label: 'Reminder icon',
      child: Container(
        width: 112,
        height: 112,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.primaryContainer,
          border: Border.all(color: colors.outlineVariant, width: 1.5),
        ),
        child: Text(
          label,
          style: theme.textTheme.displaySmall?.copyWith(
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
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
