import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../domain/models/voice_pack.dart';
import '../../domain/services/offline_voice_engine.dart';
import '../../domain/services/voice_pack_installer.dart';

/// Runs downloaded voice packs through sherpa-onnx, entirely on the device.
///
/// Models are loaded lazily and kept in memory per pack: loading Kokoro takes
/// seconds, so doing it once per reminder would make every alert feel broken.
/// If a model fails to load, the error is surfaced to the caller instead of
/// silently switching to the phone's robotic voice.
class SherpaOfflineVoiceEngine implements OfflineVoiceEngine {
  SherpaOfflineVoiceEngine({
    required this.storage,
    Future<Directory> Function()? cacheDirectory,
  }) : _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  final VoiceStorage storage;
  final Future<Directory> Function() _cacheDirectory;

  final Map<String, sherpa.OfflineTts> _engines = {};
  bool _bindingsReady = false;
  bool _disposed = false;

  @override
  Future<bool> isPackReady(VoicePack pack) async {
    final root = Directory(p.join(await storage.rootPath(), pack.id));
    if (!await root.exists()) return false;
    return _hasEveryFile(root, pack);
  }

  @override
  Future<VoiceSynthesis> synthesize({
    required VoicePack pack,
    required int speakerId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Nothing to speak.');
    }
    if (_disposed) {
      throw StateError('The voice engine has already been closed.');
    }
    if (!await isPackReady(pack)) {
      throw StateError(
        'The ${pack.name} voice files are missing. Download the voice again.',
      );
    }

    final engine = await _engineFor(pack);
    final audio = engine.generate(text: trimmed, sid: speakerId, speed: 0.95);
    if (audio.samples.isEmpty || audio.sampleRate <= 0) {
      throw StateError(
        'The ${pack.name} voice produced no audio for this reminder.',
      );
    }

    final directory = await _cacheDirectory();
    final speechDirectory = Directory(p.join(directory.path, 'lujayn_tts'));
    if (!await speechDirectory.exists()) {
      await speechDirectory.create(recursive: true);
    }
    final file = File(
      p.join(
        speechDirectory.path,
        'speech-${DateTime.now().microsecondsSinceEpoch}.wav',
      ),
    );
    final written = sherpa.writeWave(
      filename: file.path,
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );
    if (!written) {
      throw StateError('The generated speech could not be saved for playback.');
    }

    final milliseconds = (audio.samples.length * 1000 / audio.sampleRate)
        .round();
    return VoiceSynthesis(
      filePath: file.path,
      duration: Duration(milliseconds: milliseconds),
    );
  }

  Future<sherpa.OfflineTts> _engineFor(VoicePack pack) async {
    final cached = _engines[pack.id];
    if (cached != null) return cached;

    _ensureBindings();
    final root = p.join(await storage.rootPath(), pack.id);
    final model = p.join(root, pack.modelFileName);
    final voices = p.join(root, pack.voicesFileName);
    final tokens = p.join(root, pack.tokensFileName);
    final dataDir = p.join(root, pack.dataDirName);

    final modelConfig = switch (pack.family) {
      VoiceModelFamily.kitten => sherpa.OfflineTtsModelConfig(
        kitten: sherpa.OfflineTtsKittenModelConfig(
          model: model,
          voices: voices,
          tokens: tokens,
          dataDir: dataDir,
        ),
        numThreads: 2,
        debug: false,
      ),
      VoiceModelFamily.kokoro => sherpa.OfflineTtsModelConfig(
        kokoro: sherpa.OfflineTtsKokoroModelConfig(
          model: model,
          voices: voices,
          tokens: tokens,
          dataDir: dataDir,
        ),
        numThreads: 2,
        debug: false,
      ),
      VoiceModelFamily.vits => sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: model,
          tokens: tokens,
          dataDir: dataDir,
        ),
        numThreads: 2,
        debug: false,
      ),
    };

    try {
      final engine = sherpa.OfflineTts(
        sherpa.OfflineTtsConfig(model: modelConfig),
      );
      _engines[pack.id] = engine;
      return engine;
    } on Object catch (error) {
      // Loading a corrupt or mismatched model must be a visible failure, not
      // an invitation to speak with a different voice.
      throw StateError(
        'The ${pack.name} voice could not start on this device. '
        'Remove it and download it again. ($error)',
      );
    }
  }

  void _ensureBindings() {
    if (_bindingsReady) return;
    sherpa.initBindings();
    _bindingsReady = true;
  }

  bool _hasEveryFile(Directory root, VoicePack pack) {
    bool hasContent(String path) {
      final file = File(path);
      return file.existsSync() && file.lengthSync() > 0;
    }

    if (!hasContent(p.join(root.path, pack.modelFileName))) return false;
    if (!hasContent(p.join(root.path, pack.voicesFileName))) return false;
    if (!hasContent(p.join(root.path, pack.tokensFileName))) return false;
    final data = Directory(p.join(root.path, pack.dataDirName));
    if (!data.existsSync()) return false;
    // espeak-ng-data is a tree; an empty directory means the archive was
    // truncated, which would fail much later at speaking time.
    return data.listSync().isNotEmpty;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final engine in _engines.values) {
      try {
        engine.free();
      } on Object catch (error) {
        debugPrint('Lujayn voice engine cleanup failed: $error');
      }
    }
    _engines.clear();
  }
}
