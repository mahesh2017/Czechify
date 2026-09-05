import 'dart:io';

import 'package:czechify/presentation/screens/onboarding/loading_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The app shipped two unrelated marks: a flat teal speech-bubble Č as the
  /// launcher icon, and an ornate lion badge on the loading screen. A learner
  /// tapped one and was greeted by the other.
  ///
  /// Uniformity is not something a screenshot review reliably catches, because
  /// the two live in different files and neither looks wrong on its own. This
  /// reads the launcher icon straight out of pubspec.yaml and fails if the
  /// first screen stops showing that same asset.
  ///
  /// Which asset *is* the launcher icon depends on the platform, and getting
  /// that wrong shipped a milder version of the same defect: Android 12 draws
  /// its splash from the adaptive icon's two layers and crops it to a circle,
  /// so the single-image icon on the loading screen arrived a moment later as a
  /// visibly squarer second mark. Each platform is therefore checked against
  /// the pubspec key that actually feeds its launcher.
  final pubspec = File('pubspec.yaml').readAsStringSync();
  String? iconKey(String key) =>
      RegExp(
        'flutter_launcher_icons:.*?$key:\\s*(\\S+)',
        dotAll: true,
      ).firstMatch(pubspec)?.group(1);

  for (final platform in const [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'the ${platform.name} loading screen shows the launcher icon, '
      'not a second mark',
      (tester) async {
        // Reset inside the body: the framework asserts every foundation debug
        // variable is clear before addTearDown callbacks would run.
        debugDefaultTargetPlatformOverride = platform;

        // Android composes its launcher icon from the adaptive layers; every
        // other platform masks the single image.
        final expected =
            platform == TargetPlatform.android
                ? [
                  iconKey('adaptive_icon_background'),
                  iconKey('adaptive_icon_foreground'),
                ]
                : [iconKey('image_path')];
        expect(
          expected,
          everyElement(isNotNull),
          reason: 'pubspec must declare the ${platform.name} launcher icon',
        );

        await tester.pumpWidget(const LoadingScreen());
        await tester.pump(const Duration(seconds: 1));

        final images =
            tester
                .widgetList<Image>(find.byType(Image))
                .map((image) => image.image)
                .map(
                  // The mark is decoded at display size, so the AssetImage is
                  // wrapped in a ResizeImage.
                  (provider) =>
                      provider is ResizeImage ? provider.imageProvider : provider,
                )
                .whereType<AssetImage>()
                .map((asset) => asset.assetName)
                .toList();

        debugDefaultTargetPlatformOverride = null;

        for (final asset in expected) {
          expect(
            images,
            contains(asset),
            reason:
                'the first screen must show the same mark as the '
                '${platform.name} launcher icon',
          );
        }
      },
    );
  }

  testWidgets('startup error explains the problem and retries', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      LoadingScreen(
        error: 'Check your internet connection and try again.',
        onRetry: () => retries++,
      ),
    );

    expect(find.text('Course couldn’t load'), findsOneWidget);
    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  for (final size in const [Size(320, 568), Size(375, 667), Size(768, 1024)]) {
    for (final brightness in Brightness.values) {
      testWidgets('startup recovery fits ${size.width.toInt()}px at 2x text in '
          '${brightness.name} mode', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await tester.pumpWidget(
          LoadingScreen(
            error:
                'The verified course could not be prepared. '
                'Try again without losing your progress.',
            onRetry: () {},
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Try again'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.widgetWithText(FilledButton, 'Try again'))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
      });
    }
  }

  testWidgets('startup retry is keyboard operable', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      LoadingScreen(error: 'Temporary failure.', onRetry: () => retries++),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(retries, 1);
  });
}
