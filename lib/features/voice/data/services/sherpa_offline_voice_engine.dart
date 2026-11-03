import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../domain/models/voice_pack.dart';
import '../../domain/services/offline_voice_engine.dart';
import '../../domain/services/voice_pack_installer.dart';

/// Runs downloaded voice packs through sherpa-onnx, entirely on the device.
///
/// Native inference runs in a dedicated isolate. The model stays loaded in
/// that isolate and is reused, so synthesis cannot freeze Flutter's UI thread
/// and reminders do not pay the model-loading cost on every call.
class SherpaOfflineVoiceEngine implements OfflineVoiceEngine {
  SherpaOfflineVoiceEngine({
    required this.storage,
    Future<Directory> Function()? cacheDirectory,
  }) : _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  final VoiceStorage storage;
  final Future<Directory> Function() _cacheDirectory;

  Isolate? _worker;
  ReceivePort? _responses;
  ReceivePort? _errors;
  SendPort? _commands;
  Future<SendPort>? _workerReady;
  final Map<int, Completer<Map<Object?, Object?>>> _pending = {};
  int _nextRequestId = 0;
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

    final root = p.join(await storage.rootPath(), pack.id);
    final directory = await _cacheDirectory();
    final speechDirectory = Directory(p.join(directory.path, 'lujayn_tts'));
    if (!await speechDirectory.exists()) {
      await speechDirectory.create(recursive: true);
    }
    final outputPath = p.join(
      speechDirectory.path,
      'speech-${DateTime.now().microsecondsSinceEpoch}.wav',
    );

    final result = await _request({
      'operation': 'synthesize',
      'packId': pack.id,
      'family': pack.family.name,
      'model': p.join(root, pack.modelFileName),
      'voices': p.join(root, pack.voicesFileName),
      'tokens': p.join(root, pack.tokensFileName),
      'dataDir': p.join(root, pack.dataDirName),
      'speakerId': speakerId,
      'text': trimmed,
      'outputPath': outputPath,
    });

    if (result['ok'] != true) {
      throw StateError(
        (result['error'] as String?) ??
            'The ${pack.name} voice could not generate speech.',
      );
    }

    return VoiceSynthesis(
      filePath: outputPath,
      duration: Duration(milliseconds: result['durationMs'] as int),
    );
  }

  Future<Map<Object?, Object?>> _request(Map<String, Object?> payload) async {
    final commands = await _ensureWorker();
    final id = ++_nextRequestId;
    final completer = Completer<Map<Object?, Object?>>();
    _pending[id] = completer;
    commands.send({...payload, 'requestId': id});
    return completer.future;
  }

  Future<SendPort> _ensureWorker() {
    return _workerReady ??= _startWorker();
  }

  Future<SendPort> _startWorker() async {
    final responses = ReceivePort();
    final errors = ReceivePort();
    final ready = Completer<SendPort>();
    _responses = responses;
    _errors = errors;

    responses.listen((message) {
      if (message is SendPort) {
        _commands = message;
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      if (message is Map) {
        final id = message['requestId'];
        if (id is int) {
          final completer = _pending.remove(id);
          if (completer != null && !completer.isCompleted) {
            completer.complete(Map<Object?, Object?>.from(message));
          }
        }
      }
    });

    errors.listen((message) {
      final error = StateError('Offline voice worker failed: $message');
      if (!ready.isCompleted) ready.completeError(error);
      for (final completer in _pending.values) {
        if (!completer.isCompleted) completer.completeError(error);
      }
      _pending.clear();
      _commands = null;
    });

    try {
      _worker = await Isolate.spawn<SendPort>(
        _sherpaVoiceWorker,
        responses.sendPort,
        onError: errors.sendPort,
      );
      return await ready.future;
    } on Object {
      responses.close();
      errors.close();
      rethrow;
    }
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
    return data.listSync().isNotEmpty;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final commands = _commands;
    if (commands != null) {
      try {
        await _requestAfterDispose(commands, 'dispose');
      } on Object catch (error) {
        debugPrint('Lujayn voice worker cleanup failed: $error');
      }
    }
    _worker?.kill(priority: Isolate.immediate);
    _responses?.close();
    _errors?.close();
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('The voice engine has already been closed.'),
        );
      }
    }
    _pending.clear();
  }

  Future<void> _requestAfterDispose(SendPort commands, String operation) async {
    final id = ++_nextRequestId;
    final completer = Completer<Map<Object?, Object?>>();
    _pending[id] = completer;
    commands.send({'operation': operation, 'requestId': id});
    await completer.future.timeout(const Duration(seconds: 3));
  }
}

/// Entry point for the long-lived native inference isolate.
void _sherpaVoiceWorker(SendPort mainPort) {
  final commands = ReceivePort();
  final engines = <String, sherpa.OfflineTts>{};
  var bindingsReady = false;
  mainPort.send(commands.sendPort);

  commands.listen((message) {
    if (message is! Map) return;
    final requestId = message['requestId'];
    final operation = message['operation'];

    if (operation == 'dispose') {
      for (final engine in engines.values) {
        try {
          engine.free();
        } on Object {
          // Continue releasing the remaining native models.
        }
      }
      engines.clear();
      mainPort.send({'requestId': requestId, 'ok': true});
      commands.close();
      Isolate.exit();
    }

    if (operation != 'synthesize') return;

    try {
      if (!bindingsReady) {
        sherpa.initBindings();
        bindingsReady = true;
      }

      final packId = message['packId'] as String;
      var engine = engines[packId];
      if (engine == null) {
        final model = message['model'] as String;
        final voices = message['voices'] as String;
        final tokens = message['tokens'] as String;
        final dataDir = message['dataDir'] as String;
        final family = message['family'] as String;

        final modelConfig = switch (family) {
          'kitten' => sherpa.OfflineTtsModelConfig(
            kitten: sherpa.OfflineTtsKittenModelConfig(
              model: model,
              voices: voices,
              tokens: tokens,
              dataDir: dataDir,
            ),
            numThreads: 2,
            debug: false,
          ),
          'kokoro' => sherpa.OfflineTtsModelConfig(
            kokoro: sherpa.OfflineTtsKokoroModelConfig(
              model: model,
              voices: voices,
              tokens: tokens,
              dataDir: dataDir,
            ),
            numThreads: 2,
            debug: false,
          ),
          'vits' => sherpa.OfflineTtsModelConfig(
            vits: sherpa.OfflineTtsVitsModelConfig(
              model: model,
              tokens: tokens,
              dataDir: dataDir,
            ),
            numThreads: 2,
            debug: false,
          ),
          _ => throw StateError('Unsupported voice model family: $family'),
        };

        engine = sherpa.OfflineTts(sherpa.OfflineTtsConfig(model: modelConfig));
        engines[packId] = engine;
      }

      final audio = engine.generate(
        text: message['text'] as String,
        sid: message['speakerId'] as int,
        speed: 0.95,
      );
      if (audio.samples.isEmpty || audio.sampleRate <= 0) {
        throw StateError('The selected voice produced no audio.');
      }

      final outputPath = message['outputPath'] as String;
      final written = sherpa.writeWave(
        filename: outputPath,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      if (!written) {
        throw StateError('The generated speech could not be saved.');
      }

      final durationMs = (audio.samples.length * 1000 / audio.sampleRate)
          .round();
      mainPort.send({
        'requestId': requestId,
        'ok': true,
        'durationMs': durationMs,
      });
    } on Object catch (error, stackTrace) {
      mainPort.send({
        'requestId': requestId,
        'ok': false,
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
    }
  });
}
