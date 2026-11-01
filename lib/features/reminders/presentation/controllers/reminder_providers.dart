import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/repositories/drift_reminder_repository.dart';
import '../../data/services/android_reminder_alarm_scheduler.dart';
import '../../data/services/noop_reminder_alarm_scheduler.dart';
import '../../domain/models/reminder.dart';
import '../../domain/models/reminder_status.dart';
import '../../domain/services/reminder_alarm_scheduler.dart';
import '../../domain/services/reminder_schedule_planner.dart';
import '../../domain/repositories/reminder_repository.dart';

/// Filter selection for reminder list.
enum ReminderFilter { upcoming, completed, all }

/// Shared local SQLite database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Production repository. Mock data is only used by tests.
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return DriftReminderRepository(ref.watch(appDatabaseProvider));
});

/// Platform alarm scheduler. Android uses AlarmManager; other targets
/// keep the reminder data usable without invoking an unavailable channel.
final reminderAlarmSchedulerProvider = Provider<ReminderAlarmScheduler>((ref) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidReminderAlarmScheduler();
  }
  return const NoopReminderAlarmScheduler();
});

/// Pure planner shared by scheduling actions and tests.
final reminderSchedulePlannerProvider = Provider<ReminderSchedulePlanner>(
  (ref) => const ReminderSchedulePlanner(),
);

/// Reactive stream of reminders from the repository.
final remindersStreamProvider = StreamProvider<List<Reminder>>((ref) {
  final repository = ref.watch(reminderRepositoryProvider);
  return repository.watchReminders();
});

/// Modern Riverpod 3 Notifier for reminder filter state.
class ReminderFilterNotifier extends Notifier<ReminderFilter> {
  @override
  ReminderFilter build() => ReminderFilter.upcoming;

  void setFilter(ReminderFilter filter) {
    state = filter;
  }
}

/// Current filter selection on the Home screen.
final reminderFilterProvider =
    NotifierProvider<ReminderFilterNotifier, ReminderFilter>(
      ReminderFilterNotifier.new,
    );

/// Filtered list of reminders according to [reminderFilterProvider].
final filteredRemindersProvider = Provider<AsyncValue<List<Reminder>>>((ref) {
  final filter = ref.watch(reminderFilterProvider);
  final remindersAsync = ref.watch(remindersStreamProvider);

  return remindersAsync.whenData((reminders) {
    switch (filter) {
      case ReminderFilter.upcoming:
        return reminders
            .where((r) => r.status == ReminderStatus.active)
            .toList();
      case ReminderFilter.completed:
        return reminders
            .where((r) => r.status == ReminderStatus.completed)
            .toList();
      case ReminderFilter.all:
        return reminders;
    }
  });
});

/// Active reminders occurring today.
final todayRemindersProvider = Provider<AsyncValue<List<Reminder>>>((ref) {
  final remindersAsync = ref.watch(remindersStreamProvider);

  return remindersAsync.whenData((reminders) {
    return reminders.where((r) => r.isActive && r.isToday).toList();
  });
});

/// Active reminders occurring after today.
final upcomingLaterRemindersProvider = Provider<AsyncValue<List<Reminder>>>((
  ref,
) {
  final remindersAsync = ref.watch(remindersStreamProvider);

  return remindersAsync.whenData((reminders) {
    return reminders.where((r) => r.isActive && !r.isToday).toList();
  });
});

/// Completed reminders.
final completedRemindersProvider = Provider<AsyncValue<List<Reminder>>>((ref) {
  final remindersAsync = ref.watch(remindersStreamProvider);

  return remindersAsync.whenData((reminders) {
    return reminders.where((r) => r.isCompleted).toList();
  });
});

/// Controller handling reminder user mutations.
class ReminderActionNotifier {
  ReminderActionNotifier(this._repository);

  final ReminderRepository _repository;

  Future<void> createOrUpdateReminder(Reminder reminder) async {
    await _repository.saveReminder(reminder);
  }

  Future<void> toggleStatus(String id) async {
    await _repository.toggleReminderStatus(id);
  }

  Future<void> deleteReminder(String id) async {
    await _repository.deleteReminder(id);
  }

  Future<void> clearAll() async {
    await _repository.clearAllReminders();
  }
}

final reminderActionControllerProvider = Provider<ReminderActionNotifier>((
  ref,
) {
  final repository = ref.watch(reminderRepositoryProvider);
  return ReminderActionNotifier(repository);
});
