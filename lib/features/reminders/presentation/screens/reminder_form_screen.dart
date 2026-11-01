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
      // Default: scheduled for today or tomorrow, 1 hour from now or 09:00
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedTime = TimeOfDay(hour: (now.hour + 1).clamp(0, 23), minute: 0);
      _selectedRecurrence = RecurrenceRule.none;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime get _scheduledDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _save() {
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

    ref.read(reminderActionControllerProvider).createOrUpdateReminder(reminder);

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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final isDateToday =
        _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;

    final isDateTomorrow =
        _selectedDate.year == tomorrow.year &&
        _selectedDate.month == tomorrow.month &&
        _selectedDate.day == tomorrow.day;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Reminder' : 'New Reminder'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Title Input
              Text(
                'What would you like to remember?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'e.g. Morning medication, Call Dad, Water plants',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter what you need to remember';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Description Input (Optional)
              Text(
                'Notes or details (optional)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Add helpful instructions, context, or notes...',
                ),
              ),

              const SizedBox(height: 24),

              // Date Selection
              Text(
                'Date',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Today'),
                    selected: isDateToday,
                    selectedColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isDateToday
                          ? Colors.white
                          : (theme.colorScheme.onSurface),
                      fontWeight: isDateToday
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedDate = today);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Tomorrow'),
                    selected: isDateTomorrow,
                    selectedColor: AppColors.slateTeal,
                    labelStyle: TextStyle(
                      color: isDateTomorrow
                          ? Colors.white
                          : (theme.colorScheme.onSurface),
                      fontWeight: isDateTomorrow
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedDate = tomorrow);
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      isDateToday || isDateTomorrow
                          ? 'Other date...'
                          : AppDateFormatters.formatFullDate(_selectedDate),
                    ),
                    onPressed: _pickCustomDate,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Time Selection
              Text(
                'Time',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: InkWell(
                  onTap: _pickCustomTime,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 22,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedTime.format(context),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Change',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Quick time presets
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Morning (08:00)'),
                    onPressed: () => setState(
                      () => _selectedTime = const TimeOfDay(hour: 8, minute: 0),
                    ),
                  ),
                  ActionChip(
                    label: const Text('Afternoon (14:00)'),
                    onPressed: () => setState(
                      () =>
                          _selectedTime = const TimeOfDay(hour: 14, minute: 0),
                    ),
                  ),
                  ActionChip(
                    label: const Text('Evening (19:00)'),
                    onPressed: () => setState(
                      () =>
                          _selectedTime = const TimeOfDay(hour: 19, minute: 0),
                    ),
                  ),
                  ActionChip(
                    label: const Text('Night (21:30)'),
                    onPressed: () => setState(
                      () =>
                          _selectedTime = const TimeOfDay(hour: 21, minute: 30),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recurrence
              Text(
                'Repeat schedule',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              RecurrenceChipSelector(
                selectedRule: _selectedRecurrence,
                onChanged: (rule) => setState(() => _selectedRecurrence = rule),
              ),

              const SizedBox(height: 28),

              // Honest development notice
              const HonestNoticeCard(
                title: 'Phase 0 Development Note',
                message:
                    'Reminders are stored locally in the mock repository during this initialization stage. '
                    'Native Android exact alarms and simulated call presentations will be wired in Phase 2.',
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
