import '../models/natural_language_draft.dart';
import '../models/recurrence_rule.dart';

/// Lightweight, deterministic on-device parser that converts natural language
/// statements into validated reminder drafts with zero network dependencies.
class NaturalLanguageReminderParser {
  const NaturalLanguageReminderParser();

  static final Map<String, int> _weekdayMap = {
    'monday': DateTime.monday,
    'mon': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'tue': DateTime.tuesday,
    'tues': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'wed': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'thu': DateTime.thursday,
    'thur': DateTime.thursday,
    'thurs': DateTime.thursday,
    'friday': DateTime.friday,
    'fri': DateTime.friday,
    'saturday': DateTime.saturday,
    'sat': DateTime.saturday,
    'sunday': DateTime.sunday,
    'sun': DateTime.sunday,
  };

  /// Parses [input] text into a [NaturalLanguageDraft].
  ///
  /// Uses [now] as the reference anchor (defaults to [DateTime.now]).
  NaturalLanguageDraft parse(String input, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return NaturalLanguageDraft(
        rawInput: input,
        title: '',
        recurrence: RecurrenceRule.none,
        isAmbiguous: true,
        confidence: 0.0,
        explanations: const ['Input is empty.'],
      );
    }

    String working = trimmed;
    final explanations = <String>[];
    double confidence = 1.0;

    // 1. Strip common reminder command prefixes
    final prefixRegex = RegExp(
      r'^(please\s+)?(remind\s+me\s+(to\s+)?|set\s+a\s+reminder\s+(to\s+)?|remember\s+to\s+|don[\x27\u2019]t\s+forget\s+to\s+)',
      caseSensitive: false,
    );
    final prefixMatch = prefixRegex.firstMatch(working);
    if (prefixMatch != null) {
      working = working.substring(prefixMatch.end).trim();
    }

    // 2. Detect recurrence
    RecurrenceRule recurrence = RecurrenceRule.none;
    final recurrenceDailyRegex = RegExp(
      r'\b(every\s+day|daily)\b',
      caseSensitive: false,
    );
    final recurrenceWeekdaysRegex = RegExp(
      r'\b(every\s+weekday|on\s+weekdays|weekdays)\b',
      caseSensitive: false,
    );
    final recurrenceWeeklyRegex = RegExp(
      r'\b(every\s+week|weekly)\b',
      caseSensitive: false,
    );
    final recurrenceDaysRegex = RegExp(
      r'\b(every|on)\s+((?:(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)(?:s)?(?:\s*,\s*|\s+and\s+|\s+))+)',
      caseSensitive: false,
    );

    if (recurrenceDailyRegex.hasMatch(working)) {
      recurrence = RecurrenceRule.daily;
      working = working.replaceAll(recurrenceDailyRegex, ' ');
      explanations.add('Repeats daily');
    } else if (recurrenceWeekdaysRegex.hasMatch(working)) {
      recurrence = RecurrenceRule.weekdays;
      working = working.replaceAll(recurrenceWeekdaysRegex, ' ');
      explanations.add('Repeats on weekdays (Mon–Fri)');
    } else if (recurrenceDaysRegex.hasMatch(working)) {
      final match = recurrenceDaysRegex.firstMatch(working)!;
      final daysString = match.group(2)!.toLowerCase();
      final detectedDays = <int>{};
      for (final entry in _weekdayMap.entries) {
        if (daysString.contains(entry.key)) {
          detectedDays.add(entry.value);
        }
      }
      if (detectedDays.isNotEmpty) {
        final sortedDays = detectedDays.toList()..sort();
        recurrence = RecurrenceRule(
          type: RecurrenceType.customDays,
          daysOfWeek: sortedDays,
        );
        working = working.replaceRange(match.start, match.end, ' ');
        final dayNames = sortedDays.map(_weekdayName).join(', ');
        explanations.add('Repeats weekly on $dayNames');
      }
    } else if (recurrenceWeeklyRegex.hasMatch(working)) {
      recurrence = RecurrenceRule.weekly;
      working = working.replaceAll(recurrenceWeeklyRegex, ' ');
      explanations.add('Repeats weekly');
    }

    // 3. Detect relative offsets (e.g. "in 30 minutes", "in 2 hours", "in 3 days")
    DateTime? scheduledDate;
    final relativeRegex = RegExp(
      r'\bin\s+(\d+)\s*(minute|min|hour|hr|day)s?\b',
      caseSensitive: false,
    );
    final relativeMatch = relativeRegex.firstMatch(working);
    if (relativeMatch != null) {
      final amount = int.tryParse(relativeMatch.group(1)!) ?? 0;
      final unit = relativeMatch.group(2)!.toLowerCase();
      if (unit.startsWith('min')) {
        scheduledDate = reference.add(Duration(minutes: amount));
        explanations.add('Scheduled in $amount minute(s)');
      } else if (unit.startsWith('h')) {
        scheduledDate = reference.add(Duration(hours: amount));
        explanations.add('Scheduled in $amount hour(s)');
      } else if (unit.startsWith('day')) {
        scheduledDate = reference.add(Duration(days: amount));
        explanations.add('Scheduled in $amount day(s)');
      }
      working = working.replaceRange(
        relativeMatch.start,
        relativeMatch.end,
        ' ',
      );
    }

