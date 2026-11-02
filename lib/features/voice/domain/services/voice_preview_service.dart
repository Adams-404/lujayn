import '../models/voice_pack.dart';

/// Plays a short sample so a person can hear a voice before choosing it.
///
/// A voice picker without previews asks the user to choose blind, which is how
/// the app ended up with a list of names that never made a sound.
abstract interface class VoicePreviewService {
  /// Whether [voice] can be previewed on this device right now.
  Future<bool> isPreviewAvailable(VoiceOption voice);

  /// Speaks a short sample with [voice], replacing any preview already playing.
  ///
  /// Throws when the pack is missing or the engine fails, so the screen can
  /// say what went wrong instead of showing a dead play button.
  Future<void> preview(VoiceOption voice);

  /// Stops a preview. Safe to call when nothing is playing.
  Future<void> stopPreview();
}

/// The line every preview speaks. Short on purpose: a 151 MB model should not
/// make someone wait through a paragraph just to hear a voice.
const String voicePreviewText =
    'Hi, it’s Lujayn. This is how your reminder will sound.';
