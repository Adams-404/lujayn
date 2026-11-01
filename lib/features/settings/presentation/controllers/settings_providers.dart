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
