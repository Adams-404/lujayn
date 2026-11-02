/// One ringtone the user can choose for reminder calls.
class RingtoneOption {
  const RingtoneOption({
    required this.id,
    required this.title,
    this.isDefault = false,
  });

  /// Stable id. Android uses the content URI string, `default` for the phone's
  /// current default ringtone, and `silent` for no sound.
  final String id;

  /// The name Android shows for this tone.
  final String title;

  /// Whether this is the phone's current default ringtone.
  final bool isDefault;
}

/// Controls how a due reminder rings.
///
/// Ringing is the difference between "a notification I can ignore" and "a call
/// I have to answer". It must therefore start when the alarm fires even if the
/// app is closed, stop the moment the call is answered, declined or hung up,
/// and never keep a phone ringing in someone's pocket.
abstract interface class ReminderRingtoneService {
  /// Whether this platform can ring a reminder call.
  Future<bool> isAvailable();

  /// Starts ringing for [reminderId]. Safe to call when already ringing.
  Future<void> startRinging(String reminderId);

  /// Stops ringing and releases the audio route. Safe when nothing is ringing.
  Future<void> stopRinging();

  /// The ringtones available on this device, with the current default first.
  Future<List<RingtoneOption>> availableRingtones();

  /// The saved choice, or null when the phone's default is used.
  Future<String?> selectedRingtoneId();

  /// Saves the choice. Passing null restores the phone's default ringtone.
  Future<void> selectRingtone(String? id);

  /// Plays a short sample of [id] so the choice is not blind.
  Future<void> previewRingtone(String? id);

  /// Stops a sample started by [previewRingtone].
  Future<void> stopPreview();
}
