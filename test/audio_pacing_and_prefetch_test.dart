import 'dart:convert';
import 'dart:io';

import 'package:ceskina_pro/data/services/audio/offline_audio_prefetch.dart';
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/presentation/providers/settings_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two defaults that were quietly wrong for anyone who was not a native
/// speaker starting at A1.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('speech rate', () {
    test('the default plays a clip at the pace it was recorded at', () {
      // Teaching pace lives in the recordings. A default off the native rate
      // stacks a second slowdown on clips already stretched to teach with —
      // together they ran to ~1.6x the original length, which is laboured
      // rather than clear.
      expect(kDefaultTtsSpeechRate, kNativeTtsSpeechRate);
    });

    test('the default lands inside the range playback can honour', () {
      // _playNeural clamps the multiplier to 0.5..1.5; a default outside that
      // would be silently ignored rather than applied.
      const multiplier = kDefaultTtsSpeechRate / kNativeTtsSpeechRate;
      expect(multiplier, greaterThanOrEqualTo(0.5));
      expect(multiplier, lessThanOrEqualTo(1.5));
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
      expect(await OfflineAudioPrefetch.unitsForLevel(CEFRLevel.preA1), [
        1,
        2,
        3,
      ]);
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
      final raw = await rootBundle.loadString(
        'assets/audio/offline_units.json',
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['version'], greaterThanOrEqualTo(2));
      final intros = json['intros'] as Map<String, dynamic>;
      expect(intros, isNotEmpty);
      // Unit 17 is the first A2 unit that carries one, and A2 learners
      // prefetch 16-18, so it must be in the set they download.
      expect(intros['17'], isNotEmpty);
    });

    test('count is honoured', () async {
      expect(await OfflineAudioPrefetch.unitsForLevel(CEFRLevel.a2, count: 2), [
        16,
        17,
      ]);
    });
  });

  group('the prefetch set covers both packs', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory temp;
    late List<String> czechKeys;
    late List<String> introKeys;

    Directory clipDir() => Directory('${temp.path}/neural_audio');

    setUpAll(() async {
      final json =
          jsonDecode(
                await rootBundle.loadString('assets/audio/offline_units.json'),
              )
              as Map<String, dynamic>;
      czechKeys =
          ((json['units'] as Map<String, dynamic>)['17'] as List<dynamic>)
              .cast<String>();
      introKeys =
          ((json['intros'] as Map<String, dynamic>)['17'] as List<dynamic>)
              .cast<String>();
    });

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('offline_prefetch');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => temp.path);
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (temp.existsSync()) await temp.delete(recursive: true);
    });

    test('a unit asks for its English narration, not only its Czech', () async {
      // The regression this guards: missingFiles built only `{gender}_{key}`,
      // so the English intro — the first thing a teaching card plays — was
      // never prefetched and unit 17 opened with a network request.
      final missing = await OfflineAudioPrefetch(
        Dio(),
      ).missingFiles([17], 'male');

      expect(introKeys, isNotEmpty, reason: 'unit 17 should carry an intro');
      for (final key in introKeys) {
        expect(missing, contains('enmale_$key.mp3'));
      }
      expect(missing, contains('male_${czechKeys.first}.mp3'));
      expect(missing.length, czechKeys.length + introKeys.length);
    });

    test('the gender picks the filename on both packs', () async {
      final missing = await OfflineAudioPrefetch(
        Dio(),
      ).missingFiles([17], 'female');

      expect(missing, contains('enfemale_${introKeys.first}.mp3'));
      expect(missing, contains('female_${czechKeys.first}.mp3'));
      expect(
        missing.every(
          (n) => n.startsWith('female_') || n.startsWith('enfemale_'),
        ),
        isTrue,
        reason: 'a female prefetch must not ask for a male clip',
      );
    });

    test('a clip already on disk is not asked for again', () async {
      await clipDir().create(recursive: true);
      await File(
        '${clipDir().path}/male_${czechKeys.first}.mp3',
      ).writeAsBytes(const [0]);
      await File(
        '${clipDir().path}/enmale_${introKeys.first}.mp3',
      ).writeAsBytes(const [0]);

      final missing = await OfflineAudioPrefetch(
        Dio(),
      ).missingFiles([17], 'male');

      expect(missing, isNot(contains('male_${czechKeys.first}.mp3')));
      expect(missing, isNot(contains('enmale_${introKeys.first}.mp3')));
      expect(missing.length, czechKeys.length + introKeys.length - 2);
    });

    test('a unit with no intro yields Czech clips alone', () async {
      // Unit 16 has no English narration recorded. The prefetch must simply
      // omit it rather than build a name for a clip that does not exist.
      final missing = await OfflineAudioPrefetch(
        Dio(),
      ).missingFiles([16], 'male');

      expect(missing, isNotEmpty);
      expect(missing.any((n) => n.startsWith('enmale_')), isFalse);
    });
  });
}
