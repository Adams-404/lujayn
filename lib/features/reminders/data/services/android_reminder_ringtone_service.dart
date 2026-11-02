import 'package:flutter/services.dart';

import '../../domain/services/reminder_ringtone_service.dart';

/// Android ringing through the native foreground service.
///
/// The service is what makes a reminder ring while the app is closed. This
/// bridge only asks it to start, stop and preview; the audio and the call
/// notification live in Kotlin so they survive the Flutter engine sleeping.
class AndroidReminderRingtoneService implements ReminderRingtoneService {
  AndroidReminderRingtoneService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.lujayn/reminder_ringtone');

  final MethodChannel _channel;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> startRinging(String reminderId) async {
    try {
      await _channel.invokeMethod<void>('startRinging', {
        'reminderId': reminderId,
      });
    } on PlatformException {
      // The notification still appears; only the sound is missing.
    } on MissingPluginException {
      // Expected in tests and non-Android builds.
    }
  }

  @override
  Future<void> stopRinging() async {
    try {
      await _channel.invokeMethod<void>('stopRinging');
    } on PlatformException {
      // Nothing left to stop.
    } on MissingPluginException {
      // Expected in tests and non-Android builds.
    }
  }

  @override
  Future<List<RingtoneOption>> availableRingtones() async {
    try {
      final raw = await _channel.invokeListMethod<Object?>('listRingtones');
      if (raw == null) return const [];
      return [
        for (final entry in raw)
          if (entry is Map)
            RingtoneOption(
              id: entry['id'] as String? ?? '',
              title: entry['title'] as String? ?? 'Ringtone',
              isDefault: entry['isDefault'] == true,
            ),
      ].where((option) => option.id.isNotEmpty).toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<String?> selectedRingtoneId() async {
    try {
      final id = await _channel.invokeMethod<String>('getSelectedRingtone');
      return (id == null || id.isEmpty) ? null : id;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> selectRingtone(String? id) async {
    try {
      await _channel.invokeMethod<void>('setSelectedRingtone', {'id': id});
    } on PlatformException {
      // The choice stays unset; the default ringtone is still used.
    } on MissingPluginException {
      // Expected in tests and non-Android builds.
    }
  }

  @override
  Future<void> previewRingtone(String? id) async {
    try {
      await _channel.invokeMethod<void>('previewRingtone', {'id': id});
    } on PlatformException {
      // A preview failure must not break the settings screen.
    } on MissingPluginException {
      // Expected in tests and non-Android builds.
    }
  }

  @override
  Future<void> stopPreview() async {
    try {
      await _channel.invokeMethod<void>('stopPreview');
    } on PlatformException {
      // Nothing left to stop.
    } on MissingPluginException {
      // Expected in tests and non-Android builds.
    }
  }
}
