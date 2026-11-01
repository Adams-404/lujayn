/// Where an install currently is.
///
/// The stages are deliberately distinct because the wait is long: a 100 MB
/// download, then a checksum pass, then extraction. Collapsing them into one
/// spinner would leave the user unable to tell a slow download from a stuck
/// app.
enum VoiceInstallStage { downloading, verifying, extracting, done, failed }

/// A single observation from an install in progress.
class VoiceInstallProgress {
  const VoiceInstallProgress({
    required this.stage,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.message,
  });

  const VoiceInstallProgress.failed(String this.message)
    : stage = VoiceInstallStage.failed,
      receivedBytes = 0,
      totalBytes = 0;

  final VoiceInstallStage stage;
  final int receivedBytes;
  final int totalBytes;

  /// Only set for [VoiceInstallStage.failed], and written for the user rather
  /// than for a log.
  final String? message;

  bool get isFinished => stage == VoiceInstallStage.done;

  bool get isFailed => stage == VoiceInstallStage.failed;

  /// 0..1 while downloading, null when the total is unknown.
  double? get fraction {
    if (totalBytes <= 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get stageLabel => switch (stage) {
    VoiceInstallStage.downloading => 'Downloading',
    VoiceInstallStage.verifying => 'Checking the download',
    VoiceInstallStage.extracting => 'Unpacking',
    VoiceInstallStage.done => 'Ready',
    VoiceInstallStage.failed => 'Could not install',
  };
}
