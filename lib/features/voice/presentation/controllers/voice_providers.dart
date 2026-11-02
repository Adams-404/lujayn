import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../reminders/data/services/audioplayers_voice_playback_service.dart';
import '../../../reminders/data/services/flutter_reminder_speech_service.dart';
import '../../../reminders/data/services/noop_reminder_speech_service.dart';
import '../../../reminders/domain/services/reminder_speech_service.dart';
import '../../../reminders/domain/services/voice_playback_service.dart';
import '../../domain/models/voice_install_progress.dart';
import '../../domain/models/voice_pack.dart';
import '../../domain/models/voice_selection.dart';
import '../../domain/services/offline_voice_engine.dart';
import '../../domain/services/voice_pack_installer.dart';
import '../../domain/services/voice_preview_service.dart';
import '../../domain/services/voice_selection_store.dart';
import '../../data/services/app_support_voice_storage.dart';
import '../../data/services/archive_voice_pack_installer.dart';
import '../../data/services/sherpa_offline_voice_engine.dart';
import '../../data/services/voice_pack_speech_service.dart';
import '../../data/voice_catalog.dart';

// Keep the selection-store contract available to screens and tests that
// already import this controller library.
export '../../domain/services/voice_selection_store.dart';

/// Where the chosen voice is remembered between launches.
class SharedPreferencesVoiceSelectionStore implements VoiceSelectionStore {
  SharedPreferencesVoiceSelectionStore()
    : _preferences = SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  static const _key = 'lujayn.voice.selection';

  @override
  Future<String?> readSelection() => _preferences.getString(_key);

  @override
  Future<void> writeSelection(String value) =>
      _preferences.setString(_key, value);
}

final voiceStorageProvider = Provider<VoiceStorage>(
  (ref) => AppSupportVoiceStorage(),
);

final voicePackInstallerProvider = Provider<VoicePackInstaller>((ref) {
  return ArchiveVoicePackInstaller(storage: ref.watch(voiceStorageProvider));
});

final voiceSelectionStoreProvider = Provider<VoiceSelectionStore>(
  (ref) => SharedPreferencesVoiceSelectionStore(),
);

final voiceCatalogProvider = Provider<List<VoicePack>>(
  (ref) => VoiceCatalog.packs,
);

