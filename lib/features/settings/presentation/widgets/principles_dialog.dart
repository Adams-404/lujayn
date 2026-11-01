import 'package:flutter/material.dart';

/// Modal dialog presenting Lujayn's 9 core product principles from the product brief.
class PrinciplesDialog extends StatelessWidget {
  const PrinciplesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final principles = [
      (
        '1. Privacy by default',
        'Personal reminders and recordings belong to the user.',
      ),
      (
        '2. Local-first',
        'Core functionality must work without an internet connection.',
      ),
      ('3. No advertising', 'No ads or advertising SDKs.'),
      (
        '4. No tracking',
        'No analytics, tracking SDKs or behavioural profiling.',
      ),
      (
        '5. No account requirement',
        'Users should not need to register or sign in.',
      ),
      (
        '6. User control',
        'Users can create, edit, delete, export and restore their own reminder data.',
      ),
      (
        '7. Reliability over novelty',
        'A reminder that fails to appear is a serious product failure.',
      ),
      (
        '8. Simple for everyone',
        'The experience should be comfortable for non-technical users, including parents and older users.',
      ),
      (
        '9. Honest platform behaviour',
        'Never promise identical call-like behaviour on Android and iOS where the operating systems impose different restrictions.',
      ),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Product Principles',
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'These 9 principles guide every engineering and product decision in Lujayn.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  itemCount: principles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final (title, desc) = principles[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
