import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utilities/date_formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../controllers/reminder_providers.dart';
import 'reminder_form_screen.dart';

/// A calm, focused view of a reminder's details and actions.
class ReminderDetailScreen extends ConsumerWidget {
  const ReminderDetailScreen({super.key, required this.reminderId});

  final String reminderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remindersAsync = ref.watch(remindersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder'),
        actions: [
          remindersAsync.maybeWhen(
            data: (reminders) {
              final reminder = reminders
                  .where((item) => item.id == reminderId)
                  .firstOrNull;
              if (reminder == null) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit reminder',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ReminderFormScreen(initialReminder: reminder),
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
        loading: () => const ResponsiveCenter(
          child: Center(child: Text('Reading reminder…')),
        ),
        error: (_, _) => ResponsiveCenter(
          child: EmptyStateView(
            icon: Icons.error_outline_rounded,
            title: 'Could not load this reminder',
            description: 'Something went wrong reading it from this device.',
            actionLabel: 'Go back',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        ),
        data: (reminders) {
          final reminder = reminders
              .where((item) => item.id == reminderId)
              .firstOrNull;

          if (reminder == null) {
            return ResponsiveCenter(
              child: EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'Reminder not found',
                description: 'This reminder may have been deleted.',
                actionLabel: 'Back to reminders',
                onAction: () => Navigator.of(context).maybePop(),
              ),
            );
          }

          final isCompleted = reminder.isCompleted;

          return ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              children: [
                // Status & Recurrence Badges
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? colors.surfaceContainerHighest
                            : colors.tertiaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCompleted
                                ? Icons.check_circle_outline_rounded
                                : Icons.alarm_rounded,
                            size: 16,
                            color: isCompleted
                                ? colors.onSurfaceVariant
                                : colors.onTertiaryContainer,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              isCompleted ? 'Completed' : 'Active Reminder',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isCompleted
                                    ? colors.onSurfaceVariant
                                    : colors.onTertiaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (reminder.isRecurring)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                reminder.recurrence.summary,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Main Title
                Text(
                  reminder.title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                  ),
                ),

                // Optional Description / Notes
                if (reminder.description != null &&
                    reminder.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Material(
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.surface),
                      side: BorderSide(color: colors.outline),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        reminder.description!.trim(),
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                // Schedule Details Panel
                Material(
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.surface),
                    side: BorderSide(color: colors.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Scheduled For',
                          value: AppDateFormatters.formatFullDate(
                            reminder.scheduledDateTime,
                          ),
                        ),
                        Divider(
                          height: AppSpacing.md,
                          color: colors.outlineVariant,
                        ),
                        _DetailRow(
                          icon: Icons.schedule_rounded,
                          label: 'Time',
                          value: AppDateFormatters.formatTime(
                            reminder.scheduledDateTime,
                          ),
                        ),
                        if (reminder.isRecurring) ...[
                          Divider(
                            height: AppSpacing.md,
                            color: colors.outlineVariant,
                          ),
                          _DetailRow(
                            icon: Icons.repeat_rounded,
                            label: 'Recurrence',
                            value: reminder.recurrence.summary,
                          ),
                        ],
                        if (reminder.completedAt != null) ...[
                          Divider(
                            height: AppSpacing.md,
                            color: colors.outlineVariant,
                          ),
                          _DetailRow(
                            icon: Icons.check_circle_rounded,
                            label: 'Completed On',
                            value: AppDateFormatters.formatSchedule(
                              reminder.completedAt!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Primary Action: Toggle Status
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.minTouchTarget,
                  child: FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(reminderActionControllerProvider)
                          .toggleStatus(reminder.id);
                    },
                    icon: Icon(
                      isCompleted ? Icons.replay_rounded : Icons.check_rounded,
                      size: 20,
                    ),
                    label: Text(
                      isCompleted ? 'Mark as Active' : 'Mark as Completed',
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Secondary Action: Delete
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.minTouchTarget,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(
                      context,
                      ref,
                      reminder.id,
                      reminder.title,
                    ),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                      size: 20,
                    ),
                    label: Text(
                      'Delete Reminder',
                      style: TextStyle(color: colors.error),
                    ),
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
    String id,
    String title,
  ) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('Remove “$title” from your reminders?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep reminder'),
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

    if (confirm == true && context.mounted) {
      await ref.read(reminderActionControllerProvider).deleteReminder(id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
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
    final colors = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
