import 'recurrence_rule.dart';
import 'reminder_status.dart';

/// Core domain entity representing a personal reminder in Lujayn.
///
/// Designed as a pure, immutable Dart class free of database or platform specifics.
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    this.description,
    required this.scheduledDateTime,
    this.recurrence = RecurrenceRule.none,
    this.status = ReminderStatus.active,
    this.voiceNotePath,
    this.voiceNoteDuration,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime scheduledDateTime;
  final RecurrenceRule recurrence;
  final ReminderStatus status;
  final String? voiceNotePath;
  final Duration? voiceNoteDuration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  bool get hasVoiceNote => voiceNotePath != null && voiceNotePath!.isNotEmpty;

  bool get isCompleted => status == ReminderStatus.completed;
  bool get isActive => status == ReminderStatus.active;
  bool get isRecurring => recurrence.isRecurring;

  bool get isToday {
    final now = DateTime.now();
    return scheduledDateTime.year == now.year &&
        scheduledDateTime.month == now.month &&
        scheduledDateTime.day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return scheduledDateTime.year == tomorrow.year &&
        scheduledDateTime.month == tomorrow.month &&
        scheduledDateTime.day == tomorrow.day;
  }

  bool get isPastDue {
    return isActive && scheduledDateTime.isBefore(DateTime.now());
  }

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? scheduledDateTime,
    RecurrenceRule? recurrence,
    ReminderStatus? status,
    String? voiceNotePath,
    Duration? voiceNoteDuration,
    bool clearVoiceNote = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      recurrence: recurrence ?? this.recurrence,
      status: status ?? this.status,
      voiceNotePath: clearVoiceNote
          ? null
          : (voiceNotePath ?? this.voiceNotePath),
      voiceNoteDuration: clearVoiceNote
          ? null
          : (voiceNoteDuration ?? this.voiceNoteDuration),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reminder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          scheduledDateTime == other.scheduledDateTime &&
          recurrence == other.recurrence &&
          status == other.status &&
          voiceNotePath == other.voiceNotePath &&
          voiceNoteDuration == other.voiceNoteDuration &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          completedAt == other.completedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      scheduledDateTime.hashCode ^
      status.hashCode ^
      voiceNotePath.hashCode;
}
