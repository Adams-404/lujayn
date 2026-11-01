import '../domain/models/voice_pack.dart';

/// The voices Lujayn offers, and nothing else.
///
/// Every entry here is a real, published model with a published SHA-256. The
/// speaker ids come from the upstream documentation, not from guesswork: a
/// wrong id means a "female" voice that sounds male, which is exactly the kind
/// of quiet wrongness this project cannot ship.
///
/// The device engine is always available and is never replaced by these. Packs
/// are an opt-in upgrade for people who want a more natural voice.
abstract final class VoiceCatalog {
  /// Light: small enough to download on mobile data without thinking about it.
  ///
  /// Kitten Nano, 8 speakers (4 female, 4 male), 24 kHz.
  /// Speaker map from
  /// https://k2-fsa.github.io/sherpa/onnx/tts/all/English/kitten-nano-en-v0_1.html
  static const VoicePack kittenNano = VoicePack(
    id: 'kitten-nano-en',
    name: 'Light',
    summary:
        'Small and quick to download. Clear, natural speech for short '
        'reminders.',
    language: 'English',
    licence: 'Apache-2.0',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
        'tts-models/kitten-nano-en-v0_1-fp16.tar.bz2',
    sha256: 'f35dac93754fe2ac97c66e1f468311d0d2130f7f0f5a89bfa1197e09a0cbdec5',
    // Measured from the published archive, not estimated.
    downloadBytes: 26855312,
    installedBytes: 41861647,
    // This pack ships a fp16 model under its own name. Getting this wrong is
    // silent: the engine simply refuses to load and the voice never speaks.
    modelFileName: 'model.fp16.onnx',
    voices: [
      VoiceOption(
        packId: 'kitten-nano-en',
        speakerId: 0,
        name: 'Voice 1',
        gender: VoiceGender.male,
      ),
      VoiceOption(
        packId: 'kitten-nano-en',
        speakerId: 1,
        name: 'Voice 2',
        gender: VoiceGender.female,
      ),
      VoiceOption(
        packId: 'kitten-nano-en',
        speakerId: 2,
        name: 'Voice 3',
        gender: VoiceGender.male,
      ),
      VoiceOption(
        packId: 'kitten-nano-en',
        speakerId: 3,
        name: 'Voice 4',
        gender: VoiceGender.female,
      ),
      VoiceOption(
        packId: 'kitten-nano-en',
        speakerId: 4,
        name: 'Voice 5',
        gender: VoiceGender.male,
      ),
      VoiceOption(
        packId: 'kitten-nano-en',
        speakerId: 5,
        name: 'Voice 6',
        gender: VoiceGender.female,
      ),
      VoiceOption(
        packId: 'kitten-nano-en',
        speakerId: 6,
        name: 'Voice 7',
        gender: VoiceGender.male,
      ),
      VoiceOption(
        packId: 'kitten-nano-en',
        speakerId: 7,
        name: 'Voice 8',
        gender: VoiceGender.female,
      ),
    ],
  );

  /// Natural: the best-sounding voice that still fits on a phone.
  ///
  /// Kokoro v0.19, 11 speakers (7 female, 4 male), 24 kHz.
  /// Speaker map from
  /// https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html
  static const VoicePack kokoro = VoicePack(
    id: 'kokoro-en',
    name: 'Natural',
    summary:
        'The most human-sounding voice available offline. A larger download '
        'and more storage.',
    language: 'English',
    licence: 'Apache-2.0',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
        'tts-models/kokoro-int8-en-v0_19.tar.bz2',
    sha256: 'c9f0dd393615805b0bab050c340834d5e684e732aec91c0e860cd30e982c08bd',
    // Measured from the published archive, not estimated.
    downloadBytes: 103248205,
    installedBytes: 157947103,
    // The int8 build ships under its own file name. A wrong name here fails
    // silently at load time, which is why both packs were inspected directly.
    modelFileName: 'model.int8.onnx',
    voices: [
      VoiceOption(
        packId: 'kokoro-en',
        speakerId: 0,
        name: 'Heart',
        gender: VoiceGender.female,
      ),
      VoiceOption(
        packId: 'kokoro-en',
        speakerId: 1,
        name: 'Bella',
        gender: VoiceGender.female,
      ),
      VoiceOption(
        packId: 'kokoro-en',
        speakerId: 2,
        name: 'Nicole',
        gender: VoiceGender.female,
      ),
      VoiceOption(
        packId: 'kokoro-en',
        speakerId: 3,
        name: 'Sarah',
        gender: VoiceGender.female,
      ),
      VoiceOption(
        packId: 'kokoro-en',
        speakerId: 4,
        name: 'Sky',
        gender: VoiceGender.female,
      ),
      VoiceOption(
        packId: 'kokoro-en',
        speakerId: 5,
        name: 'Adam',
        gender: VoiceGender.male,
      ),
      VoiceOption(
        packId: 'kokoro-en',
        speakerId: 6,
        name: 'Michael',
        gender: VoiceGender.male,
      ),
      VoiceOption(
        packId: 'kokoro-en',
        speakerId: 7,
        name: 'Emma',
        gender: VoiceGender.female,
        accent: 'British English',
      ),
      VoiceOption(
        packId: 'kokoro-en',
        speakerId: 8,
        name: 'Isabella',
        gender: VoiceGender.female,
        accent: 'British English',
      ),
      VoiceOption(
        packId: 'kokoro-en',
        speakerId: 9,
        name: 'George',
        gender: VoiceGender.male,
        accent: 'British English',
      ),
      VoiceOption(
        packId: 'kokoro-en',
        speakerId: 10,
        name: 'Lewis',
        gender: VoiceGender.male,
        accent: 'British English',
      ),
    ],
  );

  /// Ordered cheapest-first, because the first question a user has is
  /// "how much will this cost me?".
  static const List<VoicePack> packs = [kittenNano, kokoro];

  static VoicePack? byId(String id) {
    for (final pack in packs) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  /// Every selectable voice across every pack.
  static List<VoiceOption> get allVoices => [
    for (final pack in packs) ...pack.voices,
  ];
}
