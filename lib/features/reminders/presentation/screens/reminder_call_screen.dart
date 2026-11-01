import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/date_formatters.dart';
import '../../domain/models/reminder.dart';
import '../controllers/reminder_providers.dart';

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

class _CallBody extends ConsumerWidget {
  const _CallBody({required this.reminder});

  final Reminder reminder;

  Future<void> _snooze(BuildContext context, WidgetRef ref) async {
    await ref.read(reminderActionControllerProvider).snooze(reminder.id);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    await ref
        .read(reminderActionControllerProvider)
        .dismissOccurrence(reminder.id);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final time = AppDateFormatters.formatTime(reminder.scheduledDateTime);

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
                  _CallerBadge(label: _initials(reminder.title)),
                  const SizedBox(height: 26),
                  Text(
                    reminder.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (reminder.description case final note?
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
                    reminder.recurrence.summary,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _dismiss(context, ref),
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
              onPressed: () => _snooze(context, ref),
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
