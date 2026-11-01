import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/domain/services/voice_note_storage_service.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';

class _FakeVoiceNoteStorage implements VoiceNoteStorageService {
  final List<String> deleted = [];
  bool cleared = false;

  @override
  Future<void> clearAllRecordings() async {
    cleared = true;
  }

  @override
  Future<int> cleanupOrphanedRecordings(List<String> activeFileNames) async =>
      0;

  @override
  Future<void> deleteRecording(String fileName) async {
    deleted.add(fileName);
  }

  @override
  Future<String> generateNewRecordingPath({String? reminderId}) async =>
      '/mock/path.m4a';

  @override
  Future<String> getRecordingsDirectory() async => '/mock/recordings';

  @override
  Future<String> resolvePath(String fileName) async => '/mock/$fileName';
}

class _FakeAlarmScheduler implements ReminderAlarmScheduler {
  @override
  Future<bool> canPostNotifications() async => true;
  @override
  Future<bool> canScheduleExactAlarms() async => true;
  @override
  Future<bool> requestExactAlarmPermission() async => true;
  @override
  Future<bool> requestNotificationPermission() async => true;
  @override
  Future<void> cancel(String reminderId) async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> schedule(ReminderSchedule schedule) async {}
}

void main() {
  group('ReminderActionNotifier voice note cleanup', () {
    late MockReminderRepository repository;
    late _FakeAlarmScheduler scheduler;
    late _FakeVoiceNoteStorage storage;
    late ReminderActionNotifier notifier;

    setUp(() {
      repository = MockReminderRepository(preloadSampleData: false);
      scheduler = _FakeAlarmScheduler();
      storage = _FakeVoiceNoteStorage();
      notifier = ReminderActionNotifier(
        repository,
        scheduler,
        const ReminderSchedulePlanner(),
        storage,
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test('deleting a reminder removes its voice note file', () async {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 'voice-del-1',
        title: 'Check oven',
        scheduledDateTime: now.add(const Duration(minutes: 30)),
        voiceNotePath: 'oven_check.m4a',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveReminder(reminder);

      await notifier.deleteReminder(reminder.id);

      expect(storage.deleted, contains('oven_check.m4a'));
      expect(await repository.getReminderById(reminder.id), isNull);
    });

    test('replacing a voice note deletes the old recording file', () async {
      final now = DateTime.now();
      final original = Reminder(
        id: 'voice-replace-1',
        title: 'Call Mum',
        scheduledDateTime: now.add(const Duration(hours: 1)),
        voiceNotePath: 'old_recording.m4a',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveReminder(original);

      final updated = original.copyWith(voiceNotePath: 'new_recording.m4a');
      await notifier.createOrUpdateReminder(updated);

      expect(storage.deleted, contains('old_recording.m4a'));
      final fetched = await repository.getReminderById(original.id);
      expect(fetched!.voiceNotePath, 'new_recording.m4a');
    });

    test('clearAll removes all voice note recordings', () async {
      await notifier.clearAll();
      expect(storage.cleared, isTrue);
    });
  });
}
