import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/core/widgets/responsive_center.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import '../controllers/settings_providers.dart';
import '../widgets/principles_dialog.dart';
import '../widgets/theme_picker.dart';

/// Settings and principles screen for Lujayn.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentThemeChoice =
        ref.watch(themeChoiceProvider).valueOrNull ?? AppThemeChoice.system;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Privacy Promise Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: theme.colorScheme.tertiary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy by default',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your reminders and data stay entirely on this device. No ads, tracking, or cloud sync.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section: Privacy & Data
            _SectionTitle(title: 'Privacy & Data'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Product principles'),
                    subtitle: const Text('Read Lujayn’s 9 core principles'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const PrinciplesDialog(),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Data persistence'),
                    subtitle: const Text(
                      'Phase 0: In-memory mock • Phase 1: Drift SQLite',
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.download_for_offline_outlined),
                    title: const Text('Encrypted backup & export'),
                    subtitle: const Text(
                      'Local encrypted backups (Planned for Phase 4)',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Phase 4', style: theme.textTheme.labelSmall),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.restore_rounded),
                    title: const Text('Reset sample reminders'),
                    subtitle: const Text(
                      'Reload the 5 curated sample reminders',
                    ),
                    onTap: () async {
                      await ref
                          .read(reminderActionControllerProvider)
                          .resetToSampleData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sample reminders reloaded'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_sweep_outlined,
                      color: theme.colorScheme.error,
                    ),
                    title: const Text(
                      'Clear all reminders',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    subtitle: const Text('Remove all stored reminder records'),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear all reminders?'),
                          content: const Text(
                            'This will remove all reminders from the current repository. You can reload sample data at any time.',
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
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        await ref
                            .read(reminderActionControllerProvider)
                            .clearAll();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All reminders cleared'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section: Notifications & Platform
            _SectionTitle(title: 'Notifications & Permissions'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.alarm_on_outlined),
                    title: const Text('Exact alarms (Android 12+)'),
                    subtitle: const Text(
                      'Required to deliver timely reminders at the exact scheduled minute. Wired in Phase 2.',
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.ring_volume_outlined),
                    title: const Text('Call-style presentation'),
                    subtitle: const Text(
                      'Full-screen simulated incoming call reminder. Planned for Android in Phase 2.',
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.battery_saver_outlined),
                    title: const Text('Battery optimization handling'),
                    subtitle: const Text(
                      'Guidance for manufacturer-specific background restrictions will be provided in onboarding.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section: Appearance
            _SectionTitle(title: 'Appearance'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ThemePicker(
                selected: currentThemeChoice,
                onSelected: (choice) {
                  ref.read(themeChoiceProvider.notifier).select(choice);
                },
              ),
            ),

            const SizedBox(height: 24),

            // Section: About
            _SectionTitle(title: 'About'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.alarm_rounded,
                            color: theme.colorScheme.onPrimary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Lujayn', style: theme.textTheme.headlineSmall),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'v1.0.0 (Phase 0)',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A personal reminder companion that respects your privacy, '
                      'stays on your device and helps you remember what matters.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
