import 'dart:async';

/// Database architecture interface for Lujayn.
///
/// In Phase 1, Lujayn uses SQLite via Drift.
///
/// Architecture overview:
/// ```
/// +-------------------------------------------------------------+
/// |                      Presentation                           |
/// | (Riverpod Providers -> ReminderListController)              |
/// +-------------------------------------------------------------+
///                                |
///                                v
/// +-------------------------------------------------------------+
/// |                         Domain                              |
/// | (ReminderRepository Interface, Reminder, RecurrenceRule)    |
/// +-------------------------------------------------------------+
///                                |
///                 +--------------+--------------+
///                 |                             |
///                 v                             v
/// +-------------------------------+  +--------------------------+
/// | Phase 0: Mock Repository      |  | Phase 1: Drift SQLite    |
/// | (MockReminderRepository)      |  | (DriftReminderRepository)|
/// +-------------------------------+  +--------------------------+
///                                               |
///                                               v
///                                    +--------------------------+
///                                    | AppDatabase (Drift)      |
///                                    | - reminders_table.dart   |
///                                    | - sqlite3 engine         |
///                                    +--------------------------+
/// ```
///
/// Drift table schema planned for Phase 1:
/// - `id`: TextColumn (UUID primary key)
/// - `title`: TextColumn (max 255 chars, not empty)
/// - `description`: TextColumn (nullable)
/// - `scheduled_timestamp`: DateTimeColumn
/// - `recurrence_type`: IntColumn (enum index)
/// - `recurrence_days`: TextColumn (comma-separated days of week)
/// - `status`: IntColumn (enum index)
/// - `created_at`: DateTimeColumn
/// - `updated_at`: DateTimeColumn
/// - `completed_at`: DateTimeColumn (nullable)
abstract class AppDatabaseContract {
  /// Ensures the database is open and schemas/migrations are up to date.
  Future<void> initialize();

  /// Closes database connection safely.
  Future<void> close();
}
