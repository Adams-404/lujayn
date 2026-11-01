import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/settings/presentation/controllers/settings_providers.dart';
import 'package:lujayn/features/settings/presentation/screens/settings_screen.dart';

void main() {
  Widget wrap() {
    return ProviderScope(
      overrides: [
        themePreferenceStoreProvider.overrideWithValue(_MemoryThemeStore()),
        speechPreferenceStoreProvider.overrideWithValue(_MemorySpeechStore()),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  testWidgets('offers a voice picker and the read-aloud switch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final voiceRow = find.widgetWithText(ListTile, 'Reminder voice');
    expect(voiceRow, findsOneWidget);
    expect(tester.widget<ListTile>(voiceRow).onTap, isNotNull);

    expect(find.text('Read reminders aloud'), findsOneWidget);
  });

  testWidgets('the read-aloud switch is off until the user asks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Read reminders aloud'),
    );
    expect(tile.value, isFalse);
  });

  testWidgets('turning on read-aloud is saved', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = _MemorySpeechStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themePreferenceStoreProvider.overrideWithValue(_MemoryThemeStore()),
          speechPreferenceStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read reminders aloud'));
    await tester.pumpAndSettle();

    expect(store.enabled, isTrue);
  });
}

class _MemoryThemeStore implements ThemePreferenceStore {
  String? value;

  @override
  Future<String?> readThemeChoice() async => value;

  @override
  Future<void> writeThemeChoice(String value) async {
    this.value = value;
  }
}

class _MemorySpeechStore implements SpeechPreferenceStore {
  bool? enabled;

  @override
  Future<bool?> readSpokenRemindersEnabled() async => enabled;

  @override
  Future<void> writeSpokenRemindersEnabled(bool value) async {
    enabled = value;
  }
}
