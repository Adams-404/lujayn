import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utilities/date_formatters.dart';
import '../../../../core/widgets/honest_notice_card.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../domain/models/recurrence_rule.dart';
import '../../domain/models/reminder.dart';
import '../../domain/models/reminder_status.dart';
import '../controllers/reminder_providers.dart';
import '../widgets/recurrence_chip_selector.dart';

/// Screen for creating or editing a reminder.
class ReminderFormScreen extends ConsumerStatefulWidget {
  const ReminderFormScreen({super.key, this.initialReminder});

  final Reminder? initialReminder;

  @override
  ConsumerState<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends ConsumerState<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late RecurrenceRule _selectedRecurrence;
  bool _isSaving = false;

  bool get _isEditing => widget.initialReminder != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReminder;

    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );

    if (initial != null) {
      _selectedDate = DateTime(
        initial.scheduledDateTime.year,
        initial.scheduledDateTime.month,
        initial.scheduledDateTime.day,
      );
      _selectedTime = TimeOfDay(
        hour: initial.scheduledDateTime.hour,
        minute: initial.scheduledDateTime.minute,
      );
      _selectedRecurrence = initial.recurrence;
    } else {
      final suggested = DateTime.now().add(const Duration(hours: 1));
      _selectedDate = DateTime(
        suggested.year,
        suggested.month,
        suggested.day,
      );
      _selectedTime = TimeOfDay(
        hour: suggested.hour,
        minute: suggested.minute,
      );
      _selectedRecurrence = RecurrenceRule.none;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime get _scheduledDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _selectedTime.hour,
    _selectedTime.minute,
  );

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = _isEditing ? DateTime(now.year - 1) : today;
    final lastDate = DateTime(now.year + 5);
    var initialDate = _selectedDate;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final reminder = Reminder(
      id: widget.initialReminder?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      scheduledDateTime: _scheduledDateTime,
      recurrence: _selectedRecurrence,
      status: widget.initialReminder?.status ?? ReminderStatus.active,
      createdAt: widget.initialReminder?.createdAt ?? now,
      updatedAt: now,
      completedAt: widget.initialReminder?.completedAt,
    );

    try {
      await ref
          .read(reminderActionControllerProvider)
          .createOrUpdateReminder(reminder);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Reminder updated' : 'Reminder saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your reminder. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final isDateToday = _sameDate(_selectedDate, today);
    final isDateTomorrow = _sameDate(_selectedDate, tomorrow);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit reminder' : 'New reminder'),
      ),
      body: ResponsiveCenter(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
            children: [
              Text(
                'What do you need to remember?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Give it a name. You can add details and choose when it should happen.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              _FormSectionLabel(label: 'Reminder'),
              const SizedBox(height: 9),
              TextFormField(
                controller: _titleController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLength: 80,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'e.g. Take medication',
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter what you need to remember';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _FormSectionLabel(label: 'Notes'),
              const SizedBox(height: 4),
              Text(
                'Optional details that may help when the reminder appears.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Add instructions or a little context...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),
              _FormSectionLabel(label: 'When'),
              const SizedBox(height: 12),
              Text(
                'Date',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DateChoice(
                    label: 'Today',
                    selected: isDateToday,
                    onPressed: () => setState(() => _selectedDate = today),
                  ),
                  _DateChoice(
                    label: 'Tomorrow',
                    selected: isDateTomorrow,
                    onPressed: () => setState(() => _selectedDate = tomorrow),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickCustomDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    label: Text(
                      isDateToday || isDateTomorrow
                          ? 'Choose date'
                          : AppDateFormatters.formatFullDate(
                              _selectedDate,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Time',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              Material(
                color: colors.surfaceContainerLow,
                child: InkWell(
                  onTap: _pickCustomTime,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 76),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: colors.primary,
                          size: 23,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _selectedTime.format(context),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                AppDateFormatters.formatFullDate(
                                  _selectedDate,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Change',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Quick times',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TimeChoice(
                    label: 'Morning',
                    time: const TimeOfDay(hour: 8, minute: 0),
                    onPressed: (time) => setState(() => _selectedTime = time),
                  ),
                  _TimeChoice(
                    label: 'Afternoon',
                    time: const TimeOfDay(hour: 14, minute: 0),
                    onPressed: (time) => setState(() => _selectedTime = time),
                  ),
                  _TimeChoice(
                    label: 'Evening',
                    time: const TimeOfDay(hour: 19, minute: 0),
                    onPressed: (time) => setState(() => _selectedTime = time),
                  ),
                  _TimeChoice(
                    label: 'Night',
                    time: const TimeOfDay(hour: 21, minute: 30),
                    onPressed: (time) => setState(() => _selectedTime = time),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _FormSectionLabel(label: 'Repeat schedule'),
              const SizedBox(height: 6),
              Text(
                'Choose how often this reminder should repeat.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              RecurrenceChipSelector(
                selectedRule: _selectedRecurrence,
                onChanged: (rule) => setState(() => _selectedRecurrence = rule),
              ),
              const SizedBox(height: 28),
              HonestNoticeCard(
                title: 'Saved on this device',
                message:
                    'Your reminder is stored locally. Automatic alarms and notifications are still being built, so Lujayn cannot alert you at the scheduled time yet.',
                icon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: ResponsiveCenter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
          ),
        ),
      ),
    );
  }

  bool _sameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DateChoice extends StatelessWidget {
  const _DateChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 48),
            ),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(88, 48),
            ),
            child: Text(label),
          );
  }
}

class _TimeChoice extends StatelessWidget {
  const _TimeChoice({
    required this.label,
    required this.time,
    required this.onPressed,
  });

  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: () => onPressed(time),
    );
  }
}
