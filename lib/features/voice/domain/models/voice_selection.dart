import 'voice_pack.dart';

/// What Lujayn should use to speak a reminder.
///
/// The device engine is the default and the fallback: it costs no storage, is
/// already installed, and keeps the app usable when a pack download is refused.
sealed class VoiceSelection {
  const VoiceSelection();

  /// The phone's own text-to-speech engine.
  static const VoiceSelection device = DeviceVoice();

  /// The persisted form: `device`, or `<packId>#<speakerId>`.
  String encode() => switch (this) {
    DeviceVoice() => 'device',
    PackVoice(:final voice) => voice.id,
  };

  /// Parses [value], returning null when it does not name a real choice.
  static VoiceSelection? decode(
    String? value, {
    required List<VoicePack> catalog,
  }) {
    if (value == null || value.isEmpty) return null;
    if (value == 'device') return const DeviceVoice();
    for (final pack in catalog) {
      for (final voice in pack.voices) {
        if (voice.id == value) return PackVoice(voice);
      }
    }
    return null;
  }
}

class DeviceVoice extends VoiceSelection {
  const DeviceVoice();
}

class PackVoice extends VoiceSelection {
  const PackVoice(this.voice);

  final VoiceOption voice;

  String get packId => voice.packId;
}
