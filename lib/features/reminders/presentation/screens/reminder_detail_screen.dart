import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utilities/date_formatters.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../controllers/reminder_providers.dart';
import 'reminder_form_screen.dart';

/// Screen presenting the full details of a specific reminder.
class ReminderDetailScreen extends ConsumerWidget {
  const ReminderDetailScreen({super.key, required this.reminderId});

  final String reminderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final remindersAsync = ref.watch(remindersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Details'),
        actions: [
          remindersAsync.maybeWhen(
            data: (reminders) {
              final reminder = reminders
                  .where((r) => r.id == reminderId)
                  .firstOrNull;
              if (reminder == null) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit reminder',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Error loading reminder: $error')),
        data: (reminders) {
          final reminder = reminders
              .where((r) => r.id == reminderId)
              .firstOrNull;

          if (reminder == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded, size: 48),
                  const SizedBox(height: 12),
                  const Text('Reminder not found'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Reminders'),
                  ),
                ],
              ),
            );
          }

          final isCompleted = reminder.isCompleted;

          return ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Status Badge & Schedule
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? (isDark
                                  ? AppColors.darkSurfaceSubtle
                                  : AppColors.statusCompletedSubtle)
                            : (isDark
                                  ? AppColors.darkSurfaceSubtle
                                  : AppColors.calmSageSubtle),
                        borderRadius: BorderRadius.circular(8),
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
                                ? (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.statusCompleted)
                                : AppColors.calmSage,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isCompleted ? 'Completed' : 'Active Reminder',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isCompleted
                                  ? (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.statusCompleted)
                                  : AppColors.calmSage,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (reminder.isRecurring)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceSubtle
                              : AppColors.lightSurfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          reminder.recurrence.summary,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Main Title
                Text(
                  reminder.title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),

                // Optional Description
                if (reminder.description != null &&
                    reminder.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Text(
                      reminder.description!.trim(),
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Schedule Details Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Scheduled For',
                          value: AppDateFormatters.formatFullDate(
                            reminder.scheduledDateTime,
                          ),
                        ),
                        const Divider(height: 24),
                        _DetailRow(
                          icon: Icons.schedule_rounded,
                          label: 'Time',
                          value: AppDateFormatters.formatTime(
                            reminder.scheduledDateTime,
                          ),
                        ),
                        const Divider(height: 24),
                        _DetailRow(
                          icon: Icons.repeat_rounded,
                          label: 'Recurrence',
                          value: reminder.recurrence.summary,
                        ),
                        if (reminder.completedAt != null) ...[
                          const Divider(height: 24),
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

                const SizedBox(height: 32),

                // Primary Actions
                FilledButton.icon(
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

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete reminder?'),
                        content: Text(
                          'Are you sure you want to delete "${reminder.title}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.statusDanger,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      await ref
                          .read(reminderActionControllerProvider)
                          .deleteReminder(reminder.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.statusDanger,
                    size: 20,
                  ),
                  label: const Text(
                    'Delete Reminder',
                    style: TextStyle(color: AppColors.statusDanger),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
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
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.slateTealLight,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
