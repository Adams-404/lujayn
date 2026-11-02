import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_choice.dart';
import '../../../../core/widgets/lujayn_mark.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../reminders/presentation/controllers/reminder_providers.dart';
import '../../../reminders/presentation/screens/ringtone_settings_screen.dart';
import '../../../voice/presentation/screens/voice_settings_screen.dart';
import '../controllers/settings_providers.dart';
import '../widgets/principles_dialog.dart';
import '../widgets/theme_picker.dart';

/// Settings, privacy information, and appearance controls for Lujayn.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentThemeChoice =
        ref.watch(themeChoiceProvider).asData?.value ?? AppThemeChoice.system;
    final spokenAloud =
        ref.watch(spokenRemindersEnabledProvider).asData?.value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            LujaynMark(size: 24, color: colors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            const Text('Settings'),
          ],
        ),
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.fabClearance,
          ),
          children: [
            // Privacy Promise Banner
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.surface),
                side: BorderSide(color: colors.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.tertiary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        color: colors.tertiary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
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
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Your reminders stay entirely on this device. No accounts, ads, tracking, or cloud sync.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Data & Privacy Section (Placed directly after Privacy Banner)
            const _SectionHeading(title: 'DATA & PRIVACY'),
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.surface),
                side: BorderSide(color: colors.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    minTileHeight: AppSpacing.minTouchTarget,
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Product principles'),
                    subtitle: const Text('Read Lujayn’s 9 core principles'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => const PrinciplesDialog(),
                      );
                    },
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  const ListTile(
                    minTileHeight: AppSpacing.minTouchTarget,
                    leading: Icon(Icons.storage_outlined),
                    title: Text('Data persistence'),
                    subtitle: Text(
                      'SQLite on this device. Works offline; no account or cloud sync.',
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  ListTile(
                    minTileHeight: AppSpacing.minTouchTarget,
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
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Phase 4', style: theme.textTheme.labelSmall),
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  ListTile(
                    minTileHeight: AppSpacing.minTouchTarget,
                    leading: Icon(
                      Icons.delete_sweep_outlined,
                      color: colors.error,
                    ),
                    title: Text(
                      'Clear all reminders',
                      style: TextStyle(color: colors.error),
                    ),
                    subtitle: const Text(
                      'Remove all stored reminder records from this device',
                    ),
                    onTap: () => _confirmClearAll(context, ref),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Appearance Section
            const _SectionHeading(title: 'APPEARANCE'),
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.surface),
                side: BorderSide(color: colors.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: ThemePicker(
                selected: currentThemeChoice,
                onSelected: (choice) {
                  ref.read(themeChoiceProvider.notifier).select(choice);
                },
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Voice & Audio Section
            const _SectionHeading(title: 'VOICE & AUDIO'),
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.surface),
                side: BorderSide(color: colors.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    minTileHeight: AppSpacing.minTouchTarget,
                    leading: const Icon(Icons.record_voice_over_outlined),
                    title: const Text('Reminder voice'),
                    subtitle: const Text(
                      'Use this phone’s voice, or download a more natural one.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const VoiceSettingsScreen(),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  ListTile(
                    minTileHeight: AppSpacing.minTouchTarget,
                    leading: const Icon(Icons.ring_volume_outlined),
                    title: const Text('Reminder ringtone'),
                    subtitle: const Text(
                      'Choose the sound a reminder call makes, and hear it first.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RingtoneSettingsScreen(),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: const Text('Read reminders aloud'),
                    subtitle: const Text(
                      'Speaks the reminder when it arrives. Nothing is sent anywhere.',
                    ),
                    value: spokenAloud,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      ref
                          .read(spokenRemindersEnabledProvider.notifier)
                          .setEnabled(value);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Delivery & Permissions Section
            const _SectionHeading(title: 'DELIVERY & PERMISSIONS'),
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.surface),
                side: BorderSide(color: colors.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  const ListTile(
                    minTileHeight: AppSpacing.minTouchTarget,
                    leading: Icon(Icons.alarm_on_outlined),
                    title: Text('Exact alarms (Android 12+)'),
                    subtitle: Text(
                      'Delivers reminders at the exact minute when allowed. Without it, reminders may arrive a few minutes late.',
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  const ListTile(
                    minTileHeight: AppSpacing.minTouchTarget,
                    leading: Icon(Icons.ring_volume_outlined),
                    title: Text('Call-style presentation'),
                    subtitle: Text(
                      'Appears as a full-screen alert when Android allows it, and as a heads-up notification otherwise.',
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  const ListTile(
                    minTileHeight: AppSpacing.minTouchTarget,
                    leading: Icon(Icons.battery_saver_outlined),
                    title: Text('Battery optimization'),
                    subtitle: Text(
                      'Some device manufacturers restrict background alarms. Keep Lujayn unmonitored if reminders arrive late.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // About Section
            const _SectionHeading(title: 'ABOUT'),
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.surface),
                side: BorderSide(color: colors.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LujaynMark(size: 28, color: colors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Lujayn', style: theme.textTheme.headlineSmall),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'v1.0.0',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'A personal reminder companion that respects your privacy, '
                      'stays on your device and helps you remember what matters.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all reminders?'),
        content: const Text(
          'This will permanently remove every reminder stored on this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep reminders'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.mediumImpact();
      try {
        await ref.read(reminderActionControllerProvider).clearAll();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All reminders cleared'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not clear reminders. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
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
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
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
