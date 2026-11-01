import 'package:flutter/material.dart';

import '../../domain/models/recurrence_rule.dart';

/// Compact recurrence choices with a separate weekday selector when needed.
class RecurrenceChipSelector extends StatelessWidget {
  const RecurrenceChipSelector({
    super.key,
    required this.selectedRule,
    required this.onChanged,
  });

  final RecurrenceRule selectedRule;
  final ValueChanged<RecurrenceRule> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = [
      (RecurrenceRule.none, 'One-time'),
      (RecurrenceRule.daily, 'Daily'),
      (RecurrenceRule.weekdays, 'Weekdays'),
      (RecurrenceRule.weekly, 'Weekly'),
      (const RecurrenceRule(type: RecurrenceType.customDays), 'Custom'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final (rule, label) = option;
            final selected = selectedRule.type == rule.type;

            return Semantics(
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onChanged(rule),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (selectedRule.type == RecurrenceType.customDays) ...[
          const SizedBox(height: 16),
          Text(
            'Repeat on',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayNumber = index + 1;
              const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final selected = selectedRule.daysOfWeek.contains(dayNumber);

              return Semantics(
                button: true,
                selected: selected,
                label: [
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday',
                ][index],
                child: InkWell(
                  onTap: () {
                    final days = List<int>.from(selectedRule.daysOfWeek);
                    if (selected) {
                      days.remove(dayNumber);
                    } else {
                      days.add(dayNumber);
                      days.sort();
                    }
                    onChanged(
                      RecurrenceRule(
                        type: days.isEmpty
                            ? RecurrenceType.none
                            : RecurrenceType.customDays,
                        daysOfWeek: days,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    width: 44,
                    height: 48,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                        ),
                        child: Text(
                          dayNames[index],
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
