import 'dart:async';

import 'package:record/record.dart';

import '../../domain/services/voice_recording_service.dart';

/// Concrete [VoiceRecordingService] using the `record` plugin.
///
/// Encodes audio as AAC-LC (.m4a), which has universal Android & iOS hardware
/// acceleration and small storage footprint.
class RecordVoiceRecordingService implements VoiceRecordingService {
  RecordVoiceRecordingService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> startRecording(String targetFilePath) async {
    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 44100,
    );
    await _recorder.start(config, path: targetFilePath);
  }

  @override
  Future<String?> stopRecording() async {
    return await _recorder.stop();
  }

  @override
  Future<void> cancelRecording() async {
    await _recorder.cancel();
  }

  @override
  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
