import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utilities/date_formatters.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../domain/models/recurrence_rule.dart';
import '../../domain/models/reminder.dart';
import '../../domain/models/reminder_status.dart';
import '../controllers/reminder_providers.dart';
import '../widgets/recurrence_chip_selector.dart';

/// A short, guided form for creating or editing a personal reminder.
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
    final firstAllowedDate = _selectedDate.isBefore(today)
        ? _selectedDate
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstAllowedDate,
      lastDate: DateTime(now.year + 5),
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
    if (!_formKey.currentState!.validate()) return;

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

    await ref
        .read(reminderActionControllerProvider)
        .createOrUpdateReminder(reminder);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Reminder updated' : 'Reminder created'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit reminder' : 'New reminder'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
            children: [
              Text(
                'What would you like to remember?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: _titleController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'e.g. Call Mum, take medication, water plants',
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter what you need to remember';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 23),
              Text(
                'Notes or details (optional)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Add a little context or anything you might need...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'When',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              _ScheduleOption(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: AppDateFormatters.formatRelativeDate(_selectedDate),
                onTap: _pickCustomDate,
              ),
              Divider(color: theme.colorScheme.outlineVariant),
              _ScheduleOption(
                icon: Icons.schedule_rounded,
                label: 'Time',
                value: _selectedTime.format(context),
                onTap: _pickCustomTime,
              ),
              const SizedBox(height: 30),
              Text(
                'Repeat schedule',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              RecurrenceChipSelector(
                selectedRule: _selectedRecurrence,
                onChanged: (rule) => setState(() => _selectedRecurrence = rule),
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 17,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Your reminder stays on this device. You can change or delete it whenever you need.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleOption extends StatelessWidget {
  const _ScheduleOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: theme.textTheme.bodyLarge),
            ),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
