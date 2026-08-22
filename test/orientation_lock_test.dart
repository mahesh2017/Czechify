import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app is portrait-only, and all three declarations have to agree.
///
/// Every screen is drawn against a tall viewport — notch-sized top paddings,
/// fixed-height exercise images, decorations placed in portrait coordinates.
/// Rotated, the seams showed: the onboarding name step overflowed by 99px once
/// the keyboard was up, and 115 of the 151 listening-comprehension cards
/// overflowed outright — including every single one that carries an image.
///
/// Nothing had ever asked for portrait. The manifests carried Flutter's
/// default template, which permits both landscape modes, so the app inherited
/// an orientation it was never designed for. This guards the decision: putting
/// landscape back means adapting those layouts first, not just widening an
/// array.
void main() {
  test('iOS declares portrait only, on both idioms', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    for (final key in const [
      'UISupportedInterfaceOrientations',
      'UISupportedInterfaceOrientations~ipad',
    ]) {
      final start = plist.indexOf('<key>$key</key>');
      expect(start, isNonNegative, reason: '$key is missing from Info.plist');

      final open = plist.indexOf('<array>', start);
      final close = plist.indexOf('</array>', open);
      final orientations = plist.substring(open, close);

      expect(
        orientations,
        contains('UIInterfaceOrientationPortrait'),
        reason: '$key must allow portrait',
      );
      expect(
        orientations,
        isNot(contains('Landscape')),
        reason:
            '$key allows landscape again — the layouts still assume a tall '
            'viewport, so this reopens the overflows described above',
      );
    }
  });

  test('Android declares portrait only', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      manifest,
      contains('android:screenOrientation="portrait"'),
      reason: 'MainActivity must pin portrait, matching iOS',
    );
  });

  test('the Flutter side asks for portrait too', () {
    final main = File('lib/main.dart').readAsStringSync();

    // The manifests are what the OS enforces; this is what keeps an in-app
    // rotation request from ever widening it.
    expect(main, contains('setPreferredOrientations'));
    expect(main, contains('DeviceOrientation.portraitUp'));
    expect(
      main,
      isNot(contains('DeviceOrientation.landscape')),
      reason: 'landscape is not supported — see the note in main.dart',
    );
  });
}
