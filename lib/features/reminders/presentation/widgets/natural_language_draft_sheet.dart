import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/natural_language_draft.dart';
import '../../domain/services/natural_language_reminder_parser.dart';

/// Modal bottom sheet allowing users to describe a reminder in natural language,
/// preview the interpreted draft with transparent explanations, and proceed to
/// the form for review and confirmation.
class NaturalLanguageDraftSheet extends StatefulWidget {
  const NaturalLanguageDraftSheet({
    super.key,
    required this.onDraftConfirmed,
    this.parser = const NaturalLanguageReminderParser(),
  });

  final void Function(NaturalLanguageDraft draft) onDraftConfirmed;
  final NaturalLanguageReminderParser parser;

  static Future<NaturalLanguageDraft?> show(BuildContext context) {
    return showModalBottomSheet<NaturalLanguageDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => NaturalLanguageDraftSheet(
        onDraftConfirmed: (draft) => Navigator.of(ctx).pop(draft),
      ),
    );
  }

  @override
  State<NaturalLanguageDraftSheet> createState() =>
      _NaturalLanguageDraftSheetState();
}

class _NaturalLanguageDraftSheetState extends State<NaturalLanguageDraftSheet> {
  late final TextEditingController _inputController;
  NaturalLanguageDraft? _currentDraft;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.trim().isEmpty) {
      setState(() => _currentDraft = null);
      return;
    }
    final draft = widget.parser.parse(text);
    setState(() => _currentDraft = draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final draft = _currentDraft;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.md,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Draft with plain language',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Processed 100% on-device with zero network use',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Input field
              TextField(
                controller: _inputController,
                autofocus: true,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText:
                      'e.g. Remind me to call Mum tomorrow at 6, or Take vitamins every Monday at 8',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.outline,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                ),
                onChanged: _onTextChanged,
              ),
              const SizedBox(height: AppSpacing.md),

              // Examples quick chips
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.chat_bubble_outline, size: 14),
                    label: const Text('Call Mum tomorrow at 6'),
                    onPressed: () {
                      _inputController.text = 'Call Mum tomorrow at 6';
                      _onTextChanged(_inputController.text);
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.repeat_rounded, size: 14),
                    label: const Text('Take vitamins every day at 8am'),
                    onPressed: () {
                      _inputController.text = 'Take vitamins every day at 8am';
                      _onTextChanged(_inputController.text);
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.timer_outlined, size: 14),
                    label: const Text('Walk in 30 minutes'),
                    onPressed: () {
                      _inputController.text = 'Walk in 30 minutes';
                      _onTextChanged(_inputController.text);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Interpreted draft preview card
              if (draft != null && draft.title.isNotEmpty) ...[
                Card(
                  elevation: 0,
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Interpreted Draft',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: AppSpacing.md),
                        _DraftDetailRow(
                          icon: Icons.title_rounded,
                          label: 'Title',
                          value: draft.title,
                        ),
                        if (draft.scheduledDateTime != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          _DraftDetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'When',
                            value: DateFormat(
                              'EEE, MMM d, y • h:mm a',
                            ).format(draft.scheduledDateTime!),
                          ),
                        ],
                        if (draft.recurrence.isRecurring) ...[
                          const SizedBox(height: AppSpacing.xs),
                          _DraftDetailRow(
                            icon: Icons.repeat_rounded,
                            label: 'Repeats',
                            value: draft.recurrence.summary,
                          ),
                        ],
                        if (draft.hasCallerPersona) ...[
                          const SizedBox(height: AppSpacing.xs),
                          _DraftDetailRow(
                            icon: Icons.person_pin_rounded,
                            label: 'Caller Persona',
                            value:
                                '${draft.callerName} (${draft.callerNumber ?? 'Mobile'})',
                          ),
                        ],
                        if (draft.explanations.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            draft.explanations.map((e) => '• $e').join('\n'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onDraftConfirmed(draft);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Open in Reminder Form to Confirm'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      AppSpacing.minTouchTarget,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftDetailRow extends StatelessWidget {
  const _DraftDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
