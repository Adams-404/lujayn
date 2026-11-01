import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/theme/app_theme.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/features/reminders/data/services/noop_voice_playback_service.dart';
import 'package:lujayn/features/reminders/data/services/noop_voice_recording_service.dart';
import 'package:lujayn/features/reminders/domain/services/voice_note_storage_service.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/reminders/presentation/widgets/voice_note_player_widget.dart';
import 'package:lujayn/features/reminders/presentation/widgets/voice_note_recorder_control.dart';

class _MockStorage implements VoiceNoteStorageService {
  @override
  Future<void> clearAllRecordings() async {}
  @override
  Future<int> cleanupOrphanedRecordings(List<String> activeFileNames) async =>
      0;
  @override
  Future<void> deleteRecording(String fileName) async {}
  @override
  Future<String> generateNewRecordingPath({String? reminderId}) async =>
      '/mock/path.m4a';
  @override
  Future<String> getRecordingsDirectory() async => '/mock/recordings';
  @override
  Future<String> resolvePath(String fileName) async => '/mock/$fileName';
}

void main() {
  testWidgets(
    'renders idle state with Add voice recording when no initial note',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceNoteStorageServiceProvider.overrideWithValue(_MockStorage()),
            voiceRecordingServiceProvider.overrideWithValue(
              const NoopVoiceRecordingService(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.forChoice(AppThemeChoice.silver),
            home: Scaffold(
              body: VoiceNoteRecorderControl(
                initialVoiceNotePath: null,
                initialDuration: null,
                onChanged: (p, d) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add voice recording'), findsOneWidget);
    },
  );

  testWidgets('renders player when initial voice note exists', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceNoteStorageServiceProvider.overrideWithValue(_MockStorage()),
          voicePlaybackServiceProvider.overrideWithValue(
            NoopVoicePlaybackService(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.forChoice(AppThemeChoice.silver),
          home: Scaffold(
            body: VoiceNoteRecorderControl(
              initialVoiceNotePath: 'existing.m4a',
              initialDuration: const Duration(seconds: 12),
              onChanged: (p, d) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VoiceNotePlayerWidget), findsOneWidget);
    expect(find.text('0:12'), findsOneWidget);
  });
}
