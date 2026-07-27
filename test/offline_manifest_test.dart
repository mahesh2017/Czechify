import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The offline manifest is written by tool/generate_offline_manifest.py and
/// read by OfflineAudioPrefetch. Nothing else connects the two, so a change to
/// either side would silently produce an app that downloads nothing and looks
/// like it worked.
///
/// These assertions are the contract: shape, key format, and the promise that
/// the units a learner starts with actually have clips on the server.
void main() {
  final manifest =
      jsonDecode(
            File('assets/audio/offline_units.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final units = manifest['units'] as Map<String, dynamic>;

  final audioManifest =
      jsonDecode(File('assets/audio/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  final voices = audioManifest['voices'] as Map<String, dynamic>;

  test('manifest covers every unit in the curriculum', () {
    expect(units.length, 31);
    for (var id = 1; id <= 31; id++) {
      expect(units.containsKey('$id'), isTrue, reason: 'unit $id missing');
    }
  });

  test('keys are sha256 hex, matching the audio file naming', () {
    final hex = RegExp(r'^[0-9a-f]{64}$');
    for (final entry in units.entries) {
      for (final key in entry.value as List<dynamic>) {
        expect(
          hex.hasMatch(key as String),
          isTrue,
          reason: 'unit ${entry.key} has a malformed key: $key',
        );
      }
    }
  });

  test('the first three units have audio in both voices', () {
    // These are downloaded on first run, so a missing clip here means a
    // learner who went offline immediately would hit silence.
    for (final gender in ['female', 'male']) {
      final entries =
          (voices[gender] as Map<String, dynamic>)['entries']
              as Map<String, dynamic>;
      for (final unit in ['1', '2', '3']) {
        for (final key in units[unit] as List<dynamic>) {
          expect(
            entries.containsKey(key),
            isTrue,
            reason: '$gender voice has no clip for unit $unit key $key',
          );
        }
      }
    }
  });

  test('unit 1 is substantial enough to be worth pre-fetching', () {
    // Guards against the generator silently producing empty lists — which
    // would download nothing and still report success.
    expect((units['1'] as List<dynamic>).length, greaterThan(50));
  });

  test('every key resolves to a clip in the audio manifest', () {
    final female =
        (voices['female'] as Map<String, dynamic>)['entries']
            as Map<String, dynamic>;
    final all = <String>{
      for (final list in units.values) ...(list as List<dynamic>).cast<String>(),
    };
    final orphans = all.where((k) => !female.containsKey(k)).toList();
    expect(orphans, isEmpty, reason: 'keys with no audio: ${orphans.take(5)}');
  });
}
