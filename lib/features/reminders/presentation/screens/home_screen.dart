import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/date_formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../domain/models/reminder.dart';
import '../controllers/reminder_providers.dart';
import '../widgets/reminder_timeline_tile.dart';
import 'reminder_detail_screen.dart';
import 'reminder_form_screen.dart';

/// A calm, time-first view of what the user has asked Lujayn to remember.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reminderFilterProvider);
    final remindersAsync = ref.watch(remindersStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppDateFormatters.formatFullDate(DateTime.now()),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Today', style: theme.textTheme.displayLarge),
                      const SizedBox(height: 5),
                      Text(
                        'Here’s what you’ve set aside to remember.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: _ReminderFilters(
                    selected: filter,
                    onSelected: (next) => ref
                        .read(reminderFilterProvider.notifier)
                        .setFilter(next),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              remindersAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Your reminders couldn’t be loaded. Please try again.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
                data: (reminders) => _buildContent(
                  context,
                  ref,
                  reminders,
                  filter,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreate(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add reminder'),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Reminder> reminders,
    ReminderFilter filter,
  ) {
    if (filter == ReminderFilter.completed) {
      final completed = reminders.where((reminder) => reminder.isCompleted).toList();
      if (completed.isEmpty) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateView(
            icon: Icons.check_circle_outline_rounded,
            title: 'Nothing completed yet',
            description: 'Reminders you complete will be kept here.',
          ),
        );
      }
      return _timelineGroup(context, ref, 'COMPLETED', completed);
    }

    if (filter == ReminderFilter.all) {
      if (reminders.isEmpty) return _emptyState(context);
      return _timelineGroup(context, ref, 'ALL REMINDERS', reminders);
    }

    final active = reminders.where((reminder) => reminder.isActive).toList();
    if (active.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyStateView(
          icon: Icons.notifications_none_rounded,
          title: 'Nothing waiting for you',
          description: 'When you add a reminder, it will appear here.',
          actionLabel: 'Add reminder',
          onAction: () => _navigateToCreate(context),
        ),
      );
    }

    final now = DateTime.now();
    final next = active.firstWhere(
      (reminder) => reminder.scheduledDateTime.isAfter(now),
      orElse: () => active.first,
    );
    final remaining = active.where((reminder) => reminder.id != next.id).toList();
    final today = remaining.where((reminder) => reminder.isToday).toList();
    final later = remaining.where((reminder) => !reminder.isToday).toList();

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _NextReminderPanel(
              reminder: next,
              onTap: () => _navigateToDetail(context, next.id),
            ),
          ),
        ),
        if (today.isNotEmpty) ...[
          _groupHeading(context, 'ALSO TODAY'),
          ..._timelineSlivers(context, ref, today),
        ],
        if (later.isNotEmpty) ...[
          _groupHeading(context, 'COMING UP'),
          ..._timelineSlivers(context, ref, later),
        ],
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: EmptyStateView(
        icon: Icons.notifications_none_rounded,
        title: 'No reminders yet',
        description: 'Add the first thing you want Lujayn to remember.',
        actionLabel: 'Add reminder',
        onAction: () => _navigateToCreate(context),
      ),
    );
  }

  Widget _groupHeading(BuildContext context, String title) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
        child: Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  List<Widget> _timelineSlivers(
    BuildContext context,
    WidgetRef ref,
    List<Reminder> reminders,
  ) {
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final reminder = reminders[index];
            return ReminderTimelineTile(
              reminder: reminder,
              isLast: index == reminders.length - 1,
              onTap: () => _navigateToDetail(context, reminder.id),
              onToggleStatus: () => ref
                  .read(reminderActionControllerProvider)
                  .toggleStatus(reminder.id),
              onDelete: () => ref
                  .read(reminderActionControllerProvider)
                  .deleteReminder(reminder.id),
            );
          }, childCount: reminders.length),
        ),
      ),
    ];
  }

  Widget _timelineGroup(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<Reminder> reminders,
  ) {
    return SliverMainAxisGroup(
      slivers: [
        _groupHeading(context, title),
        ..._timelineSlivers(context, ref, reminders),
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

class _ReminderFilters extends StatelessWidget {
  const _ReminderFilters({
    required this.selected,
    required this.onSelected,
  });

  final ReminderFilter selected;
  final ValueChanged<ReminderFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = [
      (ReminderFilter.upcoming, 'Upcoming'),
      (ReminderFilter.completed, 'Completed'),
      (ReminderFilter.all, 'All'),
    ];

    return Row(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(width: 22),
          _FilterTab(
            label: options[index].$2,
            selected: selected == options[index].$1,
            onTap: () => onSelected(options[index].$1),
          ),
        ],
      ],
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 7),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 24 : 0,
                height: 2,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextReminderPanel extends StatelessWidget {
  const _NextReminderPanel({
    required this.reminder,
    required this.onTap,
  });

  final Reminder reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: colors.primary, width: 3),
              top: BorderSide(color: colors.outlineVariant),
              right: BorderSide(color: colors.outlineVariant),
              bottom: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'NEXT REMINDER',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.north_east_rounded, size: 17, color: colors.primary),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                AppDateFormatters.formatTime(reminder.scheduledDateTime),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                reminder.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (reminder.description?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 5),
                Text(
                  reminder.description!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                AppDateFormatters.formatRelativeDate(reminder.scheduledDateTime),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
