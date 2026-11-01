import 'package:flutter/material.dart';
import '../../domain/models/recurrence_rule.dart';

/// Interactive chip selector for recurrence options.
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
      (RecurrenceRule.none, 'One-time', Icons.event_rounded),
      (RecurrenceRule.daily, 'Daily', Icons.repeat_rounded),
      (RecurrenceRule.weekdays, 'Weekdays', Icons.work_outline_rounded),
      (RecurrenceRule.weekly, 'Weekly', Icons.calendar_view_week_rounded),
      (
        RecurrenceRule(
          type: RecurrenceType.customDays,
          daysOfWeek: [DateTime.monday],
        ),
        'Custom days',
        Icons.tune_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final (rule, label, icon) = option;
            final isSelected = selectedRule.type == rule.type;

            return ChoiceChip(
              showCheckmark: false,
              avatar: Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              label: Text(label),
              selected: isSelected,
              selectedColor: theme.colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (theme.colorScheme.outline),
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  onChanged(rule);
                }
              },
            );
          }).toList(),
        ),

        // Custom Days selector if customDays is active
        if (selectedRule.type == RecurrenceType.customDays) ...[
          const SizedBox(height: 12),
          Text('Select repeating days:', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (index) {
              final dayNumber = index + 1;
              final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final fullDayNames = [
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
                'Sunday',
              ];
              final isDaySelected = selectedRule.daysOfWeek.contains(dayNumber);

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isDaySelected,
                  label: fullDayNames[index],
                  child: InkWell(
                    onTap: () {
                      final updatedDays = List<int>.from(
                        selectedRule.daysOfWeek,
                      );
                      if (isDaySelected) {
                        updatedDays.remove(dayNumber);
                      } else {
                        updatedDays.add(dayNumber);
                        updatedDays.sort();
                      }
                      onChanged(
                        RecurrenceRule(
                          type: updatedDays.isEmpty
                              ? RecurrenceType.none
                              : RecurrenceType.customDays,
                          daysOfWeek: updatedDays,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDaySelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            border: Border.all(
                              color: isDaySelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          child: Text(
                            dayNames[index],
                            style: TextStyle(
                              color: isDaySelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
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
