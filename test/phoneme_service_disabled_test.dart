import 'dart:convert';
import 'dart:io';

import 'package:czechify/presentation/providers/stt_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phoneme scoring is postponed until there is a cloud model trained for Czech
/// audio. Until then the prototype service under `services/phoneme-recognizer`
/// stays switched off, and three audit findings stay dormant only because of
/// that — unauthenticated by default, unbounded upload memory, and consent
/// wording that does not cover sending recordings to it.
///
/// So the switch itself is worth pinning: turning it on is a decision that has
/// to be made deliberately, with those three addressed, not one that can be
/// made by adding a key to a config file.
void main() {
  test('no phoneme endpoint is compiled into this build', () {
    expect(
      kPhonemeServiceUrl,
      isEmpty,
      reason:
          'Setting PHONEME_SERVICE_URL enables an unauthenticated service and '
          'sends voice recordings outside the consent wording. See the notes '
          'at kPhonemeServiceUrl before changing this.',
    );
    expect(kPhonemeServiceToken, isEmpty);
  });

  test('the release dart-defines do not enable it either', () {
    // A passing unit test only proves the *test* build has no value. Release
    // builds take their defines from this file, so it is the one that decides
    // what learners actually run.
    final file = File('env/prod.json');
    expect(file.existsSync(), isTrue, reason: 'release defines are missing');

    final defines = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(defines.containsKey('PHONEME_SERVICE_URL'), isFalse);
    expect(defines.containsKey('PHONEME_SERVICE_TOKEN'), isFalse);
  });
}
