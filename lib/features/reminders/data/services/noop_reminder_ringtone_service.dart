import '../../domain/services/reminder_ringtone_service.dart';

/// Used on platforms without a ringing implementation, and in tests.
class NoopReminderRingtoneService implements ReminderRingtoneService {
  const NoopReminderRingtoneService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> startRinging(String reminderId) async {}

  @override
  Future<void> stopRinging() async {}

  @override
  Future<List<RingtoneOption>> availableRingtones() async => const [];

  @override
  Future<String?> selectedRingtoneId() async => null;

  @override
  Future<void> selectRingtone(String? id) async {}

  @override
  Future<void> previewRingtone(String? id) async {}

  @override
  Future<void> stopPreview() async {}
}
