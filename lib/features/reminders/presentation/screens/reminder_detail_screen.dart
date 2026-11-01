import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/date_formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../controllers/reminder_providers.dart';
import 'reminder_form_screen.dart';

/// A focused view of one reminder and the actions available for it.
class ReminderDetailScreen extends ConsumerWidget {
  const ReminderDetailScreen({super.key, required this.reminderId});

  final String reminderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final remindersAsync = ref.watch(remindersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder'),
        actions: [
          remindersAsync.maybeWhen(
            data: (reminders) {
              final reminder = reminders.where((item) => item.id == reminderId).firstOrNull;
              if (reminder == null) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit reminder',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReminderFormScreen(initialReminder: reminder),
                    ),
                  );
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyStateView(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load this reminder',
          description: 'Go back and try opening it again.',
        ),
        data: (reminders) {
          final reminder = reminders.where((item) => item.id == reminderId).firstOrNull;
          if (reminder == null) {
            return EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'Reminder not found',
              description: 'It may have been deleted.',
              actionLabel: 'Back to reminders',
              onAction: () => Navigator.of(context).pop(),
            );
          }

          final completed = reminder.isCompleted;
          final colors = theme.colorScheme;

          return ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 36),
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: completed ? colors.tertiary : colors.primary,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      completed ? 'COMPLETED' : 'UPCOMING',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    if (reminder.isRecurring) ...[
                      const SizedBox(width: 12),
                      Text(
                        reminder.recurrence.summary,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  AppDateFormatters.formatTime(reminder.scheduledDateTime),
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppDateFormatters.formatFullDate(reminder.scheduledDateTime),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  reminder.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (reminder.description?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  Text(
                    reminder.description!.trim(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Divider(color: colors.outlineVariant),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: AppDateFormatters.formatRelativeDate(
                    reminder.scheduledDateTime,
                  ),
                ),
                Divider(color: colors.outlineVariant),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Time',
                  value: AppDateFormatters.formatTime(reminder.scheduledDateTime),
                ),
                Divider(color: colors.outlineVariant),
                _DetailRow(
                  icon: Icons.repeat_rounded,
                  label: 'Repeats',
                  value: reminder.recurrence.summary,
                ),
                if (reminder.completedAt != null) ...[
                  Divider(color: colors.outlineVariant),
                  _DetailRow(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Completed',
                    value: AppDateFormatters.formatSchedule(reminder.completedAt!),
                  ),
                ],
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: () => ref
                      .read(reminderActionControllerProvider)
                      .toggleStatus(reminder.id),
                  icon: Icon(
                    completed ? Icons.replay_rounded : Icons.check_rounded,
                  ),
                  label: Text(completed ? 'Mark as active' : 'Mark as completed'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, ref, reminder.title),
                  icon: Icon(Icons.delete_outline_rounded, color: colors.error),
                  label: Text(
                    'Delete reminder',
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('Remove “$title” from your reminders?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(reminderActionControllerProvider).deleteReminder(reminderId);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Row(
        children: [
          Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
