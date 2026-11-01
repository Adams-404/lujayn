import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/voice_install_progress.dart';
import '../../domain/models/voice_pack.dart';
import '../../domain/services/voice_pack_installer.dart';
import 'voice_pack_downloader.dart';

/// Downloads, checks and unpacks voice packs on the device.
///
/// The install is staged: everything happens in temporary paths, and the pack
/// only becomes visible under its real name once every step has succeeded. A
/// cancelled download, a corrupted file, or a full disk therefore leaves no
/// half-installed pack that the app would later try to speak with.
class ArchiveVoicePackInstaller implements VoicePackInstaller {
  ArchiveVoicePackInstaller({
    required this.storage,
    VoicePackDownloader? downloader,
  }) : _downloader = downloader ?? HttpVoicePackDownloader();

  final VoiceStorage storage;
  final VoicePackDownloader _downloader;

  /// Marks a directory as a finished install, so an interrupted run cannot be
  /// mistaken for a usable pack.
  static const _markerFile = '.lujayn-voice-pack';

  @override
  Stream<VoiceInstallProgress> install(VoicePack pack) async* {
    final root = await storage.rootPath();
    final download = File(p.join(root, '${pack.id}.part'));
    final tarball = File(p.join(root, '${pack.id}.tar'));
    final staging = Directory(p.join(root, '.${pack.id}.staging'));
    final target = Directory(p.join(root, pack.id));

    try {
      await Directory(root).create(recursive: true);
      await _deleteIfPresent(staging);
      await staging.create(recursive: true);

      yield VoiceInstallProgress(
        stage: VoiceInstallStage.downloading,
        totalBytes: pack.downloadBytes,
      );

      await for (final received in _downloader.download(
        pack.downloadUrl,
        download,
      )) {
        yield VoiceInstallProgress(
          stage: VoiceInstallStage.downloading,
          receivedBytes: received,
          totalBytes: pack.downloadBytes,
        );
      }

      yield const VoiceInstallProgress(stage: VoiceInstallStage.verifying);
      final digest = await sha256.bind(download.openRead()).first;
      if (digest.toString() != pack.sha256) {
        yield const VoiceInstallProgress.failed(
          'The download did not match its checksum, so it was thrown away. '
          'Nothing was installed. Please try again.',
        );
        return;
      }

      yield const VoiceInstallProgress(stage: VoiceInstallStage.extracting);
      // Unpacking a 100 MB archive is slow and CPU-bound. Doing it on a
      // background isolate keeps the app responsive while it happens.
      await Isolate.run(
        () => _unpack(
          downloadPath: download.path,
          tarballPath: tarball.path,
          stagingPath: staging.path,
        ),
      );

      final packRoot = await _resolvePackRoot(staging);
      await File(
        p.join(packRoot.path, _markerFile),
      ).writeAsString(pack.id, flush: true);

      await _deleteIfPresent(target);
      if (p.equals(packRoot.path, staging.path)) {
        await staging.rename(target.path);
      } else {
        await packRoot.rename(target.path);
        await _deleteIfPresent(staging);
      }

      yield const VoiceInstallProgress(stage: VoiceInstallStage.done);
    } on Object catch (error, stack) {
      debugPrint('Lujayn voice install failed: $error\n$stack');
      yield const VoiceInstallProgress.failed(
        'The voice could not be installed. Check your connection and free '
        'space, then try again.',
      );
    } finally {
      // Whatever happened, the large temporary files must not survive.
      await _deleteIfPresent(download);
      await _deleteIfPresent(tarball);
      await _deleteIfPresent(staging);
    }
  }

  @override
  Future<void> remove(String packId) async {
    final root = await storage.rootPath();
    await _deleteIfPresent(Directory(p.join(root, packId)));
  }

  @override
  Future<Set<String>> installedPackIds() async {
    final root = Directory(await storage.rootPath());
    if (!await root.exists()) return {};
    final ids = <String>{};
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final marker = File(p.join(entry.path, _markerFile));
      if (await marker.exists()) {
        ids.add(await marker.readAsString());
      }
    }
    return ids;
  }

  @override
  Future<int> installedBytes() async {
    final root = Directory(await storage.rootPath());
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final entry in root.list(recursive: true)) {
      if (entry is File) {
        total += await entry.length();
      }
    }
    return total;
  }

  /// Archives usually wrap their contents in one top-level folder. Both
  /// supported packs do, but an archive that does not is still handled.
  Future<Directory> _resolvePackRoot(Directory staging) async {
    final entries = await staging.list().toList();
    if (entries.length == 1 && entries.single is Directory) {
      return entries.single as Directory;
    }
    return staging;
  }

  static Future<void> _deleteIfPresent(FileSystemEntity entity) async {
    if (await entity.exists()) {
      await entity.delete(recursive: true);
    }
  }
}

/// Runs on a background isolate: bzip2 to a tar file, then tar to disk.
///
/// Written as a top-level function so it can be sent to an isolate.
void _unpack({
  required String downloadPath,
  required String tarballPath,
  required String stagingPath,
}) {
  final compressed = InputFileStream(downloadPath);
  final expanded = OutputFileStream(tarballPath);
  try {
    BZip2Decoder().decodeStream(compressed, expanded, verify: true);
  } finally {
    expanded.closeSync();
    compressed.closeSync();
  }

  final tar = InputFileStream(tarballPath);
  try {
    final archive = TarDecoder().decodeStream(tar, verify: true);
    extractArchiveToDiskSync(archive, stagingPath, throwOnError: true);
  } finally {
    tar.closeSync();
  }
}
