import 'dart:async';

import '../../domain/services/voice_playback_service.dart';

/// No-op playback service for widget tests and headless platforms.
class NoopVoicePlaybackService implements VoicePlaybackService {
  NoopVoicePlaybackService();

  final StreamController<VoicePlaybackState> _controller =
      StreamController<VoicePlaybackState>.broadcast();
  VoicePlaybackState _state = const VoicePlaybackState();

  @override
  Stream<VoicePlaybackState> get stateStream => _controller.stream;

  @override
  VoicePlaybackState get currentState => _state;

  @override
  Future<void> play(String filePath) async {
    _state = const VoicePlaybackState(
      status: VoicePlaybackStatus.playing,
      position: Duration.zero,
      duration: Duration(seconds: 5),
    );
    _controller.add(_state);
  }

  @override
  Future<void> pause() async {
    _state = _state.copyWith(status: VoicePlaybackStatus.paused);
    _controller.add(_state);
  }

  @override
  Future<void> resume() async {
    _state = _state.copyWith(status: VoicePlaybackStatus.playing);
    _controller.add(_state);
  }

  @override
  Future<void> stop() async {
    _state = const VoicePlaybackState(
      status: VoicePlaybackStatus.stopped,
      position: Duration.zero,
    );
    _controller.add(_state);
  }

  @override
  Future<void> seek(Duration position) async {
    _state = _state.copyWith(position: position);
    _controller.add(_state);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
