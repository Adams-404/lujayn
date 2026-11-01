import 'package:flutter_test/flutter_test.dart';
import 'package:lujayn/features/voice/data/voice_catalog.dart';
import 'package:lujayn/features/voice/domain/models/voice_pack.dart';
import 'package:lujayn/features/voice/domain/models/voice_selection.dart';

void main() {
  group('voice catalog', () {
    test('offers at least five voices, female and male', () {
      final voices = VoiceCatalog.allVoices;

      expect(voices.length, greaterThanOrEqualTo(5));
      expect(
        voices.where((voice) => voice.gender == VoiceGender.female),
        isNotEmpty,
      );
      expect(
        voices.where((voice) => voice.gender == VoiceGender.male),
        isNotEmpty,
      );
    });

    test('every pack fits inside the agreed size budget', () {
      for (final pack in VoiceCatalog.packs) {
        expect(
          pack.downloadBytes,
          lessThanOrEqualTo(VoicePack.maxPackBytes),
          reason: '${pack.id} download is too large to install on a phone',
        );
        expect(
          pack.installedBytes,
          lessThanOrEqualTo(VoicePack.maxPackBytes),
          reason: '${pack.id} needs too much storage once unpacked',
        );
        expect(pack.downloadBytes, greaterThan(0));
      }
    });

    test('every pack is a real, verifiable HTTPS download', () {
      for (final pack in VoiceCatalog.packs) {
        expect(pack.downloadUrl, startsWith('https://'));
        expect(
          pack.sha256,
          matches(RegExp(r'^[0-9a-f]{64}$')),
          reason: '${pack.id} needs a lowercase hex SHA-256 to verify against',
        );
        expect(pack.licence, isNotEmpty);
        expect(pack.voices, isNotEmpty);
      }
    });

    test('voice ids are unique and point at their own pack', () {
      final seen = <String>{};
      for (final pack in VoiceCatalog.packs) {
        for (final voice in pack.voices) {
          expect(seen.add(voice.id), isTrue, reason: 'duplicate ${voice.id}');
          expect(voice.packId, pack.id);
          expect(voice.speakerId, greaterThanOrEqualTo(0));
          expect(voice.name, isNotEmpty);
        }
      }
    });

    test('speaker ids are unique within a pack', () {
      for (final pack in VoiceCatalog.packs) {
        final ids = pack.voices.map((voice) => voice.speakerId).toList();
        expect(ids.toSet().length, ids.length, reason: pack.id);
      }
    });

    test('byId finds a pack and rejects an unknown one', () {
      expect(VoiceCatalog.byId(VoiceCatalog.kokoro.id), VoiceCatalog.kokoro);
      expect(VoiceCatalog.byId('nope'), isNull);
    });
  });

  group('voice selection', () {
    test('the device voice round-trips', () {
      expect(VoiceSelection.device.encode(), 'device');
      final decoded = VoiceSelection.decode(
        'device',
        catalog: VoiceCatalog.packs,
      );
      expect(decoded, isA<DeviceVoice>());
    });

    test('a downloaded voice round-trips to the same speaker', () {
      final voice = VoiceCatalog.kokoro.voices.first;
      final selection = PackVoice(voice);

      final decoded = VoiceSelection.decode(
        selection.encode(),
        catalog: VoiceCatalog.packs,
      );

      expect(decoded, isA<PackVoice>());
      expect((decoded! as PackVoice).voice.id, voice.id);
    });

    test('an unknown or empty value decodes to nothing', () {
      expect(VoiceSelection.decode(null, catalog: VoiceCatalog.packs), isNull);
      expect(VoiceSelection.decode('', catalog: VoiceCatalog.packs), isNull);
      expect(
        VoiceSelection.decode('gone#3', catalog: VoiceCatalog.packs),
        isNull,
      );
    });
  });
}
