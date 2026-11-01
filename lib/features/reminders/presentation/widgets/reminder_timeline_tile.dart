import 'package:flutter/material.dart';

import '../../../../core/utilities/date_formatters.dart';
import '../../domain/models/reminder.dart';

/// A quiet, time-first row for the daily reminder timeline.
class ReminderTimelineTile extends StatelessWidget {
  const ReminderTimelineTile({
    super.key,
    required this.reminder,
    required this.isLast,
    required this.onTap,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final Reminder reminder;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final completed = reminder.isCompleted;

    return Dismissible(
      key: ValueKey('timeline-${reminder.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colors.errorContainer,
        child: Icon(Icons.delete_outline_rounded, color: colors.onErrorContainer),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete reminder?'),
          content: Text('Remove “${reminder.title}” from your reminders?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep it'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: colors.error),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    AppDateFormatters.formatTime(reminder.scheduledDateTime),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: completed ? colors.onSurfaceVariant : colors.onSurface,
                      fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: completed ? colors.outline : colors.primary,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 1,
                        height: 62,
                        margin: const EdgeInsets.only(top: 5),
                        color: colors.outlineVariant,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: completed ? colors.onSurfaceVariant : colors.onSurface,
                          decoration: completed ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (reminder.description?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 3),
                        Text(
                          reminder.description!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (reminder.isRecurring) ...[
                        const SizedBox(height: 5),
                        Text(
                          reminder.recurrence.summary,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Divider(height: 1, color: colors.outlineVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: completed
                    ? 'Mark “${reminder.title}” active'
                    : 'Mark “${reminder.title}” complete',
                child: IconButton(
                  tooltip: completed ? 'Mark active' : 'Mark complete',
                  onPressed: onToggleStatus,
                  icon: Icon(
                    completed
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: completed ? colors.tertiary : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
