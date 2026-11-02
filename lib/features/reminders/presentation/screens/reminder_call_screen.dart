import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utilities/date_formatters.dart';
import '../../../settings/presentation/controllers/settings_providers.dart';
import '../../domain/models/reminder.dart';
import '../../domain/services/reminder_ringtone_service.dart';
import '../../domain/services/reminder_speech_service.dart';
import '../controllers/reminder_providers.dart';
import '../widgets/caller_persona_selector.dart';
import '../widgets/voice_note_player_widget.dart';

/// Call affordance colours.
///
/// Answer green and decline red are platform conventions, not brand colours:
/// people recognise them before they read a label. They are fixed because a
/// themed "decline" colour would make the most important control ambiguous.
abstract final class AppCallColors {
  static const Color answer = Color(0xFF2E9E5B);
  static const Color decline = Color(0xFFD64545);
}

/// The focused, call-style surface shown when a reminder becomes due.
///
/// Android may present this as a full-screen intent or as a notification the
/// user taps, depending on the OS version, permissions and OEM restrictions.
/// The layout therefore never assumes it is already the only thing on screen.
class ReminderCallScreen extends ConsumerWidget {
  const ReminderCallScreen({
    super.key,
    required this.reminderId,
    this.autoAnswer = false,
  });

  final String reminderId;
  final bool autoAnswer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
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
              return _CallBody(reminder: reminder, autoAnswer: autoAnswer);
            },
          ),
        ),
      ),
    );
  }
}

class _CallBody extends ConsumerStatefulWidget {
  const _CallBody({required this.reminder, this.autoAnswer = false});

  final Reminder reminder;
  final bool autoAnswer;

  @override
  ConsumerState<_CallBody> createState() => _CallBodyState();
}

class _CallBodyState extends ConsumerState<_CallBody> {
  static const _audioChannel = MethodChannel('com.lujayn/reminder_audio');
  static const _ringDuration = Duration(seconds: 60);

  ReminderSpeechService? _speech;
  ReminderRingtoneService? _ringtone;
  bool _speechAvailable = false;
  bool _speakerEnabled = true;
  bool _speaking = false;
  late bool _isAnswered;
  late bool _ringing;
  bool _showKeypad = false;
  String _dialed = '';
  int _callSeconds = 0;
  Timer? _callTimer;
  Timer? _ringTimer;

  Reminder get _reminder => widget.reminder;

