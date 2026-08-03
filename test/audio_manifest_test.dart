import 'dart:convert';

import 'package:ceskina_pro/data/services/audio/audio_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidAudioPackFileName', () {
    final hash = 'a' * 64;

    test('accepts the shape the pack generator produces', () {
      // Both playback paths used to carry their own copy of this pattern, and
      // the English one escaped the dot as `\\.` inside a raw string — a
      // literal backslash no filename can contain. It matched nothing, so
      // every English narration fell through to the device's synthetic voice.
      expect(isValidAudioPackFileName('male_$hash.mp3'), isTrue);
      expect(isValidAudioPackFileName('female_$hash.mp3'), isTrue);
    });

    test('rejects anything that is not a pack clip', () {
      expect(isValidAudioPackFileName('male_$hash.wav'), isFalse);
      expect(isValidAudioPackFileName('male_${'a' * 63}.mp3'), isFalse);
      expect(isValidAudioPackFileName('MALE_$hash.mp3'), isFalse);
      expect(isValidAudioPackFileName('male_${'z' * 64}.mp3'), isFalse);
      expect(isValidAudioPackFileName('$hash.mp3'), isFalse);
      // Traversal: the name becomes a local path under the cache directory.
      expect(isValidAudioPackFileName('../male_$hash.mp3'), isFalse);
    });
  });

  group('ManifestEntry', () {
    test('parses legacy v2 string entries', () {
      final entry = ManifestEntry.fromJson('assets/audio/female_abc.mp3');
      expect(entry.path, 'assets/audio/female_abc.mp3');
      expect(entry.sha256, isNull);
      expect(entry.size, isNull);
      expect(entry.hasChecksum, isFalse);
    });

    test('parses v3 object entries with checksum and size', () {
      final entry = ManifestEntry.fromJson({
        'path': 'assets/audio/female_abc.mp3',
        'sha256': 'deadbeef',
        'size': 12345,
      });
      expect(entry.path, 'assets/audio/female_abc.mp3');
      expect(entry.sha256, 'deadbeef');
      expect(entry.size, 12345);
      expect(entry.hasChecksum, isTrue);
    });

    test('parses v3 object entries with only path (partial)', () {
      final entry = ManifestEntry.fromJson({
        'path': 'assets/audio/female_abc.mp3',
      });
      expect(entry.path, 'assets/audio/female_abc.mp3');
      expect(entry.hasChecksum, isFalse);
    });
  });

  group('AudioManifest.parse', () {
    test('parses v2 manifest with string entries', () {
      final raw = jsonEncode({
        'version': 2,
        'locale': 'cs-CZ',
        'voices': {
          'female': {
            'name': 'cs-CZ-VlastaNeural',
            'entries': {'abc123': 'assets/audio/female_abc123.mp3'},
          },
        },
      });
      final manifest = AudioManifest.parse(raw);
      expect(manifest.version, 2);
      expect(manifest.locale, 'cs-CZ');
      expect(manifest.revision, isNull);
      final entries = manifest.forGender('female');
      expect(entries, hasLength(1));
      expect(entries['abc123']!.path, 'assets/audio/female_abc123.mp3');
      expect(entries['abc123']!.hasChecksum, isFalse);
    });

    test('parses v3 manifest with object entries + revision', () {
      final raw = jsonEncode({
        'version': 3,
        'locale': 'cs-CZ',
        'revision': '20260731120000',
        'voices': {
          'female': {
            'name': 'cs-CZ-VlastaNeural',
            'entries': {
              'abc123': {
                'path': 'assets/audio/female_abc123.mp3',
                'sha256': 'deadbeef',
                'size': 12345,
              },
            },
          },
        },
      });
      final manifest = AudioManifest.parse(raw);
      expect(manifest.version, 3);
      expect(manifest.revision, '20260731120000');
      final entries = manifest.forGender('female');
      expect(entries['abc123']!.sha256, 'deadbeef');
      expect(entries['abc123']!.size, 12345);
      expect(entries['abc123']!.hasChecksum, isTrue);
    });

    test('forGender returns empty for unknown gender', () {
      final manifest = AudioManifest.parse('{"version":3,"voices":{}}');
      expect(manifest.forGender('male'), isEmpty);
    });
  });
}
