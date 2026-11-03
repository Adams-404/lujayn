import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_speech_service.dart';
import 'package:lujayn/features/reminders/domain/services/voice_playback_service.dart';
import 'package:lujayn/features/voice/data/services/voice_pack_speech_service.dart';
import 'package:lujayn/features/voice/data/voice_catalog.dart';
import 'package:lujayn/features/voice/domain/models/voice_install_progress.dart';
import 'package:lujayn/features/voice/domain/models/voice_pack.dart';
import 'package:lujayn/features/voice/domain/models/voice_selection.dart';
import 'package:lujayn/features/voice/domain/services/offline_voice_engine.dart';
import 'package:lujayn/features/voice/domain/services/voice_pack_installer.dart';
import 'package:lujayn/features/voice/domain/services/voice_preview_service.dart';
import 'package:lujayn/features/voice/domain/services/voice_selection_store.dart';

void main() {
  late _FakeDeviceSpeech device;
  late _FakeEngine engine;
  late _FakeInstaller installer;
  late _FakeSelectionStore store;
  late _FakePlayback playback;
  late VoicePackSpeechService service;

  final pack = VoiceCatalog.kokoro;
  final voice = pack.femaleVoices.first;

  setUp(() {
    device = _FakeDeviceSpeech();
    engine = _FakeEngine();
    installer = _FakeInstaller({pack.id});
    store = _FakeSelectionStore('device');
    playback = _FakePlayback();
    service = VoicePackSpeechService(
      device: device,
      engine: engine,
      installer: installer,
      selectionStore: store,
      playback: playback,
    );
  });

  test('uses the phone voice when the device voice is selected', () async {
    await service.speak('Take your medication.');

    expect(device.spoken, ['Take your medication.']);
    expect(engine.requests, isEmpty);
  });

  test('uses the selected pack and speaker, not the phone voice', () async {
    store.value = PackVoice(voice).encode();

    await service.speak('Take your medication.');

    expect(engine.requests, hasLength(1));
    expect(engine.requests.single.pack.id, pack.id);
    expect(engine.requests.single.speakerId, voice.speakerId);
    expect(engine.requests.single.text, 'Take your medication.');
    expect(playback.played, ['/tmp/generated.wav']);
    expect(device.spoken, isEmpty);
  });

  test(
    'a broken pack fails loudly instead of faking the device voice',
    () async {
      store.value = PackVoice(voice).encode();
      installer.ready.clear();

      await expectLater(service.speak('Hello'), throwsStateError);

      expect(device.spoken, isEmpty);
      expect(service.lastFailure, contains('download it again'));
    },
  );

  test(
    'a pack that is ready still speaks when the phone has no engine',
    () async {
      store.value = PackVoice(voice).encode();
      device.available = false;

      expect(await service.isAvailable(), isTrue);
    },
  );

  test('previews the chosen voice with the shared sample line', () async {
    await service.preview(voice);

    expect(engine.requests.single.speakerId, voice.speakerId);
    expect(engine.requests.single.text, voicePreviewText);
    expect(playback.played, ['/tmp/generated.wav']);
  });

  test('stopping a preview during synthesis prevents stale playback', () async {
    final pending = Completer<VoiceSynthesis>();
    engine.pending = pending;

    final preview = service.preview(voice);
    await Future<void>.delayed(Duration.zero);
    await service.stopPreview();
    pending.complete(
      const VoiceSynthesis(
        filePath: '/tmp/generated.wav',
        duration: Duration(seconds: 3),
      ),
    );
    await preview;

    expect(playback.played, isEmpty);
  });

  test('refuses to preview a voice whose pack is not installed', () async {
    installer.ready.clear();

    await expectLater(service.preview(voice), throwsStateError);
    expect(engine.requests, isEmpty);
  });
}

class _FakeDeviceSpeech implements ReminderSpeechService {
  bool available = true;
  final List<String> spoken = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

class _SynthesisRequest {
  const _SynthesisRequest({
    required this.pack,
    required this.speakerId,
    required this.text,
  });

  final VoicePack pack;
  final int speakerId;
  final String text;
}

class _FakeEngine implements OfflineVoiceEngine {
  final List<_SynthesisRequest> requests = [];
  Completer<VoiceSynthesis>? pending;

  @override
  Future<bool> isPackReady(VoicePack pack) async => true;

  @override
  Future<VoiceSynthesis> synthesize({
    required VoicePack pack,
    required int speakerId,
    required String text,
  }) async {
    requests.add(
      _SynthesisRequest(pack: pack, speakerId: speakerId, text: text),
    );
    return pending?.future ??
        const VoiceSynthesis(
          filePath: '/tmp/generated.wav',
          duration: Duration(seconds: 3),
        );
  }

  @override
  Future<void> dispose() async {}
}

class _FakeInstaller implements VoicePackInstaller {
  _FakeInstaller(this.ready);

  final Set<String> ready;

  @override
  Stream<VoiceInstallProgress> install(VoicePack pack) => const Stream.empty();

  @override
  Future<void> remove(String packId) async => ready.remove(packId);

  @override
  Future<Set<String>> installedPackIds() async => {...ready};

  @override
  Future<bool> isReady(VoicePack pack) async => ready.contains(pack.id);

  @override
  Future<int> installedBytes() async => 0;
}

class _FakeSelectionStore implements VoiceSelectionStore {
  _FakeSelectionStore(this.value);

  String? value;

  @override
  Future<String?> readSelection() async => value;

  @override
  Future<void> writeSelection(String value) async => this.value = value;
}

class _FakePlayback implements VoicePlaybackService {
  final List<String> played = [];

  @override
  Stream<VoicePlaybackState> get stateStream => const Stream.empty();

  @override
  VoicePlaybackState get currentState => const VoicePlaybackState();

  @override
  Future<void> play(String filePath) async => played.add(filePath);

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() async {}
}
