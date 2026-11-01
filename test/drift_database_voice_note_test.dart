import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/core/database/app_database.dart';
import 'package:lujayn/features/reminders/data/repositories/drift_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';

void main() {
  late AppDatabase db;
  late DriftReminderRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftReminderRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'persists and retrieves reminders with voice note path and duration',
    () async {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 'voice-rem-1',
        title: 'Medication reminder',
        description: 'Take 2 pills with water',
        scheduledDateTime: now.add(const Duration(hours: 1)),
        recurrence: RecurrenceRule.none,
        status: ReminderStatus.active,
        voiceNotePath: 'voice_note_123.m4a',
        voiceNoteDuration: const Duration(seconds: 14),
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveReminder(reminder);

      final fetched = await repository.getReminderById(reminder.id);
      expect(fetched, isNotNull);
      expect(fetched!.voiceNotePath, 'voice_note_123.m4a');
      expect(fetched.voiceNoteDuration, const Duration(seconds: 14));
      expect(fetched.hasVoiceNote, isTrue);
    },
  );

  test('clearing a voice note updates the stored reminder', () async {
    final now = DateTime.now();
    final reminder = Reminder(
      id: 'voice-rem-2',
      title: 'Water plants',
      scheduledDateTime: now.add(const Duration(hours: 2)),
      voiceNotePath: 'voice_note_456.m4a',
      voiceNoteDuration: const Duration(seconds: 8),
      createdAt: now,
      updatedAt: now,
    );

    await repository.saveReminder(reminder);

    final cleared = reminder.copyWith(clearVoiceNote: true);
    await repository.saveReminder(cleared);

    final fetched = await repository.getReminderById(reminder.id);
    expect(fetched!.voiceNotePath, isNull);
    expect(fetched.voiceNoteDuration, isNull);
    expect(fetched.hasVoiceNote, isFalse);
  });
}
