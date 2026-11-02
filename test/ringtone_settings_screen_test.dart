import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/reminders/domain/services/reminder_ringtone_service.dart';
import 'package:lujayn/features/reminders/presentation/controllers/reminder_providers.dart';
import 'package:lujayn/features/reminders/presentation/screens/ringtone_settings_screen.dart';

void main() {
  late _FakeRingtone ringtone;

  setUp(() {
    ringtone = _FakeRingtone();
  });

  Widget wrap() {
    return ProviderScope(
      overrides: [reminderRingtoneServiceProvider.overrideWithValue(ringtone)],
      child: const MaterialApp(home: RingtoneSettingsScreen()),
    );
  }

  testWidgets('lists the phone default and every ringtone on the device', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Phone default'), findsOneWidget);
    expect(find.text('Morning bells'), findsOneWidget);
    expect(find.text('Quiet chime'), findsOneWidget);
  });

  testWidgets('a ringtone can be heard before it is chosen', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Preview Morning bells'));
    await tester.pumpAndSettle();

    expect(ringtone.previewed, ['content://ringtone/morning']);
    expect(ringtone.selected, isNull);
  });

  testWidgets('choosing a ringtone is saved', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quiet chime'));
    await tester.pumpAndSettle();

    expect(ringtone.selected, 'content://ringtone/quiet');
  });

  testWidgets('explains when the device offers no ringtones', (tester) async {
    ringtone.available = false;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Ringtones aren’t available'), findsOneWidget);
  });
}

class _FakeRingtone implements ReminderRingtoneService {
  bool available = true;
  String? selected;
  final List<String?> previewed = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> startRinging(String reminderId) async {}

  @override
  Future<void> stopRinging() async {}

  @override
  Future<List<RingtoneOption>> availableRingtones() async => const [
    RingtoneOption(id: 'content://ringtone/morning', title: 'Morning bells'),
    RingtoneOption(
      id: 'content://ringtone/quiet',
      title: 'Quiet chime',
      isDefault: true,
    ),
  ];

  @override
  Future<String?> selectedRingtoneId() async => selected;

  @override
  Future<void> selectRingtone(String? id) async => selected = id;

  @override
  Future<void> previewRingtone(String? id) async => previewed.add(id);

  @override
  Future<void> stopPreview() async {}
}
