/// Who a voice sounds like. Used only to group the picker; it is never
/// inferred from audio, so a pack must declare it accurately.
enum VoiceGender { female, male }

/// Which sherpa-onnx model family a pack belongs to.
///
/// The families take different configuration objects, and using the wrong one
/// fails at load time with no useful message. Each pack therefore states its
/// family explicitly instead of the adapter guessing from the pack id.
enum VoiceModelFamily { vits, kitten, kokoro }

/// One selectable speaker inside a downloaded pack.
///
/// [speakerId] is the model's own integer speaker id. It is not stable across
/// packs, so a voice is always addressed by its full [id].
class VoiceOption {
  const VoiceOption({
    required this.packId,
    required this.speakerId,
    required this.name,
    required this.gender,
    this.accent,
  });

  /// The pack this speaker belongs to.
  final String packId;

  /// The integer speaker id the engine expects.
  final int speakerId;

  /// A short, human name such as "Bella". Not a model id.
  final String name;

  final VoiceGender gender;

  /// Optional accent note, e.g. "British English".
  final String? accent;

  /// Stable identity used for storage and selection.
  String get id => '$packId#$speakerId';

  String get genderLabel => switch (gender) {
    VoiceGender.female => 'Female',
    VoiceGender.male => 'Male',
  };

  @override
  String toString() => 'VoiceOption($id, $name)';
}

/// A downloadable on-device speech model.
///
/// A pack is downloaded once, verified against [sha256], and then used with no
/// network connection at all. Every pack must stay small enough to install on a
/// phone: [maxPackBytes] is enforced by a test, not by hope.
class VoicePack {
  const VoicePack({
    required this.id,
    required this.name,
    required this.summary,
    required this.language,
    required this.licence,
    required this.downloadUrl,
    required this.sha256,
    required this.downloadBytes,
    required this.installedBytes,
    required this.voices,
    this.family = VoiceModelFamily.vits,
    this.modelFileName = 'model.onnx',
    this.voicesFileName = 'voices.bin',
    this.tokensFileName = 'tokens.txt',
    this.dataDirName = 'espeak-ng-data',
  });

  /// Hard ceiling for a pack. The product decision was 200 MB; anything above
  /// this should be rejected in review rather than quietly shipped.
  static const int maxPackBytes = 200 * 1024 * 1024;

  final String id;

  /// Display name, e.g. "Natural".
  final String name;

  /// One sentence on what the pack is for and what it costs the user.
  final String summary;

  final String language;

  /// The licence the model weights are published under. Shown to the user
  /// because downloading a model is the one place a licence matters to them.
  final String licence;

  final String downloadUrl;

  /// Lowercase hex SHA-256 of the exact archive at [downloadUrl].
  final String sha256;

  /// Size of the download.
  final int downloadBytes;

  /// Approximate size once extracted, for the storage warning.
  final int installedBytes;

  final List<VoiceOption> voices;

  /// The model family this pack's files belong to.
  final VoiceModelFamily family;

  final String modelFileName;
  final String voicesFileName;
  final String tokensFileName;
  final String dataDirName;

  /// Whether this is a large download worth warning about on mobile data.
  bool get isLargeDownload => downloadBytes > 50 * 1024 * 1024;

  String get downloadLabel =>
      '${(downloadBytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  String get installedLabel => '${(installedBytes / (1024 * 1024)).round()} MB';

  Iterable<VoiceOption> get femaleVoices =>
      voices.where((voice) => voice.gender == VoiceGender.female);

  Iterable<VoiceOption> get maleVoices =>
      voices.where((voice) => voice.gender == VoiceGender.male);
}
