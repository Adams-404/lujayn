import 'package:flutter/foundation.dart';

import '../../../reminders/domain/services/reminder_speech_service.dart';
import '../../../reminders/domain/services/voice_playback_service.dart';
import '../../domain/models/voice_pack.dart';
import '../../domain/models/voice_selection.dart';
import '../../domain/services/offline_voice_engine.dart';
import '../../domain/services/voice_pack_installer.dart';
import '../../domain/services/voice_preview_service.dart';
import '../../domain/services/voice_selection_store.dart';
import '../voice_catalog.dart';

/// Speaks with the voice the user chose, and only that voice.
///
/// If a downloaded pack is selected, its files are checked and the pack's own
/// engine speaks. The device's text-to-speech engine is used only when the
/// device voice is the actual selection — never as a silent substitute for a
/// natural voice that failed, because that would make the picker a lie.
class VoicePackSpeechService
    implements ReminderSpeechService, VoicePreviewService {
  VoicePackSpeechService({
    required this.device,
    required this.engine,
    required this.installer,
    required this.selectionStore,
    required this.playback,
    this.catalog = VoiceCatalog.packs,
  });

  final ReminderSpeechService device;
  final OfflineVoiceEngine engine;
  final VoicePackInstaller installer;
  final VoiceSelectionStore selectionStore;
  final VoicePlaybackService playback;
  final List<VoicePack> catalog;

  /// The most recent failure, for a screen that wants to explain silence.
  String? lastFailure;

  @override
  Future<bool> isAvailable() async {
    if (await _selectedPack() != null) return true;
    return device.isAvailable();
  }

  @override
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    lastFailure = null;

    final selection = await _readSelection();
    if (selection is PackVoice) {
      final pack = VoiceCatalog.byId(selection.packId);
      if (pack == null || !await installer.isReady(pack)) {
        lastFailure =
            'The downloaded voice is not ready. Open Settings, then Reminder '
            'voice, and download it again or choose the device voice.';
        throw StateError(lastFailure!);
      }
      await device.stop();
      await _play(pack, selection.voice.speakerId, trimmed);
      return;
    }

    await _stopPlayback();
    await device.speak(trimmed);
  }

  @override
  Future<void> stop() async {
    await _stopPlayback();
    await device.stop();
  }

  @override
  Future<bool> isPreviewAvailable(VoiceOption voice) async {
    final pack = VoiceCatalog.byId(voice.packId);
    if (pack == null) return false;
    return installer.isReady(pack);
  }

  @override
  Future<void> preview(VoiceOption voice) async {
    lastFailure = null;
    final pack = VoiceCatalog.byId(voice.packId);
    if (pack == null) {
      throw StateError('That voice is no longer in the catalogue.');
    }
    if (!await installer.isReady(pack)) {
      throw StateError(
        'The ${pack.name} voice files are missing. Download the voice again.',
      );
    }
    await device.stop();
    await _play(pack, voice.speakerId, voicePreviewText);
  }

  @override
  Future<void> stopPreview() => _stopPlayback();

  Future<void> _play(VoicePack pack, int speakerId, String text) async {
    try {
      final synthesis = await engine.synthesize(
        pack: pack,
        speakerId: speakerId,
        text: text,
      );
      await playback.play(synthesis.filePath);
    } on Object catch (error) {
      lastFailure = error is StateError ? error.message : error.toString();
      debugPrint('Lujayn voice playback failed: $error');
      rethrow;
    }
  }

  Future<VoicePack?> _selectedPack() async {
    final selection = await _readSelection();
    if (selection is! PackVoice) return null;
    final pack = VoiceCatalog.byId(selection.packId);
    if (pack == null) return null;
    return await installer.isReady(pack) ? pack : null;
  }

  Future<VoiceSelection> _readSelection() async {
    final decoded = VoiceSelection.decode(
      await selectionStore.readSelection(),
      catalog: catalog,
    );
    return decoded ?? VoiceSelection.device;
  }

  Future<void> _stopPlayback() async {
    try {
      await playback.stop();
    } on Object catch (error) {
      debugPrint('Lujayn speech playback stop failed: $error');
    }
  }

  Future<void> dispose() async {
    await stop();
    await engine.dispose();
    await playback.dispose();
  }
}
