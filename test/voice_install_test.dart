import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/voice/data/services/archive_voice_pack_installer.dart';
import 'package:lujayn/features/voice/data/services/voice_pack_downloader.dart';
import 'package:lujayn/features/voice/domain/models/voice_install_progress.dart';
import 'package:lujayn/features/voice/domain/models/voice_pack.dart';
import 'package:lujayn/features/voice/domain/services/voice_pack_installer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;
  late _FixedStorage storage;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('lujayn_voice_test');
    storage = _FixedStorage(tempRoot.path);
  });

  tearDown(() async {
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  /// Builds a real .tar.bz2 containing the files a pack needs.
  Uint8List buildArchive({
    String topLevel = 'test-pack',
    Map<String, String> files = const {
      'model.onnx': 'not really a model',
      'voices.bin': 'voices',
      'tokens.txt': 'tokens',
      'espeak-ng-data/en_dict': 'dictionary',
    },
  }) {
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(
        ArchiveFile.bytes('$topLevel/${entry.key}', entry.value.codeUnits),
      );
    }
    final tar = TarEncoder().encodeBytes(archive);
    return BZip2Encoder().encodeBytes(tar);
  }

  VoicePack packFor(Uint8List archiveBytes, {String? sha256Override}) {
    return VoicePack(
      id: 'test-pack',
      name: 'Test',
      summary: 'A pack used only by tests.',
      language: 'English',
      licence: 'Apache-2.0',
      downloadUrl: 'https://example.invalid/test-pack.tar.bz2',
      sha256: sha256Override ?? sha256.convert(archiveBytes).toString(),
      downloadBytes: archiveBytes.length,
      installedBytes: archiveBytes.length,
      voices: const [
        VoiceOption(
          packId: 'test-pack',
          speakerId: 0,
          name: 'Voice',
          gender: VoiceGender.female,
        ),
      ],
    );
  }

  ArchiveVoicePackInstaller installerFor(Uint8List archiveBytes) {
    return ArchiveVoicePackInstaller(
      storage: storage,
      downloader: _MemoryDownloader(archiveBytes),
    );
  }

  test('installs a verified pack and cleans up its temporary files', () async {
    final bytes = buildArchive();
    final pack = packFor(bytes);
    final installer = installerFor(bytes);

    final events = await installer.install(pack).toList();

    expect(events.first.stage, VoiceInstallStage.downloading);
    expect(
      events.map((event) => event.stage),
      containsAll([
        VoiceInstallStage.downloading,
        VoiceInstallStage.verifying,
        VoiceInstallStage.extracting,
        VoiceInstallStage.done,
      ]),
    );
    expect(events.last.isFinished, isTrue);

    // The pack is usable at its final path, not in a staging directory.
    final model = File(p.join(tempRoot.path, 'test-pack', 'model.onnx'));
    expect(await model.exists(), isTrue);
    expect(await model.readAsString(), 'not really a model');

    expect(await installer.installedPackIds(), {'test-pack'});
    expect(await installer.installedBytes(), greaterThan(0));

    // Nothing large is left behind.
    final leftovers = await tempRoot
        .list()
        .where(
          (entry) =>
              entry.path.endsWith('.part') || entry.path.endsWith('.tar'),
        )
        .toList();
    expect(leftovers, isEmpty);
    final staging = Directory(p.join(tempRoot.path, '.test-pack.staging'));
    expect(await staging.exists(), isFalse);
  });

  test('installing an already installed pack skips its download', () async {
    final bytes = buildArchive();
    final downloader = _MemoryDownloader(bytes);
    final installer = ArchiveVoicePackInstaller(
      storage: storage,
      downloader: downloader,
    );
    final pack = packFor(bytes);

    await installer.install(pack).toList();
    expect(downloader.downloadCalls, 1);

    final secondInstall = await installer.install(pack).toList();

    expect(secondInstall.last.stage, VoiceInstallStage.done);
    expect(downloader.downloadCalls, 1);
    expect(await installer.installedPackIds(), {'test-pack'});
  });

  test('repairs a pack whose model file disappeared', () async {
    final bytes = buildArchive();
    final downloader = _MemoryDownloader(bytes);
    final installer = ArchiveVoicePackInstaller(
      storage: storage,
      downloader: downloader,
    );
    final pack = packFor(bytes);

    await installer.install(pack).toList();
    expect(downloader.downloadCalls, 1);

    // A half-restored backup, or a user clearing files, must be repaired
    // rather than handed to the engine.
    await File(p.join(tempRoot.path, 'test-pack', 'model.onnx')).delete();
    expect(await installer.isReady(pack), isFalse);

    final repaired = await installer.install(pack).toList();
    expect(repaired.last.stage, VoiceInstallStage.done);
    expect(downloader.downloadCalls, 2);
    expect(await installer.isReady(pack), isTrue);
  });

  test('reports download progress against the expected size', () async {
    final bytes = buildArchive();
    final installer = installerFor(bytes);

    final events = await installer.install(packFor(bytes)).toList();
    final downloads = events
        .where((event) => event.stage == VoiceInstallStage.downloading)
        .toList();

    expect(downloads.length, greaterThan(1));
    expect(downloads.first.fraction, 0.0);
    expect(downloads.last.fraction, 1.0);
  });

  test('rejects a download that does not match its checksum', () async {
    final bytes = buildArchive();
    final pack = packFor(bytes, sha256Override: '0' * 64);
    final installer = installerFor(bytes);

    final events = await installer.install(pack).toList();

    expect(events.last.isFailed, isTrue);
    expect(events.last.message, contains('checksum'));
    expect(await installer.installedPackIds(), isEmpty);
    expect(
      await Directory(p.join(tempRoot.path, 'test-pack')).exists(),
      isFalse,
    );
  });

  test('fails cleanly when the archive is corrupt', () async {
    final bytes = Uint8List.fromList(List.filled(2048, 7));
    final installer = installerFor(bytes);

    final events = await installer.install(packFor(bytes)).toList();

    expect(events.last.isFailed, isTrue);
    expect(await installer.installedPackIds(), isEmpty);
    // A broken install must not leave a half-unpacked directory behind.
    final entries = await tempRoot.list().toList();
    expect(entries.where((entry) => !entry.path.endsWith('.part')), isEmpty);
  });

  test('an archive without a wrapping folder still installs', () async {
    final bytes = buildArchive(topLevel: '');
    final installer = installerFor(bytes);

    final events = await installer.install(packFor(bytes)).toList();

    expect(events.last.isFinished, isTrue);
    expect(
      await File(p.join(tempRoot.path, 'test-pack', 'model.onnx')).exists(),
      isTrue,
    );
  });

  test('removing a pack deletes its files and its marker', () async {
    final bytes = buildArchive();
    final installer = installerFor(bytes);
    await installer.install(packFor(bytes)).toList();

    await installer.remove('test-pack');

    expect(await installer.installedPackIds(), isEmpty);
    expect(await installer.installedBytes(), 0);
    expect(
      await Directory(p.join(tempRoot.path, 'test-pack')).exists(),
      isFalse,
    );
  });

  test('a download error is reported as a failure, not an exception', () async {
    final installer = ArchiveVoicePackInstaller(
      storage: storage,
      downloader: _FailingDownloader(),
    );

    final events = await installer
        .install(packFor(Uint8List.fromList([1, 2, 3])))
        .toList();

    expect(events.last.isFailed, isTrue);
    expect(await installer.installedPackIds(), isEmpty);
  });
}

class _FixedStorage implements VoiceStorage {
  _FixedStorage(this.path);

  final String path;

  @override
  Future<String> rootPath() async => path;
}

/// Writes the whole archive in a few chunks so progress is observable.
class _MemoryDownloader implements VoicePackDownloader {
  _MemoryDownloader(this.bytes);

  final Uint8List bytes;
  int downloadCalls = 0;

  @override
  Stream<int> download(String url, File destination) async* {
    downloadCalls++;
    final sink = destination.openWrite();
    var received = 0;
    const chunkSize = 512;
    try {
      while (received < bytes.length) {
        final end = (received + chunkSize).clamp(0, bytes.length);
        sink.add(bytes.sublist(received, end));
        received = end;
        yield received;
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }
}

class _FailingDownloader implements VoicePackDownloader {
  @override
  Stream<int> download(String url, File destination) async* {
    yield 1;
    throw const SocketException('no connection');
  }
}