  @override
  void initState() {
    super.initState();
    _isAnswered = widget.autoAnswer;
    _ringing = !widget.autoAnswer;
    if (_isAnswered) {
      _startCallTimer();
    }
    // Ask after the first frame: the screen should be visible before it starts
    // talking or ringing, and providers must not be read during build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isAnswered) {
        _startRinging();
        _prepareSpeech();
      } else {
        await _prepareSpeech();
        if (mounted && !_reminder.hasVoiceNote) {
          _speak();
        }
      }
    });
    if (!_isAnswered) {
      _ringTimer = Timer(_ringDuration, () {
        if (!mounted || _isAnswered) return;
        setState(() => _ringing = false);
      });
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callSeconds++);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    // Leaving the screen must never leave a voice talking or a phone ringing.
    _callTimer?.cancel();
    _ringTimer?.cancel();
    _speech?.stop();
    _ringtone?.stopRinging();
    _resetAudioRoute();
    super.dispose();
  }

  Future<void> _startRinging() async {
    final ringtone = ref.read(reminderRingtoneServiceProvider);
    _ringtone = ringtone;
    await ringtone.startRinging(_reminder.id);
  }

  Future<void> _stopRinging() async {
    await _ringtone?.stopRinging();
  }

  Future<void> _answerCall() async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _isAnswered = true;
      _ringing = false;
      _callSeconds = 0;
    });

    _ringTimer?.cancel();
    _startCallTimer();

    await _stopRinging();
    if (_reminder.hasVoiceNote) {
      // The recording is the message. Reading the text over it would talk
      // across the person the user recorded.
      return;
    }

    final speech = _speech ?? ref.read(reminderSpeechServiceProvider);
    if (speech == null) return;
    _speech = speech;
    if (!_speechAvailable) {
      _speechAvailable = await speech.isAvailable();
    }
    if (_speechAvailable && mounted) {
      _speak();
    }
  }

  Future<bool> _setSpeakerphone(bool enabled) async {
    try {
      final routed = await _audioChannel.invokeMethod<bool>('setSpeakerphone', {
        'enabled': enabled,
      });
      return routed ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Widget tests and non-Android builds have no native audio route.
      return false;
    }
  }

  Future<void> _toggleSpeakerphone() async {
    HapticFeedback.selectionClick();
    final next = !_speakerEnabled;
    final routed = await _setSpeakerphone(next);
    if (!mounted) return;
    if (routed) {
      setState(() => _speakerEnabled = next);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Speaker and earpiece routing is not available on this device.',
          ),
        ),
      );
    }
  }

  Future<void> _resetAudioRoute() async {
    try {
      await _audioChannel.invokeMethod<void>('resetAudioRoute');
    } on PlatformException {
      // The call UI can still close if Android audio routing is unavailable.
    } on MissingPluginException {
      // Expected in widget tests and non-Android builds.
    }
  }

  Future<void> _playDialTone(String key) async {
    try {
      await _audioChannel.invokeMethod<void>('playDialTone', {'key': key});
    } on PlatformException {
      // A missing tone is cosmetic; the key still works.
    } on MissingPluginException {
      // Expected in widget tests and non-Android builds.
    }
  }

  Future<void> _hangUp() async {
    HapticFeedback.mediumImpact();
    _callTimer?.cancel();
    _ringTimer?.cancel();
    await _speech?.stop();
    await _stopRinging();
    unawaited(_resetAudioRoute());
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
    if (available && autoSpeak && !_reminder.hasVoiceNote && !_isAnswered) {
      await _speak();
    }
  }

  Future<void> _speak() async {
    final speech = _speech ?? ref.read(reminderSpeechServiceProvider);
    if (speech == null || !mounted || _speaking) return;
    HapticFeedback.lightImpact();
    setState(() => _speaking = true);
    try {
      await speech.speak(_spokenText);
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : 'The reminder could not be read aloud.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    _callTimer?.cancel();
    _ringTimer?.cancel();
    await _stopSpeech();
    await _stopRinging();
    unawaited(_resetAudioRoute());
    await ref.read(reminderActionControllerProvider).snooze(_reminder.id);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _dismiss() async {
    HapticFeedback.mediumImpact();
    _callTimer?.cancel();
    _ringTimer?.cancel();
    await _stopSpeech();
    await _stopRinging();
    unawaited(_resetAudioRoute());
    await ref
        .read(reminderActionControllerProvider)
        .dismissOccurrence(_reminder.id);
    if (mounted) Navigator.of(context).maybePop();
  }

  /// Dialpad keys 1–3 answer the reminder. The rest behave like a real keypad
  /// so the surface feels familiar, and each press gives an audible tone.
  Future<void> _pressKey(String key) async {
    HapticFeedback.selectionClick();
    unawaited(_playDialTone(key));
    switch (key) {
      case '1':
        await _dismiss();
      case '2':
        await _snooze();
      case '3':
        await _hangUp();
      default:
        if (mounted) setState(() => _dialed = '$_dialed$key');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final time = AppDateFormatters.formatTime(_reminder.scheduledDateTime);
    final autoSpeak =
        ref.watch(spokenRemindersEnabledProvider).asData?.value ?? false;
    final callerNumber = _reminder.callerNumber;
    final description = _reminder.description;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          Text(
            _isAnswered
                ? 'CONNECTED • $_formattedCallDuration'
                : (_ringing ? 'INCOMING CALL' : 'MISSED CALL'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: _isAnswered ? colors.primary : colors.onSurfaceVariant,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
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
                  const SizedBox(height: AppSpacing.xxl),
                  _CallerBadge(
                    label: _initials(_reminder.callerName ?? _reminder.title),
                    icon: _reminder.hasCallerPersona
                        ? iconForCallerIcon(_reminder.callerIcon)
                        : null,
                    imagePath: _reminder.callerImagePath,
                    size: _isAnswered ? 96 : 120,
                    ringing: _ringing && !_isAnswered,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _reminder.callerName ?? _reminder.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (callerNumber != null && callerNumber.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      callerNumber,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                  if (_reminder.hasCallerPersona) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ReminderPill(text: _reminder.title),
                  ],
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _reminder.recurrence.summary,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (_isAnswered) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _InCallControls(
                      speakerEnabled: _speakerEnabled,
                      showKeypad: _showKeypad,
                      speechAvailable: _speechAvailable,
                      speaking: _speaking,
                      onSpeaker: _toggleSpeakerphone,
                      onKeypad: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showKeypad = !_showKeypad);
                      },
                      onReadAloud: _speaking ? _stopSpeech : _speak,
                    ),
                    if (_showKeypad) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _Dialpad(dialed: _dialed, onKey: _pressKey),
                    ],
                  ],
                  if (_reminder.hasVoiceNote) ...[
                    const SizedBox(height: AppSpacing.md),
                    VoiceNotePlayerWidget(
                      fileNameOrPath: _reminder.voiceNotePath!,
                      totalDuration: _reminder.voiceNoteDuration,
                      autoPlay: autoSpeak || _isAnswered,
                    ),
                  ] else if (!_isAnswered && _speechAvailable) ...[
                    const SizedBox(height: AppSpacing.xs),
                    TextButton.icon(
                      onPressed: _speaking ? _stopSpeech : _speak,
                      icon: Icon(
                        _speaking
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_rounded,
                      ),
                      label: Text(_speaking ? 'Stop reading' : 'Read aloud'),
                    ),
                  ] else if (!_isAnswered && autoSpeak) ...[
                    // The setting is on but the device cannot speak. Say so
                    // rather than failing silently.
                    const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.sm),
          if (_isAnswered) ...[
            _EndCallButton(onPressed: _hangUp),
          ] else ...[
            if (_ringing)
              TextButton.icon(
                onPressed: _snooze,
                icon: const Icon(Icons.snooze_rounded),
                label: const Text('Snooze for 10 minutes'),
              )
            else
              const SizedBox(height: AppSpacing.xxxl),
            const SizedBox(height: AppSpacing.xs),
            if (_ringing)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _IncomingCallAction(
                    icon: Icons.call_end_rounded,
                    label: 'Decline',
                    color: AppCallColors.decline,
                    onPressed: _dismiss,
                  ),
                  _IncomingCallAction(
                    icon: Icons.call_rounded,
                    label: 'Answer',
                    color: AppCallColors.answer,
                    onPressed: _answerCall,
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _dismiss,
                  child: const Text('Close'),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
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

class _ReminderPill extends StatelessWidget {
  const _ReminderPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.circle),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InCallControls extends StatelessWidget {
  const _InCallControls({
    required this.speakerEnabled,
    required this.showKeypad,
    required this.speechAvailable,
    required this.speaking,
    required this.onSpeaker,
    required this.onKeypad,
    required this.onReadAloud,
  });

  final bool speakerEnabled;
  final bool showKeypad;
  final bool speechAvailable;
  final bool speaking;
  final VoidCallback onSpeaker;
  final VoidCallback onKeypad;
  final VoidCallback onReadAloud;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.xl,
      runSpacing: AppSpacing.md,
      children: [
        _CallControl(
          icon: speakerEnabled
              ? Icons.volume_up_rounded
              : Icons.phone_in_talk_rounded,
          label: speakerEnabled ? 'Speaker' : 'Earpiece',
          selected: speakerEnabled,
          onPressed: onSpeaker,
        ),
        _CallControl(
          icon: Icons.dialpad_rounded,
          label: 'Keypad',
          selected: showKeypad,
          onPressed: onKeypad,
        ),
        if (speechAvailable)
          _CallControl(
            icon: speaking ? Icons.stop_rounded : Icons.record_voice_over,
            label: speaking ? 'Stop' : 'Read again',
            selected: speaking,
            onPressed: onReadAloud,
          ),
      ],
    );
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: IconButton.filledTonal(
                onPressed: onPressed,
                tooltip: label,
                style: IconButton.styleFrom(
                  backgroundColor: selected
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                  foregroundColor: selected
                      ? colors.onPrimary
                      : colors.onSurface,
                ),
                icon: Icon(icon),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _Dialpad extends StatelessWidget {
  const _Dialpad({required this.dialed, required this.onKey});

  final String dialed;
  final ValueChanged<String> onKey;

  static const _keys = <(String, String)>[
    ('1', ''),
    ('2', 'ABC'),
    ('3', 'DEF'),
    ('4', 'GHI'),
    ('5', 'JKL'),
    ('6', 'MNO'),
    ('7', 'PQRS'),
    ('8', 'TUV'),
    ('9', 'WXYZ'),
    ('*', ''),
    ('0', '+'),
    ('#', ''),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Text(
            dialed.isEmpty ? ' ' : dialed,
            style: theme.textTheme.headlineSmall?.copyWith(
              letterSpacing: 3,
              color: colors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            children: [
              for (var row = 0; row < 4; row++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var column = 0; column < 3; column++)
                      _DialpadKey(
                        digit: _keys[row * 3 + column].$1,
                        letters: _keys[row * 3 + column].$2,
                        actionLabel: switch (_keys[row * 3 + column].$1) {
                          '1' => 'Done',
                          '2' => 'Snooze',
                          '3' => 'Keep',
                          _ => null,
                        },
                        onPressed: () => onKey(_keys[row * 3 + column].$1),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '1 Done · 2 Snooze · 3 Keep active',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DialpadKey extends StatelessWidget {
  const _DialpadKey({
    required this.digit,
    required this.letters,
    required this.actionLabel,
    required this.onPressed,
  });

  final String digit;
  final String letters;
  final String? actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      child: Semantics(
        button: true,
        label: actionLabel == null ? digit : '$digit, $actionLabel',
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceContainerHighest,
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  digit,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
                if (letters.isNotEmpty)
                  Text(
                    letters,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  )
                else if (actionLabel != null)
                  Text(
                    actionLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hang up',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppCallColors.decline,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.call_end_rounded, size: 32),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Hang up', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _CallerBadge extends ConsumerStatefulWidget {
  const _CallerBadge({
    required this.label,
    this.icon,
    this.imagePath,
    this.size = 112,
    this.ringing = false,
  });

  final String label;
  final IconData? icon;
  final String? imagePath;
  final double size;
  final bool ringing;

  @override
  ConsumerState<_CallerBadge> createState() => _CallerBadgeState();
}

class _CallerBadgeState extends ConsumerState<_CallerBadge>
    with SingleTickerProviderStateMixin {
  String? _resolvedPath;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      lowerBound: 1,
      upperBound: 1.06,
    );
    if (widget.imagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(_CallerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ringing != widget.ringing) _syncPulse();
    if (oldWidget.imagePath != widget.imagePath) {
      if (widget.imagePath != null) {
        _resolve();
      } else {
        setState(() => _resolvedPath = null);
      }
    }
  }

  /// The badge only breathes while it rings, and never when the system asks
  /// for reduced motion. Leaving the controller ticking in the background
  /// would also keep the screen awake for no visible reason.
  void _syncPulse() {
    final shouldPulse =
        widget.ringing && !MediaQuery.disableAnimationsOf(context);
    if (shouldPulse) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      if (_pulse.isAnimating) _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final badge = Semantics(
      label: hasImage ? 'Caller profile picture' : 'Reminder icon',
      child: Container(
        width: widget.size,
        height: widget.size,
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
                      size: widget.size * 0.46,
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

    if (!widget.ringing || reduceMotion) return badge;
    return ScaleTransition(scale: _pulse, child: badge);
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
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Column(
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
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
