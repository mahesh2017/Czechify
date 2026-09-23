import 'dart:io';

import 'package:czechify/core/platform/orientation_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('adaptive orientation policy', () {
    test(
      'keeps compact phones portrait-only in either physical orientation',
      () {
        expect(preferredOrientationsForDisplay(const Size(393, 852)), const [
          DeviceOrientation.portraitUp,
        ]);
        expect(preferredOrientationsForDisplay(const Size(852, 393)), const [
          DeviceOrientation.portraitUp,
        ]);
      },
    );

    test('unlocks tablets and other displays from 600dp', () {
      for (final size in const [
        Size(600, 960),
        Size(960, 600),
        Size(1024, 768),
        Size(1366, 768),
      ]) {
        expect(
          preferredOrientationsForDisplay(size),
          isEmpty,
          reason: '$size should be free to rotate',
        );
      }
    });

    testWidgets('on Android the display, not the window, decides', (
      tester,
    ) async {
      final requested = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            requested.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      addTearDown(tester.view.display.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        // A phone: 1179 x 2556 physical pixels at 3x is 393 x 852 dp.
        tester.view.display.size = const Size(1179, 2556);
        tester.view.display.devicePixelRatio = 3;
        await applyAdaptiveOrientationPolicy();
        // A tablet, even when the app window itself is narrow.
        tester.view.display.size = const Size(2560, 1600);
        tester.view.display.devicePixelRatio = 2;
        tester.view.physicalSize = const Size(600, 1600);
        addTearDown(tester.view.resetPhysicalSize);
        await applyAdaptiveOrientationPolicy();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(requested, [
        ['DeviceOrientation.portraitUp'],
        <String>[],
      ]);

      // Other platforms keep their own settings.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await applyAdaptiveOrientationPolicy();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(requested, hasLength(2));
    });

    test('does not statically lock Android in the manifest', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, isNot(contains('android:screenOrientation')));
    });

    test('keeps iPhone portrait-only and unlocks iPad', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      String orientationsFor(String key) {
        final start = plist.indexOf('<key>$key</key>');
        expect(start, isNonNegative, reason: '$key is missing from Info.plist');
        final open = plist.indexOf('<array>', start);
        final close = plist.indexOf('</array>', open);
        return plist.substring(open, close);
      }

      final phone = orientationsFor('UISupportedInterfaceOrientations');
      expect(phone, contains('UIInterfaceOrientationPortrait'));
      expect(phone, isNot(contains('Landscape')));

      final tablet = orientationsFor('UISupportedInterfaceOrientations~ipad');
      expect(tablet, contains('UIInterfaceOrientationPortrait'));
      expect(tablet, contains('UIInterfaceOrientationLandscapeLeft'));
      expect(tablet, contains('UIInterfaceOrientationLandscapeRight'));
    });
  });
}
