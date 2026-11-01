import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/repositories/drift_reminder_repository.dart';
import '../../data/services/android_reminder_alarm_scheduler.dart';
import '../../data/services/android_reminder_call_bridge.dart';
import '../../data/services/app_support_caller_image_service.dart';
import '../../data/services/app_support_voice_note_storage.dart';
import '../../data/services/audioplayers_voice_playback_service.dart';
import '../../data/services/flutter_reminder_speech_service.dart';
import '../../data/services/noop_caller_image_service.dart';
import '../../data/services/noop_reminder_alarm_scheduler.dart';
import '../../data/services/noop_reminder_call_bridge.dart';
import '../../data/services/noop_reminder_speech_service.dart';
import '../../data/services/noop_voice_note_storage_service.dart';
import '../../data/services/noop_voice_playback_service.dart';
import '../../data/services/noop_voice_recording_service.dart';
import '../../data/services/record_voice_recording_service.dart';
import '../../domain/models/recurrence_rule.dart';
import '../../domain/models/reminder.dart';
import '../../domain/models/reminder_alarm_id.dart';
import '../../domain/models/reminder_status.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/services/caller_image_service.dart';
import '../../domain/services/reminder_alarm_scheduler.dart';
import '../../domain/services/reminder_call_bridge.dart';
import '../../domain/services/reminder_schedule_planner.dart';
import '../../domain/services/reminder_speech_service.dart';
import '../../domain/services/voice_note_storage_service.dart';
import '../../domain/services/voice_playback_service.dart';
import '../../domain/services/voice_recording_service.dart';

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

/// Storage for reminder voice recordings.
final voiceNoteStorageServiceProvider = Provider<VoiceNoteStorageService>((
  ref,
) {
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return AppSupportVoiceNoteStorage();
  }
  return const NoopVoiceNoteStorageService();
});

/// Voice recording engine.
final voiceRecordingServiceProvider = Provider<VoiceRecordingService>((ref) {
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return RecordVoiceRecordingService();
  }
  return const NoopVoiceRecordingService();
});

/// Creates a fresh voice playback instance for audio playback in UI.
final voicePlaybackServiceProvider = Provider.autoDispose<VoicePlaybackService>(
  (ref) {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      final service = AudioplayersVoicePlaybackService();
      ref.onDispose(service.dispose);
      return service;
    }
    final service = NoopVoicePlaybackService();
    ref.onDispose(service.dispose);
    return service;
  },
);

/// On-device speech for reading a reminder aloud.
///
/// Speech is optional and never required to receive a reminder, so targets
/// without an engine fall back to a no-op instead of failing.
final reminderSpeechServiceProvider = Provider<ReminderSpeechService>((ref) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return FlutterReminderSpeechService();
  }
  return const NoopReminderSpeechService();
});

/// Storage and image picking for caller profile photos.
final callerImageServiceProvider = Provider<CallerImageService>((ref) {
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return AppSupportCallerImageService();
  }
  return const NoopCallerImageService();
});

/// Whether the device will actually deliver reminders right now.
///
/// Lujayn never claims an alarm is guaranteed. This reports what Android
/// currently allows so the interface can be honest about degraded delivery
/// instead of silently failing.
class DeliveryReadiness {
  const DeliveryReadiness({
    required this.notifications,
    required this.exactAlarms,
  });

  /// Android is allowed to show reminder notifications.
  final bool notifications;

  /// Android is allowed to deliver at the exact minute the user chose.
  final bool exactAlarms;

  bool get isLimited => !notifications || !exactAlarms;

  /// True when the user will probably not see a reminder at all.
  bool get isBlocked => !notifications;
}

/// Reads the current delivery permissions. Refresh it after the user returns
/// from a system settings screen.
final deliveryReadinessProvider = FutureProvider<DeliveryReadiness>((
  ref,
) async {
  final scheduler = ref.watch(reminderAlarmSchedulerProvider);
  if (defaultTargetPlatform != TargetPlatform.android) {
    return const DeliveryReadiness(notifications: true, exactAlarms: true);
  }
  try {
    final notifications = await scheduler.canPostNotifications();
    final exactAlarms = await scheduler.canScheduleExactAlarms();
    return DeliveryReadiness(
      notifications: notifications,
      exactAlarms: exactAlarms,
    );
  } on Object {
    // Never block the screen on a platform call that cannot answer.
    return const DeliveryReadiness(notifications: true, exactAlarms: true);
  }
});

