import '../models/voice_pack.dart';

/// A rendered piece of speech on disk, ready to be played.
class VoiceSynthesis {
  const VoiceSynthesis({required this.filePath, required this.duration});

  /// Absolute path to a mono WAV file in the app's private cache.
  final String filePath;

  /// How long the clip runs, so the interface can show honest progress.
  final Duration duration;
}

/// Turns text into speech using a downloaded, fully offline voice pack.
///
/// This contract exists so the rest of the app never depends on the native
/// engine directly. A fake can therefore prove that the selected pack is the
/// one being used, and that a broken pack never quietly falls back to the
/// device's robotic voice while claiming to be the natural one.
abstract interface class OfflineVoiceEngine {
  /// Whether every file [pack] needs is present and non-empty.
  ///
  /// This is a cheap file check, not a model load. A model load can take
  /// seconds and must only happen when the user actually asks to hear it.
  Future<bool> isPackReady(VoicePack pack);

  /// Renders [text] with [speakerId] from [pack] and returns a playable file.
  ///
  /// Throws when the pack cannot load or produces no audio. Callers must
  /// report that failure rather than substituting the device voice.
  Future<VoiceSynthesis> synthesize({
    required VoicePack pack,
    required int speakerId,
    required String text,
  });

  /// Releases loaded models and temporary files.
  Future<void> dispose();
}
