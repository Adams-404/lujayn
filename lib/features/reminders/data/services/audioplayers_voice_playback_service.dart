import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../../domain/services/voice_playback_service.dart';

/// Concrete [VoicePlaybackService] using the `audioplayers` plugin.
class AudioplayersVoicePlaybackService implements VoicePlaybackService {
  AudioplayersVoicePlaybackService({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _initListeners();
  }

  final AudioPlayer _player;
  final StreamController<VoicePlaybackState> _controller =
      StreamController<VoicePlaybackState>.broadcast();

  VoicePlaybackState _state = const VoicePlaybackState();
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  void _initListeners() {
    _stateSub = _player.onPlayerStateChanged.listen((playerState) {
      final status = switch (playerState) {
        PlayerState.playing => VoicePlaybackStatus.playing,
        PlayerState.paused => VoicePlaybackStatus.paused,
        PlayerState.stopped => VoicePlaybackStatus.stopped,
        PlayerState.completed => VoicePlaybackStatus.completed,
        _ => VoicePlaybackStatus.stopped,
      };
      _emit(_state.copyWith(status: status));
    });

    _positionSub = _player.onPositionChanged.listen((pos) {
      _emit(_state.copyWith(position: pos));
    });

    _durationSub = _player.onDurationChanged.listen((dur) {
      _emit(_state.copyWith(duration: dur));
    });
  }

  void _emit(VoicePlaybackState newState) {
    _state = newState;
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }

  @override
  Stream<VoicePlaybackState> get stateStream => _controller.stream;

  @override
  VoicePlaybackState get currentState => _state;

  @override
  Future<void> play(String filePath) async {
    _emit(
      _state.copyWith(
        status: VoicePlaybackStatus.playing,
        position: Duration.zero,
      ),
    );
    await _player.stop();
    await _player.play(DeviceFileSource(filePath));
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    await _player.resume();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _emit(
      _state.copyWith(
        status: VoicePlaybackStatus.stopped,
        position: Duration.zero,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _player.dispose();
    await _controller.close();
  }
}
