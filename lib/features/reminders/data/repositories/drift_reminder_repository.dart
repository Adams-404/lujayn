import '../../domain/models/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';

/// Drift SQLite implementation of [ReminderRepository].
///
/// Designed to connect the generated Drift database tables with the domain layer
/// starting in Phase 1 (Functional reminder foundation).
///
/// Implements identical interface as [MockReminderRepository] ensuring zero UI rewrites.
class DriftReminderRepository implements ReminderRepository {
  DriftReminderRepository();

  @override
  Stream<List<Reminder>> watchReminders() {
    throw UnimplementedError(
      'DriftReminderRepository will be wired up with generated Drift database in Phase 1.',
    );
  }

  @override
  Future<List<Reminder>> getReminders() {
    throw UnimplementedError(
      'DriftReminderRepository will be wired up with generated Drift database in Phase 1.',
    );
  }

  @override
  Future<Reminder?> getReminderById(String id) {
    throw UnimplementedError(
      'DriftReminderRepository will be wired up with generated Drift database in Phase 1.',
    );
  }

  @override
  Future<void> saveReminder(Reminder reminder) {
    throw UnimplementedError(
      'DriftReminderRepository will be wired up with generated Drift database in Phase 1.',
    );
  }

  @override
  Future<void> deleteReminder(String id) {
    throw UnimplementedError(
      'DriftReminderRepository will be wired up with generated Drift database in Phase 1.',
    );
  }

  @override
  Future<void> toggleReminderStatus(String id) {
    throw UnimplementedError(
      'DriftReminderRepository will be wired up with generated Drift database in Phase 1.',
    );
  }

  @override
  Future<void> resetToSampleData() {
    throw UnimplementedError(
      'DriftReminderRepository will be wired up with generated Drift database in Phase 1.',
    );
  }

  @override
  Future<void> clearAllReminders() {
    throw UnimplementedError(
      'DriftReminderRepository will be wired up with generated Drift database in Phase 1.',
    );
  }
}
