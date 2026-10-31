import 'package:intl/intl.dart';

/// Formatter utilities for formatting dates and times in a calm, human-readable way.
class AppDateFormatters {
  AppDateFormatters._();

  static final DateFormat _timeFormat = DateFormat.jm(); // e.g. 7:30 AM
  static final DateFormat _dayOfWeekFormat = DateFormat.EEEE(); // e.g. Monday
  static final DateFormat _shortDateFormat = DateFormat.MMMd(); // e.g. Nov 1
  static final DateFormat _fullDateFormat =
      DateFormat.yMMMMd(); // e.g. November 1, 2026

  /// Formats time as "7:30 AM" or "18:00" depending on locale.
  static String formatTime(DateTime dateTime) {
    return _timeFormat.format(dateTime);
  }

  /// Formats date with relative context: "Today", "Tomorrow", "Yesterday", or "Nov 1".
  static String formatRelativeDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final differenceInDays = targetDate.difference(today).inDays;

    if (differenceInDays == 0) {
      return 'Today';
    } else if (differenceInDays == 1) {
      return 'Tomorrow';
    } else if (differenceInDays == -1) {
      return 'Yesterday';
    } else if (differenceInDays > 1 && differenceInDays < 7) {
      return _dayOfWeekFormat.format(dateTime);
    } else {
      return _shortDateFormat.format(dateTime);
    }
  }

  /// Formats full human date: "Sunday, November 1, 2026".
  static String formatFullDate(DateTime dateTime) {
    return _fullDateFormat.format(dateTime);
  }

  /// Formats a complete schedule string: "Today at 7:30 AM" or "Tomorrow at 9:00 AM".
  static String formatSchedule(DateTime dateTime) {
    return '${formatRelativeDate(dateTime)} at ${formatTime(dateTime)}';
  }
}
