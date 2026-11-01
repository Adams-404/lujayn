import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/theme/app_theme_choice.dart';

/// Preference boundary keeps the theme controller testable without platform IO.
abstract interface class ThemePreferenceStore {
  Future<String?> readThemeChoice();
  Future<void> writeThemeChoice(String value);
}

class SharedPreferencesThemePreferenceStore implements ThemePreferenceStore {
  SharedPreferencesThemePreferenceStore()
    : _preferences = SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  static const _key = 'lujayn.theme.choice';

  @override
  Future<String?> readThemeChoice() => _preferences.getString(_key);

  @override
  Future<void> writeThemeChoice(String value) =>
      _preferences.setString(_key, value);
}

final themePreferenceStoreProvider = Provider<ThemePreferenceStore>((ref) {
  return SharedPreferencesThemePreferenceStore();
});

class ThemeChoiceNotifier extends AsyncNotifier<AppThemeChoice> {
  late ThemePreferenceStore _store;

  @override
  Future<AppThemeChoice> build() async {
    _store = ref.watch(themePreferenceStoreProvider);
    final stored = await _store.readThemeChoice();
    return AppThemeChoice.values.firstWhere(
      (choice) => choice.name == stored,
      orElse: () => AppThemeChoice.system,
    );
  }

  Future<void> select(AppThemeChoice choice) async {
    await _store.writeThemeChoice(choice.name);
    state = AsyncData(choice);
  }
}

final themeChoiceProvider =
    AsyncNotifierProvider<ThemeChoiceNotifier, AppThemeChoice>(
      ThemeChoiceNotifier.new,
    );

/// Preference boundary for reading reminders aloud.
abstract interface class SpeechPreferenceStore {
  Future<bool?> readSpokenRemindersEnabled();
  Future<void> writeSpokenRemindersEnabled(bool value);
}

class SharedPreferencesSpeechPreferenceStore implements SpeechPreferenceStore {
  SharedPreferencesSpeechPreferenceStore()
    : _preferences = SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  static const _key = 'lujayn.speech.spoken_reminders';

  @override
  Future<bool?> readSpokenRemindersEnabled() => _preferences.getBool(_key);

  @override
  Future<void> writeSpokenRemindersEnabled(bool value) =>
      _preferences.setBool(_key, value);
}

final speechPreferenceStoreProvider = Provider<SpeechPreferenceStore>((ref) {
  return SharedPreferencesSpeechPreferenceStore();
});

/// Whether a due reminder is read aloud automatically.
///
/// Defaults to off. A reminder can arrive in a meeting, on a bus, or beside a
/// sleeping child, so speaking without being asked is the wrong default even
/// though it is the more accessible one. The call screen still offers a manual
/// "Read aloud" control when speech is available.
class SpokenRemindersNotifier extends AsyncNotifier<bool> {
  late SpeechPreferenceStore _store;

  @override
  Future<bool> build() async {
    _store = ref.watch(speechPreferenceStoreProvider);
    return await _store.readSpokenRemindersEnabled() ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    await _store.writeSpokenRemindersEnabled(enabled);
    state = AsyncData(enabled);
  }
}

final spokenRemindersEnabledProvider =
    AsyncNotifierProvider<SpokenRemindersNotifier, bool>(
      SpokenRemindersNotifier.new,
    );
