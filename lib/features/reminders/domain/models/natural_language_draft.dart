import 'recurrence_rule.dart';

/// Interpreted draft result from on-device natural language parsing.
class NaturalLanguageDraft {
  const NaturalLanguageDraft({
    required this.rawInput,
    required this.title,
    required this.recurrence,
    this.scheduledDateTime,
    this.callerName,
    this.callerNumber,
    this.callerIcon,
    this.confidence = 1.0,
    this.explanations = const [],
    this.isAmbiguous = false,
  });

  /// The original raw input string from the user.
  final String rawInput;

  /// Parsed clean title for the reminder.
  final String title;

  /// Parsed recurrence rule.
  final RecurrenceRule recurrence;

  /// Parsed target date and time, if detected.
  final DateTime? scheduledDateTime;

  /// Detected caller persona name if applicable (e.g. "Mom").
  final String? callerName;

  /// Detected caller persona label or number if applicable.
  final String? callerNumber;

  /// Detected caller persona icon identifier if applicable.
  final String? callerIcon;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Plain-language explanations of how the input was interpreted.
  final List<String> explanations;

  /// Whether the parser considers the input ambiguous or incomplete.
  final bool isAmbiguous;

  /// Whether caller details were identified.
  bool get hasCallerPersona =>
      callerName != null && callerName!.trim().isNotEmpty;
}
