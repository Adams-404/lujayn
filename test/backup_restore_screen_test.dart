import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/app/theme/app_theme.dart';
import 'package:lujayn/app/theme/app_theme_choice.dart';
import 'package:lujayn/features/backup/data/services/aes_backup_vault_service.dart';
import 'package:lujayn/features/backup/domain/services/backup_vault_service.dart';
import 'package:lujayn/features/backup/presentation/controllers/backup_providers.dart';
import 'package:lujayn/features/backup/presentation/screens/backup_restore_screen.dart';
import 'package:lujayn/features/reminders/data/repositories/mock_reminder_repository.dart';
import 'package:lujayn/features/reminders/domain/models/recurrence_rule.dart';
import 'package:lujayn/features/reminders/domain/models/reminder.dart';
import 'package:lujayn/features/reminders/domain/models/reminder_status.dart';
import 'package:lujayn/features/reminders/domain/services/caller_image_service.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_alarm_scheduler.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_schedule_planner.dart';
import 'package:lujayn/features/reminders/domain/services/voice_note_storage_service.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:path/path.dart' as p;

class _TestVoiceNoteStorage implements VoiceNoteStorageService {
  _TestVoiceNoteStorage(this.baseDir);
  final Directory baseDir;

  @override
  Future<String> getRecordingsDirectory() async {
    final dir = Directory(p.join(baseDir.path, 'recordings'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  @override
  Future<String> resolvePath(String fileName) async {
    final dir = await getRecordingsDirectory();
    return p.join(dir, p.basename(fileName));
  }

  @override
  Future<String> generateNewRecordingPath({String? reminderId}) async {
    final dir = await getRecordingsDirectory();
    return p.join(dir, 'rec_$reminderId.m4a');
  }

  @override
  Future<void> deleteRecording(String fileName) async {}
  @override
  Future<void> clearAllRecordings() async {}
  @override
  Future<int> cleanupOrphanedRecordings(List<String> activeFileNames) async =>
      0;
}

class _TestCallerImageService implements CallerImageService {
  _TestCallerImageService(this.baseDir);
  final Directory baseDir;

  Future<String> getImagesDirectory() async {
    final dir = Directory(p.join(baseDir.path, 'caller_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  @override
  Future<String> resolvePath(String fileNameOrPath) async {
    if (p.isAbsolute(fileNameOrPath)) return fileNameOrPath;
    final dir = await getImagesDirectory();
    return p.join(dir, p.basename(fileNameOrPath));
  }

  @override
  Future<void> deleteImage(String fileNameOrPath) async {}

  @override
  Future<void> clearAllImages() async {}

  @override
  Future<String?> pickAndStoreImage() async => null;
}

class _TestAlarmScheduler implements ReminderAlarmScheduler {
  @override
  Future<bool> canPostNotifications() async => true;
  @override
  Future<bool> canScheduleExactAlarms() async => true;
  @override
  Future<bool> requestExactAlarmPermission() async => true;
  @override
  Future<bool> requestNotificationPermission() async => true;
  @override
  Future<void> schedule(ReminderSchedule schedule) async {}
  @override
  Future<void> cancel(String reminderId) async {}
  @override
  Future<void> cancelAll() async {}
}

void main() {
  late Directory tempDir;
  late MockReminderRepository repository;
  late _TestVoiceNoteStorage voiceStorage;
  late _TestCallerImageService callerImageService;
  late _TestAlarmScheduler alarmScheduler;
  late BackupVaultService vault;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_screen_test_');
    repository = MockReminderRepository(preloadSampleData: false);
    voiceStorage = _TestVoiceNoteStorage(tempDir);
    callerImageService = _TestCallerImageService(tempDir);
    alarmScheduler = _TestAlarmScheduler();

    vault = AesBackupVaultService(
      reminderRepository: repository,
      voiceNoteStorage: voiceStorage,
      callerImageService: callerImageService,
      alarmScheduler: alarmScheduler,
      baseDirectoryResolver: () async => tempDir,
      pbkdf2Iterations: 1000,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget createSubject({
    AppThemeChoice themeChoice = AppThemeChoice.system,
    double textScaleFactor = 1.0,
    List<String> availableBackups = const [],
  }) {
    return ProviderScope(
      overrides: [
        backupVaultServiceProvider.overrideWithValue(vault),
        availableBackupsProvider.overrideWith(
          (ref) => Future.value(availableBackups),
        ),
        reminderRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.forChoice(themeChoice),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScaleFactor),
            size: const Size(400, 900),
          ),
          child: const BackupRestoreScreen(),
        ),
      ),
    );
  }

  testWidgets('renders create backup tab with inputs and button', (
    tester,
  ) async {
    await repository.saveReminder(
      Reminder(
        id: 'r1',
        title: 'Call Doctor',
        scheduledDateTime: DateTime.now().add(const Duration(hours: 1)),
        recurrence: RecurrenceRule.none,
        status: ReminderStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('Encrypted Backup & Restore'), findsOneWidget);
    expect(find.text('100% Local & Encrypted'), findsOneWidget);
    expect(find.text('Create Backup'), findsOneWidget);
    expect(find.text('Restore Backup'), findsOneWidget);
    expect(find.text('Content to be backed up'), findsOneWidget);
    expect(find.text('1 reminders'), findsOneWidget);
    expect(find.text('Create Encrypted Backup'), findsOneWidget);
  });

  testWidgets('switches between Create Backup and Restore Backup tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore Backup'));
    await tester.pumpAndSettle();

    expect(find.text('Select Backup File'), findsOneWidget);
    expect(find.text('Backup Passphrase'), findsOneWidget);

    await tester.tap(find.text('Create Backup'));
    await tester.pumpAndSettle();

    expect(find.text('Content to be backed up'), findsOneWidget);
  });

  testWidgets('creates encrypted backup successfully through UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await repository.saveReminder(
      Reminder(
        id: 'r1',
        title: 'Meeting at 3',
        scheduledDateTime: DateTime.now().add(const Duration(hours: 3)),
        recurrence: RecurrenceRule.none,
        status: ReminderStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BackupRestoreScreen)),
    );
    await tester.runAsync(() async {
      await container
          .read(backupControllerProvider.notifier)
          .createBackup('strongpassword123');
    });
    await tester.pumpAndSettle();

    expect(find.text('Backup Created Successfully'), findsOneWidget);
    expect(find.text('Copy Path'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('renders without overflow at 200% text scale', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(createSubject(textScaleFactor: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  for (final choice in AppThemeChoice.values) {
    testWidgets('renders across theme ${choice.name} without error', (
      tester,
    ) async {
      await tester.pumpWidget(createSubject(themeChoice: choice));
      await tester.pumpAndSettle();

      expect(find.text('Encrypted Backup & Restore'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