    // 4. Detect calendar day if not already relative
    DateTime targetDate = reference;
    bool explicitDateFound = false;

    if (scheduledDate == null) {
      final todayRegex = RegExp(r'\btoday\b', caseSensitive: false);
      final tomorrowRegex = RegExp(r'\btomorrow\b', caseSensitive: false);
      final dayAfterTomorrowRegex = RegExp(
        r'\bday\s+after\s+tomorrow\b',
        caseSensitive: false,
      );
      final namedDayRegex = RegExp(
        r'\b(this|next)?\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
        caseSensitive: false,
      );

      if (dayAfterTomorrowRegex.hasMatch(working)) {
        targetDate = reference.add(const Duration(days: 2));
        working = working.replaceAll(dayAfterTomorrowRegex, ' ');
        explicitDateFound = true;
        explanations.add('Scheduled for the day after tomorrow');
      } else if (tomorrowRegex.hasMatch(working)) {
        targetDate = reference.add(const Duration(days: 1));
        working = working.replaceAll(tomorrowRegex, ' ');
        explicitDateFound = true;
        explanations.add('Scheduled for tomorrow');
      } else if (todayRegex.hasMatch(working)) {
        targetDate = reference;
        working = working.replaceAll(todayRegex, ' ');
        explicitDateFound = true;
        explanations.add('Scheduled for today');
      } else if (namedDayRegex.hasMatch(working)) {
        final match = namedDayRegex.firstMatch(working)!;
        final modifier = match.group(1)?.toLowerCase();
        final dayName = match.group(2)!.toLowerCase();
        final targetWeekday = _weekdayMap[dayName]!;

        int daysToAdd = targetWeekday - reference.weekday;
        if (daysToAdd <= 0 || modifier == 'next') {
          daysToAdd += 7;
        }
        targetDate = reference.add(Duration(days: daysToAdd));
        working = working.replaceRange(match.start, match.end, ' ');
        explicitDateFound = true;
        explanations.add('Scheduled for next ${_weekdayName(targetWeekday)}');
      }
    }

    // 5. Detect time of day
    int? parsedHour;
    int? parsedMinute;

    // Specific time like "at 6:30 pm", "at 6 pm", "6:30am", "at 18:00", "at 8"
    final timeRegex = RegExp(
      r'(?:\bat\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
      caseSensitive: false,
    );

    // Named time of day
    final noonRegex = RegExp(r'\b(at\s+)?noon\b', caseSensitive: false);
    final midnightRegex = RegExp(r'\b(at\s+)?midnight\b', caseSensitive: false);
    final morningRegex = RegExp(
      r'\b(in\s+the\s+)?morning\b',
      caseSensitive: false,
    );
    final afternoonRegex = RegExp(
      r'\b(in\s+the\s+)?afternoon\b',
      caseSensitive: false,
    );
    final eveningRegex = RegExp(
      r'\b(in\s+the\s+)?evening\b',
      caseSensitive: false,
    );
    final nightRegex = RegExp(r'\b(at\s+)?night\b', caseSensitive: false);

