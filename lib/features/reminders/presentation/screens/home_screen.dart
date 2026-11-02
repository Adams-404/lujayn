import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utilities/date_formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/lujayn_mark.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../domain/models/reminder.dart';
import '../../domain/models/reminder_status.dart';
import '../controllers/reminder_providers.dart';
import '../widgets/natural_language_draft_sheet.dart';
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.xl,
                    AppSpacing.gutter,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppDateFormatters.formatFullDate(
                                    DateTime.now(),
                                  ),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Today',
                                  style: theme.textTheme.displayMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.6,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton.filledTonal(
                            onPressed: () => _openQuickDraft(context),
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 20,
                            ),
                            tooltip: 'Draft with plain language',
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: LujaynMark(
                              size: 24,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Here’s what you’ve set aside to remember.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                  child: _ReminderFilters(
                    selected: filter,
                    onSelected: (next) => ref
                        .read(reminderFilterProvider.notifier)
                        .setFilter(next),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              const SliverToBoxAdapter(child: _DeliveryNotice()),
              remindersAsync.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ReminderLoadingState(),
                ),
                error: (_, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateView(
                    icon: Icons.error_outline_rounded,
                    title: 'Your reminders didn’t load',
                    description:
                        'Something went wrong reading them from this device. '
                        'Nothing has been lost — try again.',
                    actionLabel: 'Try again',
                    actionIcon: Icons.refresh_rounded,
                    onAction: () => ref.invalidate(remindersStreamProvider),
                  ),
                ),
                data: (reminders) =>
                    _buildContent(context, ref, reminders, filter),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.fabClearance),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FloatingActionButton.extended(
          onPressed: () => _navigateToCreate(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add reminder'),
        ),
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
      final completed = reminders
          .where((reminder) => reminder.isCompleted)
          .toList();
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
      return SliverFillRemaining(
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

    final overdue = active.where((reminder) => reminder.isPastDue).toList();
    final future = active.where((reminder) => !reminder.isPastDue).toList();
    final next = future.isNotEmpty ? future.first : overdue.first;
    final remaining = active
        .where((reminder) => reminder.id != next.id)
        .toList();
    final overdueRemaining = remaining
        .where((reminder) => reminder.isPastDue)
        .toList();
    final today = remaining
        .where((reminder) => !reminder.isPastDue && reminder.isToday)
        .toList();
    final later = remaining
        .where((reminder) => !reminder.isPastDue && !reminder.isToday)
        .toList();

    return SliverMainAxisGroup(
      slivers: [
        if (overdueRemaining.isNotEmpty) ...[
          _groupHeading(context, 'PAST DUE'),
          ..._timelineSlivers(context, ref, overdueRemaining),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.xs,
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final reminder = reminders[index];
            return ReminderTimelineTile(
              reminder: reminder,
              isLast: index == reminders.length - 1,
              onTap: () => _navigateToDetail(context, reminder.id),
              onToggleStatus: () {
                HapticFeedback.mediumImpact();
                ref
                    .read(reminderActionControllerProvider)
                    .toggleStatus(reminder.id);
              },
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

  Future<void> _openQuickDraft(BuildContext context) async {
    HapticFeedback.lightImpact();
    final draft = await NaturalLanguageDraftSheet.show(context);
    if (draft != null && context.mounted) {
      final initialReminder = Reminder(
        id: const Uuid().v4(),
        title: draft.title,
        scheduledDateTime:
            draft.scheduledDateTime ??
            DateTime.now().add(const Duration(hours: 1)),
        recurrence: draft.recurrence,
        status: ReminderStatus.active,
        callerName: draft.callerName,
        callerNumber: draft.callerNumber,
        callerIcon: draft.callerIcon,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReminderFormScreen(initialReminder: initialReminder),
        ),
      );
    }
  }

  void _navigateToCreate(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReminderFormScreen()));
  }
}

/// A quiet, honest notice when Android is currently blocking reminder delivery.
///
/// Shown only when something is actually wrong, so it never becomes wallpaper.
class _DeliveryNotice extends ConsumerWidget {
  const _DeliveryNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(deliveryReadinessProvider).asData?.value;
    if (readiness == null || !readiness.isLimited) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final blocked = readiness.isBlocked;
    final title = blocked
        ? 'Reminders can’t be shown right now'
        : 'Reminders may arrive late';
    final message = blocked
        ? 'Android is blocking Lujayn’s notifications. Your reminders are still '
              'saved on this device and will appear here.'
        : 'Android is limiting exact alarms, so a reminder may arrive a few '
              'minutes after the time you chose.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.surface),
          border: Border.all(color: colors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  blocked
                      ? Icons.notifications_off_outlined
                      : Icons.schedule_rounded,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final scheduler = ref.read(reminderAlarmSchedulerProvider);
                  if (blocked) {
                    await scheduler.requestNotificationPermission();
                  } else {
                    await scheduler.requestExactAlarmPermission();
                  }
                  ref.invalidate(deliveryReadinessProvider);
                },
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: Text(
                  blocked ? 'Allow notifications' : 'Review settings',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet placeholder while reminders are read from the device.
///
/// A bare spinner on an empty screen reads as a stall. This keeps the page
/// structure visible so the wait feels short and the app feels alive.
class _ReminderLoadingState extends StatelessWidget {
  const _ReminderLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Semantics(
        label: 'Loading your reminders',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Reading your reminders…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderFilters extends StatelessWidget {
  const _ReminderFilters({required this.selected, required this.onSelected});

  final ReminderFilter selected;
  final ValueChanged<ReminderFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final isLargeText = textScaler.scale(14) > 17;

    final options = [
      (ReminderFilter.upcoming, 'Upcoming'),
      (ReminderFilter.completed, 'Completed'),
      (ReminderFilter.all, 'All'),
    ];

    final segments = Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: isLargeText
          ? Wrap(
              spacing: AppSpacing.xxs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final option in options)
                  _SegmentTab(
                    label: option.$2,
                    selected: selected == option.$1,
                    onTap: () => onSelected(option.$1),
                  ),
              ],
            )
          : Row(
              children: [
                for (final option in options)
                  Expanded(
                    child: _SegmentTab(
                      label: option.$2,
                      selected: selected == option.$1,
                      onTap: () => onSelected(option.$1),
                    ),
                  ),
              ],
            ),
    );

    return segments;
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
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
    final colors = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label reminders',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!selected) {
              HapticFeedback.selectionClick();
            }
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? colors.surfaceContainerHighest
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: selected ? colors.outline : Colors.transparent,
                width: 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? colors.primary : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NextReminderPanel extends StatelessWidget {
  const _NextReminderPanel({required this.reminder, required this.onTap});

  final Reminder reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = reminder.isPastDue ? colors.error : colors.primary;

    return Material(
      color: colors.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accent, width: 3),
              top: BorderSide(color: colors.outlineVariant),
              right: BorderSide(color: colors.outlineVariant),
              bottom: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: [
                  Text(
                    reminder.isPastDue ? 'NEEDS ATTENTION' : 'NEXT REMINDER',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Icon(Icons.north_east_rounded, size: 17, color: accent),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                AppDateFormatters.formatTime(reminder.scheduledDateTime),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: accent,
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
                AppDateFormatters.formatRelativeDate(
                  reminder.scheduledDateTime,
                ),
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
