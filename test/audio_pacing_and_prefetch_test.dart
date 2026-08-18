import 'package:ceskina_pro/data/services/audio/offline_audio_prefetch.dart';
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/presentation/providers/settings_providers.dart';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two defaults that were quietly wrong for anyone who was not a native
/// speaker starting at A1.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('speech rate', () {
    test('a new learner does not start at native pace', () {
      // The bug: the default sat exactly on the native rate, so rate/native
      // was 1.0 and every beginner heard the raw generated speed.
      expect(kDefaultTtsSpeechRate, lessThan(kNativeTtsSpeechRate));
    });

    test('the default lands inside the range playback can honour', () {
      // _playNeural clamps the multiplier to 0.5..1.5; a default outside that
      // would be silently ignored rather than applied.
      const multiplier = kDefaultTtsSpeechRate / kNativeTtsSpeechRate;
      expect(multiplier, greaterThanOrEqualTo(0.5));
      expect(multiplier, lessThan(1.0));
    });

    test('the default is reachable on the settings slider', () {
      // Slider spans 0.2–1.0 in 8 divisions, so only multiples of 0.1 are
      // selectable. A default off that grid jumps the moment it is touched.
      expect(kDefaultTtsSpeechRate, greaterThanOrEqualTo(0.2));
      expect(kDefaultTtsSpeechRate, lessThanOrEqualTo(1.0));
    });
  });

  group('offline prefetch follows the chosen level', () {
    test('A1 gets the first A1 units', () async {
      expect(await OfflineAudioPrefetch.unitsForLevel(CEFRLevel.a1), [1, 2, 3]);
    });

    test('pre-A1 is treated as A1 rather than falling through', () async {
      expect(
        await OfflineAudioPrefetch.unitsForLevel(CEFRLevel.preA1),
        [1, 2, 3],
      );
    });

    test('A2 gets A2 units, not A1 audio it will never open', () async {
      // The whole bug: units are numbered globally, so a hardcoded [1,2,3]
      // gave an A2 learner three units of A1 and nothing for unit 16.
      final units = await OfflineAudioPrefetch.unitsForLevel(CEFRLevel.a2);
      expect(units, [16, 17, 18]);
      expect(units, isNot(contains(1)));
    });

    test('the offline manifest carries English intro keys', () async {
      // The intros are a second pack named en{gender}_{key}.mp3. A prefetch
      // that only built {gender}_{key}.mp3 never fetched them, so the first
      // sound of a unit always needed the network.
      final raw = await rootBundle.loadString('assets/audio/offline_units.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['version'], greaterThanOrEqualTo(2));
      final intros = json['intros'] as Map<String, dynamic>;
      expect(intros, isNotEmpty);
      // Unit 17 is the first A2 unit that carries one, and A2 learners
      // prefetch 16-18, so it must be in the set they download.
      expect(intros['17'], isNotEmpty);
    });

    test('count is honoured', () async {
      expect(
        await OfflineAudioPrefetch.unitsForLevel(CEFRLevel.a2, count: 2),
        [16, 17],
      );
    });
  });
}
