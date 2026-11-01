import '../models/reminder.dart';

/// Abstract contract for reminder persistence.
///
/// Implementations include the production Drift SQLite repository and an
/// in-memory mock used by tests.
abstract class ReminderRepository {
  /// Continuously streams the list of reminders ordered by scheduled time.
  Stream<List<Reminder>> watchReminders();

  /// Fetches a snapshot of all reminders.
  Future<List<Reminder>> getReminders();

  /// Finds a specific reminder by its ID.
  Future<Reminder?> getReminderById(String id);

  /// Creates a new reminder or updates an existing one.
  Future<void> saveReminder(Reminder reminder);

  /// Permanently removes a reminder.
  Future<void> deleteReminder(String id);

  /// Toggles between active and completed status.
  Future<void> toggleReminderStatus(String id);

  /// Resets the repository to default curated sample data.
  Future<void> resetToSampleData();

  /// Clears all reminders from the repository.
  Future<void> clearAllReminders();
}
