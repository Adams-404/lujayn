/// Types of recurrence supported by Lujayn.
enum RecurrenceType { none, daily, weekdays, weekly, customDays }

/// Immutable rule defining reminder recurrence.
class RecurrenceRule {
  const RecurrenceRule({required this.type, this.daysOfWeek = const []});

  /// No repeat (one-time reminder).
  static const RecurrenceRule none = RecurrenceRule(type: RecurrenceType.none);

  /// Repeats every single day.
  static const RecurrenceRule daily = RecurrenceRule(
    type: RecurrenceType.daily,
  );

  /// Repeats Monday through Friday.
  static const RecurrenceRule weekdays = RecurrenceRule(
    type: RecurrenceType.weekdays,
    daysOfWeek: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ],
  );

  /// Repeats once a week on the same weekday.
  static const RecurrenceRule weekly = RecurrenceRule(
    type: RecurrenceType.weekly,
  );

  final RecurrenceType type;

  /// Days of the week (1 = Monday, 7 = Sunday) for custom recurrence.
  final List<int> daysOfWeek;

  bool get isRecurring => type != RecurrenceType.none;

  /// A short human-readable summary for badges and details.
  String get summary {
    switch (type) {
      case RecurrenceType.none:
        return 'One-time';
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekdays:
        return 'Weekdays (Mon–Fri)';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.customDays:
        if (daysOfWeek.isEmpty) return 'Custom';
        final names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final days = daysOfWeek
            .map((d) => names[(d - 1).clamp(0, 6)])
            .join(', ');
        return 'Custom ($days)';
    }
  }

  /// Calculates the next occurrence based on a base scheduled date.
  ///
  /// This runs against persisted data, including anything restored from a
  /// backup, so it must never loop forever. Every rule terminates: the day
  /// loops are bounded by [_maxLookaheadDays] and an unusable custom day list
  /// falls back to no recurrence instead of searching for a day that does not
  /// exist.
  DateTime calculateNextOccurrence(
    DateTime scheduledDateTime, {
    DateTime? after,
  }) {
    final reference = after ?? DateTime.now();

    if (!isRecurring) {
      return scheduledDateTime;
    }

    var candidate = scheduledDateTime;
    var steps = 0;

    switch (type) {
      case RecurrenceType.none:
        return scheduledDateTime;

      case RecurrenceType.daily:
        while (!candidate.isAfter(reference) && steps++ < _maxLookaheadDays) {
          candidate = _addDays(candidate, 1);
        }
        return candidate;

      case RecurrenceType.weekdays:
        while ((!candidate.isAfter(reference) ||
                candidate.weekday == DateTime.saturday ||
                candidate.weekday == DateTime.sunday) &&
            steps++ < _maxLookaheadDays) {
          candidate = _addDays(candidate, 1);
        }
        return candidate;

      case RecurrenceType.weekly:
        while (!candidate.isAfter(reference) &&
            steps++ < _maxLookaheadDays ~/ 7) {
          candidate = _addDays(candidate, 7);
        }
        return candidate;

      case RecurrenceType.customDays:
        final validDays = daysOfWeek
            .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
            .toSet();
        if (validDays.isEmpty) return candidate;
        while ((!candidate.isAfter(reference) ||
                !validDays.contains(candidate.weekday)) &&
            steps++ < _maxLookaheadDays) {
          candidate = _addDays(candidate, 1);
        }
        return candidate;
    }
  }

  /// Upper bound on the days searched for a next occurrence.
  ///
  /// A reminder more than four years overdue is not useful to re-arm, and the
  /// bound guarantees a corrupt rule cannot freeze the app.
  static const _maxLookaheadDays = 366 * 4;

  /// Advances by whole calendar days while keeping the local wall-clock time.
  ///
  /// Adding a 24-hour [Duration] would drift by an hour across daylight-saving
  /// changes, so a reminder set for 08:00 could start arriving at 07:00 or
  /// 09:00. Rebuilding from date components keeps the time the user chose.
  static DateTime _addDays(DateTime value, int days) {
    return DateTime(
      value.year,
      value.month,
      value.day + days,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  RecurrenceRule copyWith({RecurrenceType? type, List<int>? daysOfWeek}) {
    return RecurrenceRule(
      type: type ?? this.type,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurrenceRule &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          _listEquals(daysOfWeek, other.daysOfWeek);

  @override
  int get hashCode => type.hashCode ^ daysOfWeek.length.hashCode;

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
