import 'package:flutter/material.dart';
import '../../../../core/utilities/date_formatters.dart';
import '../../domain/models/reminder.dart';

/// Clean, personal card displaying an individual reminder.
class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onTap,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final Reminder reminder;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = reminder.isCompleted;

    return Dismissible(
      key: ValueKey('reminder-${reminder.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.error,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete reminder?'),
            content: Text(
              'Are you sure you want to remove "${reminder.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom accessible toggle circle
                Semantics(
                  label: isCompleted
                      ? 'Mark "${reminder.title}" as active'
                      : 'Mark "${reminder.title}" as completed',
                  button: true,
                  child: InkResponse(
                    onTap: onToggleStatus,
                    radius: 24,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, right: 14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? (theme.colorScheme.surfaceContainerHighest)
                              : Colors.transparent,
                          border: Border.all(
                            color: isCompleted
                                ? (theme.colorScheme.outline)
                                : theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: isCompleted
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // Reminder Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Schedule and Recurrence metadata
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: isCompleted
                                    ? (theme.colorScheme.onSurfaceVariant)
                                    : theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppDateFormatters.formatSchedule(
                                  reminder.scheduledDateTime,
                                ),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (reminder.isRecurring)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                reminder.recurrence.summary,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        reminder.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted
                              ? (theme.colorScheme.onSurfaceVariant)
                              : (theme.colorScheme.onSurface),
                        ),
                      ),

                      // Description
                      if (reminder.description != null &&
                          reminder.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reminder.description!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isCompleted
                                ? (theme.colorScheme.onSurfaceVariant)
                                : (theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
