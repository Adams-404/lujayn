import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/core/database/app_database.dart';
import 'package:lujayn/features/reminders/data/repositories/drift_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';

void main() {
  late AppDatabase database;
  late DriftReminderRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftReminderRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('persists and retrieves caller persona metadata', () async {
    final now = DateTime.now();
    final reminder = Reminder(
      id: 'persona_1',
      title: 'Take blood pressure pills',
      description: 'With a full glass of water',
      scheduledDateTime: now.add(const Duration(hours: 1)),
      recurrence: RecurrenceRule.none,
      status: ReminderStatus.active,
      callerName: 'Dr. Collins',
      callerNumber: 'Clinic • (555) 234-5678',
      callerIcon: 'medical',
      callerImagePath: 'caller_profile_photo.jpg',
      createdAt: now,
      updatedAt: now,
    );

    await repository.saveReminder(reminder);
    final fetched = await repository.getReminderById('persona_1');

    expect(fetched, isNotNull);
    expect(fetched!.callerName, 'Dr. Collins');
    expect(fetched.callerNumber, 'Clinic • (555) 234-5678');
    expect(fetched.callerIcon, 'medical');
    expect(fetched.callerImagePath, 'caller_profile_photo.jpg');
    expect(fetched.hasCallerPersona, isTrue);
  });

  test('updates and clears caller persona on a reminder', () async {
    final now = DateTime.now();
    final reminder = Reminder(
      id: 'persona_2',
      title: 'Call Grandma',
      scheduledDateTime: now.add(const Duration(hours: 2)),
      callerName: 'Mom ❤️',
      callerNumber: 'Mobile',
      callerIcon: 'family',
      callerImagePath: 'caller_mom.jpg',
      createdAt: now,
      updatedAt: now,
    );

    await repository.saveReminder(reminder);

    final updated = reminder.copyWith(clearCallerPersona: true);
    await repository.saveReminder(updated);

    final fetched = await repository.getReminderById('persona_2');
    expect(fetched, isNotNull);
    expect(fetched!.callerName, isNull);
    expect(fetched.callerNumber, isNull);
    expect(fetched.callerIcon, isNull);
    expect(fetched.callerImagePath, isNull);
    expect(fetched.hasCallerPersona, isFalse);
  });
}
