import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utilities/date_formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../../core/widgets/section_header.dart';
import '../../domain/models/reminder.dart';
import '../controllers/reminder_providers.dart';
import '../widgets/reminder_card.dart';
import 'reminder_detail_screen.dart';
import 'reminder_form_screen.dart';

/// The primary home screen of Lujayn, presenting active and upcoming reminders.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentFilter = ref.watch(reminderFilterProvider);
    final remindersAsync = ref.watch(remindersStreamProvider);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: CustomScrollView(
            slivers: [
              // Header Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Label
                      Text(
                        AppDateFormatters.formatFullDate(DateTime.now()),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Title
                      Text(
                        'Upcoming reminders',
                        style: theme.textTheme.displayMedium,
                      ),
                      const SizedBox(height: 6),
                      // Active Count subtitle
                      remindersAsync.maybeWhen(
                        data: (reminders) {
                          final activeCount = reminders
                              .where((r) => r.isActive)
                              .length;
                          return Text(
                            activeCount == 0
                                ? 'No reminders scheduled'
                                : '$activeCount active ${activeCount == 1 ? 'reminder' : 'reminders'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 20),

                      // Filter Segmented Buttons
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'Upcoming',
                              isSelected:
                                  currentFilter == ReminderFilter.upcoming,
                              onTap: () => ref
                                  .read(reminderFilterProvider.notifier)
                                  .setFilter(ReminderFilter.upcoming),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Completed',
                              isSelected:
                                  currentFilter == ReminderFilter.completed,
                              onTap: () => ref
                                  .read(reminderFilterProvider.notifier)
                                  .setFilter(ReminderFilter.completed),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'All',
                              isSelected: currentFilter == ReminderFilter.all,
                              onTap: () => ref
                                  .read(reminderFilterProvider.notifier)
                                  .setFilter(ReminderFilter.all),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Reminders Content
              remindersAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SliverFillRemaining(
                  child: Center(
                    child: Text('Could not load reminders: $error'),
                  ),
                ),
                data: (allReminders) {
                  return _buildRemindersList(
                    context,
                    ref,
                    allReminders,
                    currentFilter,
                  );
                },
              ),

              // Bottom padding for FAB clearance
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ReminderFormScreen()));
        },
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('New Reminder'),
      ),
    );
  }

  Widget _buildRemindersList(
    BuildContext context,
    WidgetRef ref,
    List<Reminder> allReminders,
    ReminderFilter filter,
  ) {
    if (filter == ReminderFilter.completed) {
      final completed = allReminders.where((r) => r.isCompleted).toList();
      if (completed.isEmpty) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateView(
            icon: Icons.check_circle_outline_rounded,
            title: 'No completed reminders',
            description:
                'Completed reminders will appear here for easy review and restoration.',
          ),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final reminder = completed[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReminderCard(
                reminder: reminder,
                onTap: () => _navigateToDetail(context, reminder.id),
                onToggleStatus: () => ref
                    .read(reminderActionControllerProvider)
                    .toggleStatus(reminder.id),
                onDelete: () => ref
                    .read(reminderActionControllerProvider)
                    .deleteReminder(reminder.id),
              ),
            );
          }, childCount: completed.length),
        ),
      );
    }

    if (filter == ReminderFilter.all) {
      if (allReminders.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateView(
            icon: Icons.alarm_outlined,
            title: 'No reminders yet',
            description: 'Create your first reminder to experience Lujayn.',
            actionLabel: 'Create Reminder',
            onAction: () => _navigateToCreate(context),
          ),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final reminder = allReminders[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReminderCard(
                reminder: reminder,
                onTap: () => _navigateToDetail(context, reminder.id),
                onToggleStatus: () => ref
                    .read(reminderActionControllerProvider)
                    .toggleStatus(reminder.id),
                onDelete: () => ref
                    .read(reminderActionControllerProvider)
                    .deleteReminder(reminder.id),
              ),
            );
          }, childCount: allReminders.length),
        ),
      );
    }

    // Default: Upcoming filter
    final active = allReminders.where((r) => r.isActive).toList();
    if (active.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyStateView(
          icon: Icons.spa_outlined,
          title: 'All caught up',
          description:
              'No upcoming reminders. Enjoy the calm, or create one for what matters.',
          actionLabel: 'New Reminder',
          onAction: () => _navigateToCreate(context),
        ),
      );
    }

    final today = active.where((r) => r.isToday).toList();
    final later = active.where((r) => !r.isToday).toList();

    return SliverMainAxisGroup(
      slivers: [
        if (today.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(title: 'Today', badge: '${today.length}'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final reminder = today[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ReminderCard(
                    reminder: reminder,
                    onTap: () => _navigateToDetail(context, reminder.id),
                    onToggleStatus: () => ref
                        .read(reminderActionControllerProvider)
                        .toggleStatus(reminder.id),
                    onDelete: () => ref
                        .read(reminderActionControllerProvider)
                        .deleteReminder(reminder.id),
                  ),
                );
              }, childCount: today.length),
            ),
          ),
        ],
        if (later.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Later & Recurring',
              badge: '${later.length}',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final reminder = later[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ReminderCard(
                    reminder: reminder,
                    onTap: () => _navigateToDetail(context, reminder.id),
                    onToggleStatus: () => ref
                        .read(reminderActionControllerProvider)
                        .toggleStatus(reminder.id),
                    onDelete: () => ref
                        .read(reminderActionControllerProvider)
                        .deleteReminder(reminder.id),
                  ),
                );
              }, childCount: later.length),
            ),
          ),
        ],
      ],
    );
  }

  void _navigateToDetail(BuildContext context, String reminderId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReminderDetailScreen(reminderId: reminderId),
      ),
    );
  }

  void _navigateToCreate(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReminderFormScreen()));
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.slateTeal
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.slateTeal
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected
                ? Colors.white
                : (isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