/// The native offline engine. Created only on platforms that ship it, and
/// disposed with the provider so a hot restart does not leak a loaded model.
final offlineVoiceEngineProvider = Provider<OfflineVoiceEngine?>((ref) {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return null;
  }
  final engine = SherpaOfflineVoiceEngine(
    storage: ref.watch(voiceStorageProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// Playback for generated speech, separate from the voice-note player so a
/// reminder's recording and its spoken reading never fight over one channel.
final voiceSpeechPlaybackProvider = Provider<VoicePlaybackService>((ref) {
  final service = AudioplayersVoicePlaybackService();
  ref.onDispose(service.dispose);
  return service;
});

/// Speaks with the selected voice and previews voices in the picker.
final voicePackSpeechServiceProvider = Provider<VoicePackSpeechService?>((ref) {
  final engine = ref.watch(offlineVoiceEngineProvider);
  if (engine == null) return null;
  final service = VoicePackSpeechService(
    device: FlutterReminderSpeechService(),
    engine: engine,
    installer: ref.watch(voicePackInstallerProvider),
    selectionStore: ref.watch(voiceSelectionStoreProvider),
    playback: ref.watch(voiceSpeechPlaybackProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Preview control used by the voice picker.
final voicePreviewServiceProvider = Provider<VoicePreviewService?>((ref) {
  return ref.watch(voicePackSpeechServiceProvider);
});

/// The app-wide speech contract. Falls back to the device engine only when
/// that is genuinely the selected voice, or when no offline engine exists.
final reminderSpeechServiceProvider = Provider<ReminderSpeechService>((ref) {
  final packAware = ref.watch(voicePackSpeechServiceProvider);
  if (packAware != null) return packAware;
  if (defaultTargetPlatform == TargetPlatform.android) {
    return FlutterReminderSpeechService();
  }
  return const NoopReminderSpeechService();
});

/// Everything the voice screen needs to draw itself.
class VoiceLibraryState {
  const VoiceLibraryState({
    required this.installedPacks,
    required this.selection,
    this.progress = const {},
  });

  final Set<String> installedPacks;
  final VoiceSelection selection;

  /// In-flight installs, keyed by pack id. Absent means nothing is happening.
  final Map<String, VoiceInstallProgress> progress;

  bool isInstalled(String packId) => installedPacks.contains(packId);

  bool isInstalling(String packId) {
    final current = progress[packId];
    return current != null && !current.isFinished && !current.isFailed;
  }

  VoiceLibraryState copyWith({
    Set<String>? installedPacks,
    VoiceSelection? selection,
    Map<String, VoiceInstallProgress>? progress,
  }) {
    return VoiceLibraryState(
      installedPacks: installedPacks ?? this.installedPacks,
      selection: selection ?? this.selection,
      progress: progress ?? this.progress,
    );
  }
}

/// Owns the installed packs, the selected voice, and any install in flight.
///
/// One notifier rather than three, because the three facts are not
/// independent: deleting a pack has to move the selection off it, and
/// finishing an install has to make the new voices selectable.
class VoiceLibraryNotifier extends AsyncNotifier<VoiceLibraryState> {
  late VoicePackInstaller _installer;
  late VoiceSelectionStore _store;
  final Map<String, StreamSubscription<VoiceInstallProgress>> _subscriptions =
      {};

  @override
  Future<VoiceLibraryState> build() async {
    _installer = ref.watch(voicePackInstallerProvider);
    _store = ref.watch(voiceSelectionStoreProvider);
    final catalog = ref.watch(voiceCatalogProvider);

    ref.onDispose(() {
      for (final subscription in _subscriptions.values) {
        subscription.cancel();
      }
      _subscriptions.clear();
    });

    final installed = await _installedPacks();
    final decoded = VoiceSelection.decode(
      await _store.readSelection(),
      catalog: catalog,
    );
    // A pack the user deleted must not stay selected: silently falling back to
    // the device voice is better than speaking with a voice that is not there.
    final selection = switch (decoded) {
      PackVoice(:final packId) when !installed.contains(packId) =>
        VoiceSelection.device,
      final other => other ?? VoiceSelection.device,
    };

    return VoiceLibraryState(installedPacks: installed, selection: selection);
  }

  Future<void> select(VoiceSelection selection) async {
    final current = state.value;
    if (current == null) return;
    if (selection is PackVoice && !current.isInstalled(selection.packId)) {
      return;
    }
    await _store.writeSelection(selection.encode());
    state = AsyncData(current.copyWith(selection: selection));
  }

  /// Starts an install and mirrors its progress into [state].
  void install(VoicePack pack) {
    final current = state.value;
    if (current == null || current.isInstalling(pack.id)) return;

    _subscriptions.remove(pack.id)?.cancel();
    final subscription = _installer
        .install(pack)
        .listen(
          (progress) {
            final latest = state.value;
            if (latest == null) return;
            state = AsyncData(
              latest.copyWith(
                progress: {...latest.progress, pack.id: progress},
              ),
            );
            if (progress.isFinished) {
              _onInstalled(pack);
            }
          },
          onError: (Object error) {
            final latest = state.value;
            if (latest == null) return;
            state = AsyncData(
              latest.copyWith(
                progress: {
                  ...latest.progress,
                  pack.id: const VoiceInstallProgress.failed(
                    'The voice could not be installed. Please try again.',
                  ),
                },
              ),
            );
          },
        );
    _subscriptions[pack.id] = subscription;
  }

  /// Only packs that are complete on disk count as installed.
  Future<Set<String>> _installedPacks() async {
    final catalog = ref.read(voiceCatalogProvider);
    final installed = <String>{};
    for (final pack in catalog) {
      if (await _installer.isReady(pack)) installed.add(pack.id);
    }
    return installed;
  }

  Future<void> _onInstalled(VoicePack pack) async {
    _subscriptions.remove(pack.id)?.cancel();
    final installed = await _installedPacks();
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(installedPacks: installed));
  }

  /// Deletes a pack and moves the selection to the device voice if it was in
  /// use.
  Future<void> remove(VoicePack pack) async {
    final current = state.value;
    if (current == null) return;

    await _installer.remove(pack.id);
    final installed = await _installedPacks();

    var selection = state.value?.selection ?? current.selection;
    if (selection is PackVoice && selection.packId == pack.id) {
      selection = VoiceSelection.device;
      await _store.writeSelection(selection.encode());
    }

    state = AsyncData(
      VoiceLibraryState(installedPacks: installed, selection: selection),
    );
  }

  /// Drops a finished or failed install message so the row goes back to normal.
  void dismissProgress(String packId) {
    final current = state.value;
    if (current == null) return;
    final next = {...current.progress}..remove(packId);
    state = AsyncData(current.copyWith(progress: next));
  }
}

final voiceLibraryProvider =
    AsyncNotifierProvider<VoiceLibraryNotifier, VoiceLibraryState>(
      VoiceLibraryNotifier.new,
    );
