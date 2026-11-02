import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/services/reminder_speech_service.dart';

/// Speaks reminders with the device's own text-to-speech engine.
///
/// Everything happens on-device: Android's TTS engine is local, so reminder
/// text is never sent anywhere. When no engine or language data is installed,
/// [isAvailable] returns false and the interface hides the control rather than
/// offering a button that does nothing.
class FlutterReminderSpeechService implements ReminderSpeechService {
  FlutterReminderSpeechService({FlutterTts? engine})
    : _engine = engine ?? FlutterTts();

  final FlutterTts _engine;

  /// A slightly slower rate: a reminder is often heard once, in a hurry, and
  /// sometimes by someone who is not a confident reader of the language.
  static const double _speechRate = 0.48;

  bool? _available;
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    try {
      await _engine.setSpeechRate(_speechRate);
      await _engine.awaitSpeakCompletion(false);
      _configured = true;
    } on Object catch (error) {
      debugPrint('Lujayn speech configuration failed: $error');
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (_available case final known?) return known;
    try {
      final languages = await _engine.getLanguages;
      final available = languages is List && languages.isNotEmpty;
      _available = available;
      if (available) {
        await _configure();
      }
      return available;
    } on Object catch (error) {
      // A missing plugin, a disabled engine, or a platform that refuses to
      // answer all mean the same thing to the user: no speech right now.
      debugPrint('Lujayn speech unavailable: $error');
      _available = false;
      return false;
    }
  }

  @override
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (!await isAvailable()) return;
    try {
      await _configure();
      await _engine.stop();
      await _engine.speak(trimmed, focus: true);
    } on Object catch (error) {
      debugPrint('Lujayn speech failed: $error');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _engine.stop();
    } on Object catch (error) {
      debugPrint('Lujayn speech stop failed: $error');
    }
  }
}