    if (scheduledDate == null) {
      if (noonRegex.hasMatch(working)) {
        parsedHour = 12;
        parsedMinute = 0;
        working = working.replaceAll(noonRegex, ' ');
        explanations.add('Time set to 12:00 PM (Noon)');
      } else if (midnightRegex.hasMatch(working)) {
        parsedHour = 0;
        parsedMinute = 0;
        working = working.replaceAll(midnightRegex, ' ');
        explanations.add('Time set to 12:00 AM (Midnight)');
      } else if (morningRegex.hasMatch(working)) {
        parsedHour = 9;
        parsedMinute = 0;
        working = working.replaceAll(morningRegex, ' ');
        explanations.add('Time set to 9:00 AM (Morning)');
      } else if (afternoonRegex.hasMatch(working)) {
        parsedHour = 14;
        parsedMinute = 0;
        working = working.replaceAll(afternoonRegex, ' ');
        explanations.add('Time set to 2:00 PM (Afternoon)');
      } else if (eveningRegex.hasMatch(working)) {
        parsedHour = 18;
        parsedMinute = 0;
        working = working.replaceAll(eveningRegex, ' ');
        explanations.add('Time set to 6:00 PM (Evening)');
      } else if (nightRegex.hasMatch(working)) {
        parsedHour = 20;
        parsedMinute = 0;
        working = working.replaceAll(nightRegex, ' ');
        explanations.add('Time set to 8:00 PM (Night)');
      } else {
        // Try numerical time match
        final matches = timeRegex.allMatches(working).toList();
        for (final match in matches) {
          final rawHour = int.tryParse(match.group(1) ?? '');
          final rawMinute = int.tryParse(match.group(2) ?? '') ?? 0;
          final meridian = match.group(3)?.toLowerCase();

          if (rawHour != null && rawHour >= 0 && rawHour <= 23) {
            // Validate if this looks like a time (has 'at' before it or has am/pm or has colon)
            final fullMatch = match.group(0)!;
            final isExplicitTime =
                fullMatch.toLowerCase().contains('at') ||
                meridian != null ||
                match.group(2) != null;

            if (isExplicitTime || (rawHour >= 1 && rawHour <= 12)) {
              int h = rawHour;
              if (meridian == 'pm' && h < 12) {
                h += 12;
              } else if (meridian == 'am' && h == 12) {
                h = 0;
              } else if (meridian == null) {
                // If hour is 1-6 and no am/pm given, default to afternoon/evening (e.g. at 6 -> 18:00)
                if (h >= 1 && h <= 6) {
                  h += 12;
                }
              }
              parsedHour = h;
              parsedMinute = rawMinute;
              working = working.replaceRange(match.start, match.end, ' ');
              final formattedTime =
                  '${parsedHour % 12 == 0 ? 12 : parsedHour % 12}:${parsedMinute.toString().padLeft(2, '0')} ${parsedHour >= 12 ? 'PM' : 'AM'}';
              explanations.add('Time set to $formattedTime');
              break;
            }
          }
        }
      }

      if (parsedHour != null) {
        scheduledDate = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          parsedHour,
          parsedMinute ?? 0,
        );
      } else if (explicitDateFound) {
        // Date found but no explicit time -> default to 9:00 AM next day
        scheduledDate = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          9,
          0,
        );
        explanations.add('Defaulted time to 9:00 AM');
      } else {
        // Neither explicit date nor time -> default to 1 hour from now
        scheduledDate = reference.add(const Duration(hours: 1));
        confidence *= 0.8;
      }
    }

    // If scheduled date is in the past, push forward if recurring or bump to next day
    if (scheduledDate.isBefore(reference)) {
      if (recurrence == RecurrenceRule.none) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
        explanations.add('Time was in the past; advanced to tomorrow');
      }
    }

    // 6. Detect Caller Persona from content
    String? callerName;
    String? callerNumber;
    String? callerIcon;

    final callPersonRegex = RegExp(
      r'\b(?:call|phone|ring|contact)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?|mum|mom|dad|sister|brother|doctor|clinic|coach|boss)\b',
      caseSensitive: false,
    );
    final callMatch = callPersonRegex.firstMatch(working);
    if (callMatch != null) {
      final nameRaw = callMatch.group(1)!.trim();
      final lowerName = nameRaw.toLowerCase();
      if (lowerName == 'mum' || lowerName == 'mom') {
        callerName = 'Mom';
        callerNumber = 'Family • Mobile';
        callerIcon = 'favorite_rounded';
      } else if (lowerName == 'dad') {
        callerName = 'Dad';
        callerNumber = 'Family • Mobile';
        callerIcon = 'favorite_rounded';
      } else if (lowerName.contains('doctor') || lowerName.contains('clinic')) {
        callerName = 'Doctor';
        callerNumber = 'Clinic • (555) 019-2831';
        callerIcon = 'local_hospital_rounded';
      } else if (lowerName.contains('boss')) {
        callerName = 'Work';
        callerNumber = 'Office';
        callerIcon = 'business_center_rounded';
      } else {
        callerName = _capitalize(nameRaw);
        callerNumber = 'Mobile';
        callerIcon = 'person_rounded';
      }
      explanations.add('Identified caller persona for $callerName');
    }

    // 7. Clean up title
    String cleanTitle = working
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[,.\-–—\s]+|[,.\-–—\s]+$'), '')
        .trim();

    if (cleanTitle.isEmpty) {
      cleanTitle = 'Reminder';
      confidence *= 0.5;
    } else {
      cleanTitle = _capitalize(cleanTitle);
    }

    return NaturalLanguageDraft(
      rawInput: input,
      title: cleanTitle,
      recurrence: recurrence,
      scheduledDateTime: scheduledDate,
      callerName: callerName,
      callerNumber: callerNumber,
      callerIcon: callerIcon,
      confidence: confidence,
      explanations: explanations,
      isAmbiguous: confidence < 0.6 || cleanTitle == 'Reminder',
    );
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  static String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }
}
