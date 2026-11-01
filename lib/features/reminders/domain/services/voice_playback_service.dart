import 'dart:async';

/// Playback state for a reminder voice note.
enum VoicePlaybackStatus { stopped, playing, paused, completed }

/// Immutable snapshot of voice playback progress.
class VoicePlaybackState {
  const VoicePlaybackState({
    this.status = VoicePlaybackStatus.stopped,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final VoicePlaybackStatus status;
  final Duration position;
  final Duration duration;

  bool get isPlaying => status == VoicePlaybackStatus.playing;
  bool get isPaused => status == VoicePlaybackStatus.paused;
  bool get isStopped =>
      status == VoicePlaybackStatus.stopped ||
      status == VoicePlaybackStatus.completed;

  double get progressFraction {
    if (duration.inMilliseconds <= 0) return 0.0;
    final frac = position.inMilliseconds / duration.inMilliseconds;
    return frac.clamp(0.0, 1.0);
  }

  VoicePlaybackState copyWith({
    VoicePlaybackStatus? status,
    Duration? position,
    Duration? duration,
  }) {
    return VoicePlaybackState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoicePlaybackState &&
          status == other.status &&
          position == other.position &&
          duration == other.duration;

  @override
  int get hashCode => status.hashCode ^ position.hashCode ^ duration.hashCode;
}

/// Abstract contract for playing local voice notes.
abstract class VoicePlaybackService {
  /// Stream emitting real-time playback state updates.
  Stream<VoicePlaybackState> get stateStream;

  /// The current state snapshot.
  VoicePlaybackState get currentState;

  /// Plays the audio file at [filePath].
  Future<void> play(String filePath);

  /// Pauses active playback.
  Future<void> pause();

  /// Resumes playback from the paused position.
  Future<void> resume();

  /// Stops playback and resets position to zero.
  Future<void> stop();

  /// Seeks to a specific [position] within the audio.
  Future<void> seek(Duration position);

  /// Releases audio resources.
  Future<void> dispose();
}
