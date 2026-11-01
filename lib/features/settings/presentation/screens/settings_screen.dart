import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme_choice.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../reminders/presentation/controllers/reminder_providers.dart';
import '../controllers/settings_providers.dart';
import '../widgets/principles_dialog.dart';
import '../widgets/theme_picker.dart';

/// Settings, privacy information, and appearance controls.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedTheme =
        ref.watch(themeChoiceProvider).asData?.value ?? AppThemeChoice.system;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: colors.tertiary, size: 22),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy by default',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your reminders stay on this device. No account, ads, tracking, or cloud sync.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _SectionHeading(title: 'APPEARANCE'),
            ThemePicker(
              selected: selectedTheme,
              onSelected: (choice) async {
                try {
                  await ref.read(themeChoiceProvider.notifier).select(choice);
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not save your appearance setting.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 30),

            _SectionHeading(title: 'PRIVACY & DATA'),
            _SettingsRow(
              icon: Icons.shield_outlined,
              title: 'Product principles',
              subtitle: 'The nine principles behind Lujayn',
              onTap: () => showDialog(
                context: context,
                builder: (_) => const PrinciplesDialog(),
              ),
            ),
            const Divider(height: 1),
            const _SettingsRow(
              icon: Icons.storage_outlined,
              title: 'Data storage',
              subtitle: 'Saved locally on this device using SQLite',
            ),
            const Divider(height: 1),
            const _SettingsRow(
              icon: Icons.download_for_offline_outlined,
              title: 'Encrypted backup & export',
              subtitle: 'Not available yet. Your data remains on this device.',
            ),
            const Divider(height: 1),
            _SettingsRow(
              icon: Icons.delete_sweep_outlined,
              title: 'Clear all reminders',
              subtitle: 'Permanently remove every saved reminder',
              iconColor: colors.error,
              titleColor: colors.error,
              onTap: () => _confirmClearAll(context, ref),
            ),
            const SizedBox(height: 30),

            _SectionHeading(title: 'REMINDER DELIVERY'),
            const _SettingsRow(
              icon: Icons.alarm_on_outlined,
              title: 'Exact alarms',
              subtitle: 'Android alarm scheduling is being added next.',
            ),
            const Divider(height: 1),
            const _SettingsRow(
              icon: Icons.ring_volume_outlined,
              title: 'Call-style reminders',
              subtitle: 'The incoming-call reminder screen is not active yet.',
            ),
            const Divider(height: 1),
            const _SettingsRow(
              icon: Icons.battery_saver_outlined,
              title: 'Battery restrictions',
              subtitle: 'Device-specific guidance will appear during alarm setup.',
            ),
            const SizedBox(height: 30),

            _SectionHeading(title: 'ABOUT'),
            Text(
              'Lujayn',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'A personal reminder companion that respects your privacy, stays on your device, and helps you remember what matters.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Early build',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all reminders?'),
        content: const Text(
          'This permanently deletes every reminder stored on this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep reminders'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(reminderActionControllerProvider).clearAll();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All reminders cleared'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not clear reminders. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.titleColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 68,
      leading: Icon(
        icon,
        size: 21,
        color: iconColor ?? theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: titleColor ?? theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
      trailing: onTap == null
          ? null
          : Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
      onTap: onTap,
    );
  }
}
