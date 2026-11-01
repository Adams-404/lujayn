import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_theme_choice.dart';

/// A plain, accessible theme selector with a preview of each palette.
class ThemePicker extends StatelessWidget {
  const ThemePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AppThemeChoice selected;
  final ValueChanged<AppThemeChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    final choices = AppThemeChoice.values;
    return Column(
      children: [
        for (var index = 0; index < choices.length; index++) ...[
          if (index > 0) const Divider(height: 1),
          _ThemeOption(
            choice: choices[index],
            selected: selected == choices[index],
            onTap: () => onSelected(choices[index]),
          ),
        ],
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final AppThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSystem = choice == AppThemeChoice.system;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSystem
                      ? theme.colorScheme.surfaceContainerHighest
                      : AppTheme.accentFor(choice),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Icon(
                  isSystem
                      ? Icons.brightness_auto_rounded
                      : (choice.isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded),
                  size: 18,
                  color: isSystem
                      ? theme.colorScheme.onSurface
                      : AppTheme.onAccentFor(choice),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      choice.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(choice.description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
              else
                Icon(Icons.circle_outlined, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