/// Hand-off of due reminders from the platform to the call-style surface.
final reminderCallBridgeProvider = Provider<ReminderCallBridge>((ref) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidReminderCallBridge();
  }
  return const NoopReminderCallBridge();
});

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
  ReminderActionNotifier(
    this._repository,
    this._scheduler,
    this._planner, [
    VoiceNoteStorageService? voiceNoteStorage,
    CallerImageService? callerImageService,
  ]) : _voiceNoteStorage = voiceNoteStorage,
       _callerImageService = callerImageService;

  final ReminderRepository _repository;
  final ReminderAlarmScheduler _scheduler;
  final ReminderSchedulePlanner _planner;
  final VoiceNoteStorageService? _voiceNoteStorage;
  final CallerImageService? _callerImageService;

  Future<void> createOrUpdateReminder(Reminder reminder) async {
    final existing = await _repository.getReminderById(reminder.id);
    if (existing?.voiceNotePath != null &&
        existing!.voiceNotePath != reminder.voiceNotePath) {
      await _voiceNoteStorage?.deleteRecording(existing.voiceNotePath!);
    }
    if (existing?.callerImagePath != null &&
        existing!.callerImagePath != reminder.callerImagePath) {
      await _callerImageService?.deleteImage(existing.callerImagePath!);
    }
    await _repository.saveReminder(reminder);
    await _syncAlarm(reminder);
  }

  Future<void> toggleStatus(String id) async {
    await _repository.toggleReminderStatus(id);
    final updated = await _repository.getReminderById(id);
    if (updated == null) {
      await _scheduler.cancel(id);
    } else {
      await _syncAlarm(updated);
    }
  }

  /// Re-alerts [id] after [duration] without moving the reminder's own schedule.
  ///
  /// A separate one-off alarm keeps a recurring series anchored to the time the
  /// user chose instead of permanently shifting it by the snooze length.
  Future<void> snooze(
    String id, {
    Duration duration = const Duration(minutes: 10),
  }) async {
    final reminder = await _repository.getReminderById(id);
    if (reminder == null) return;

    await _scheduler.schedule(
      ReminderSchedule(
        reminderId: snoozeAlarmId(id),
        title: reminder.title,
        description: reminder.description,
        recurrence: RecurrenceRule.none,
        scheduledAt: DateTime.now().add(duration),
      ),
    );
  }

  /// Closes a due reminder after the user acts on its alert.
  ///
  /// A one-time reminder becomes completed. A recurring reminder keeps its
  /// series intact and only re-syncs the next alarm.
  Future<void> dismissOccurrence(String id) async {
    await _scheduler.cancel(snoozeAlarmId(id));
    final reminder = await _repository.getReminderById(id);
    if (reminder == null) {
      await _scheduler.cancel(id);
      return;
    }
    if (reminder.recurrence.isRecurring) {
      await _syncAlarm(reminder);
      return;
    }

    final now = DateTime.now();
    await _repository.saveReminder(
      reminder.copyWith(
        status: ReminderStatus.completed,
        completedAt: now,
        updatedAt: now,
      ),
    );
    await _scheduler.cancel(id);
  }

  Future<void> deleteReminder(String id) async {
    final reminder = await _repository.getReminderById(id);
    if (reminder?.voiceNotePath != null) {
      await _voiceNoteStorage?.deleteRecording(reminder!.voiceNotePath!);
    }
    if (reminder?.callerImagePath != null) {
      await _callerImageService?.deleteImage(reminder!.callerImagePath!);
    }
    await _repository.deleteReminder(id);
    await _scheduler.cancel(id);
    await _scheduler.cancel(snoozeAlarmId(id));
  }

  Future<void> clearAll() async {
    await _voiceNoteStorage?.clearAllRecordings();
    await _callerImageService?.clearAllImages();
    await _repository.clearAllReminders();
    await _scheduler.cancelAll();
  }

  Future<void> _syncAlarm(Reminder reminder) async {
    final schedule = _planner.plan(reminder, now: DateTime.now());
    if (schedule == null) {
      await _scheduler.cancel(reminder.id);
      await _scheduler.cancel(snoozeAlarmId(reminder.id));
    } else {
      await _scheduler.schedule(schedule);
    }
  }
}

final reminderActionControllerProvider = Provider<ReminderActionNotifier>((
  ref,
) {
  final repository = ref.watch(reminderRepositoryProvider);
  final scheduler = ref.watch(reminderAlarmSchedulerProvider);
  final planner = ref.watch(reminderSchedulePlannerProvider);
  final storage = ref.watch(voiceNoteStorageServiceProvider);
  final imageService = ref.watch(callerImageServiceProvider);
  return ReminderActionNotifier(
    repository,
    scheduler,
    planner,
    storage,
    imageService,
  );
});
