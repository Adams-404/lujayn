import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/voice/data/voice_catalog.dart';
import 'package:lujayn/features/voice/domain/models/voice_install_progress.dart';
import 'package:lujayn/features/voice/domain/models/voice_pack.dart';
import 'package:lujayn/features/voice/domain/services/voice_pack_installer.dart';
import 'package:lujayn/features/voice/domain/services/voice_preview_service.dart';
import 'package:lujayn/features/voice/presentation/controllers/voice_providers.dart';
import 'package:lujayn/features/voice/presentation/screens/voice_settings_screen.dart';

void main() {
  late _FakeInstaller installer;
  late _MemorySelectionStore store;
  late _FakePreview preview;

  setUp(() {
    installer = _FakeInstaller();
    store = _MemorySelectionStore();
    preview = _FakePreview();
  });

  /// The picker is a long list; a short test window would push most of it
  /// off-screen and make taps unreliable.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget wrap() {
    return ProviderScope(
      overrides: [
        voicePackInstallerProvider.overrideWithValue(installer),
        voiceSelectionStoreProvider.overrideWithValue(store),
        voicePreviewServiceProvider.overrideWithValue(preview),
      ],
      child: const MaterialApp(home: VoiceSettingsScreen()),
    );
  }

  testWidgets('offers the device voice and every pack with its size', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Device voice'), findsOneWidget);
    for (final pack in VoiceCatalog.packs) {
      expect(find.text(pack.name.toUpperCase()), findsOneWidget);
      expect(find.text('${pack.downloadLabel} download'), findsOneWidget);
    }
    // The device voice is the safe default.
    expect(find.text('Device voice'), findsOneWidget);
  });

  testWidgets('says how much storage a download will need', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    for (final pack in VoiceCatalog.packs) {
      expect(
        find.textContaining('about ${pack.installedLabel} of storage'),
        findsOneWidget,
      );
    }
  });

  testWidgets('downloading a pack makes its voices selectable', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Nothing is installed, so no voice names are offered yet.
    expect(find.text('Heart'), findsNothing);

    await tester.ensureVisible(find.text('Download').first);
    await tester.tap(find.text('Download').first);
    await tester.pumpAndSettle();

    expect(installer.installRequests, [VoiceCatalog.packs.first.id]);
    expect(find.text('Voice 1'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
  });

  testWidgets('selecting a downloaded voice is remembered', (tester) async {
    useTallScreen(tester);
    installer.installed.add(VoiceCatalog.kokoro.id);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bella'));
    await tester.tap(find.text('Bella'));
    await tester.pumpAndSettle();

    expect(store.written, contains('kokoro-en#1'));
  });

  testWidgets('a voice can be heard before it is chosen', (tester) async {
    useTallScreen(tester);
    installer.installed.add(VoiceCatalog.kokoro.id);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Preview Bella'));
    await tester.tap(find.byTooltip('Preview Bella'));
    await tester.pumpAndSettle();

    expect(preview.previewed, ['kokoro-en#1']);
    // Hearing a voice is not the same as choosing it.
    expect(store.written, isEmpty);
  });

  testWidgets('choosing a voice plays it so the choice is not blind', (
    tester,
  ) async {
    useTallScreen(tester);
    installer.installed.add(VoiceCatalog.kokoro.id);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bella'));
    await tester.tap(find.text('Bella'));
    await tester.pumpAndSettle();

    expect(store.written, contains('kokoro-en#1'));
    expect(preview.previewed, ['kokoro-en#1']);
  });

  testWidgets('a failed install explains itself and offers a retry', (
    tester,
  ) async {
    useTallScreen(tester);
    installer.failInstall = true;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Download').first);
    await tester.tap(find.text('Download').first);
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('removing the pack in use falls back to the device voice', (
    tester,
  ) async {
    useTallScreen(tester);
    installer.installed.add(VoiceCatalog.kokoro.id);
    store.value = 'kokoro-en#1';
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('Remove download').first);
    await tester.tap(find.textContaining('Remove download').first);
    await tester.pumpAndSettle();

    expect(find.text('Remove this voice?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(installer.removed, contains(VoiceCatalog.kokoro.id));
    expect(store.value, 'device');
    // The voices are gone from the list.
    expect(find.text('Bella'), findsNothing);
  });
}

class _FakePreview implements VoicePreviewService {
  final List<String> previewed = [];

  @override
  Future<bool> isPreviewAvailable(VoiceOption voice) async => true;

  @override
  Future<void> preview(VoiceOption voice) async => previewed.add(voice.id);

  @override
  Future<void> stopPreview() async {}
}

class _FakeInstaller implements VoicePackInstaller {
  _FakeInstaller({Set<String>? installed}) : installed = installed ?? {};

  final Set<String> installed;
  final List<String> installRequests = [];
  final List<String> removed = [];
  bool failInstall = false;

  @override
  Stream<VoiceInstallProgress> install(VoicePack pack) async* {
    installRequests.add(pack.id);
    if (failInstall) {
      yield const VoiceInstallProgress.failed('Could not install.');
      return;
    }
    yield VoiceInstallProgress(
      stage: VoiceInstallStage.downloading,
      receivedBytes: pack.downloadBytes ~/ 2,
      totalBytes: pack.downloadBytes,
    );
    installed.add(pack.id);
    yield const VoiceInstallProgress(stage: VoiceInstallStage.done);
  }

  @override
  Future<void> remove(String packId) async {
    removed.add(packId);
    installed.remove(packId);
  }

  @override
  Future<Set<String>> installedPackIds() async => {...installed};

  @override
  Future<bool> isReady(VoicePack pack) async => installed.contains(pack.id);

  @override
  Future<int> installedBytes() async => installed.length * 1024;
}

class _MemorySelectionStore implements VoiceSelectionStore {
  String? value;
  final List<String> written = [];

  @override
  Future<String?> readSelection() async => value;

  @override
  Future<void> writeSelection(String value) async {
    this.value = value;
    written.add(value);
  }
}
