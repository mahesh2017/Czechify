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

  test('the release build does not define it either', () {
    // A passing unit test only proves the *test* build has no value. Release
    // builds take their dart-defines from `env/prod.json`, which is gitignored
    // and written by the release workflow from three secrets — so the workflow
    // is the committed source of truth for what ships, and the thing to check.
    final workflow = File('.github/workflows/release.yml');
    expect(workflow.existsSync(), isTrue, reason: 'release workflow missing');

    expect(
      workflow.readAsStringSync(),
      isNot(contains('PHONEME')),
      reason:
          'The release build would enable an unauthenticated service and send '
          'voice recordings outside the consent wording. See the notes at '
          'kPhonemeServiceUrl before changing this.',
    );
  });
}
