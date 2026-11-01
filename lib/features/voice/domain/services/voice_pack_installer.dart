import '../models/voice_install_progress.dart';
import '../models/voice_pack.dart';

/// Installs and removes on-device voice packs.
///
/// Installing is a long, resumable-in-principle operation, so it reports
/// progress as a stream instead of a single future. An implementation must
/// never leave a half-installed pack behind: either the pack is complete and
/// usable, or it is absent.
abstract interface class VoicePackInstaller {
  /// Downloads, verifies and unpacks [pack].
  ///
  /// The stream ends after a `done` or `failed` event. Cancelling the
  /// subscription abandons the install and cleans up.
  Stream<VoiceInstallProgress> install(VoicePack pack);

  /// Deletes an installed pack and everything it occupies on disk.
  Future<void> remove(String packId);

  /// Which packs are completely installed and ready to speak.
  Future<Set<String>> installedPackIds();

  /// Total bytes the installed packs occupy, for the settings summary.
  Future<int> installedBytes();
}

/// Where installed packs live.
///
/// Abstracted so tests can point at a temporary directory instead of the
/// device's application support directory.
abstract interface class VoiceStorage {
  /// Directory that contains one subdirectory per installed pack.
  Future<String> rootPath();
}
