import 'dart:io';

import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/core/theme/system_bars.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Android explicitly enables edge-to-edge from Dart', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await enableAppEdgeToEdge();
    // Foundation debug overrides must be cleared before the test body exits;
    // addTearDown runs after Flutter verifies this invariant.
    debugDefaultTargetPlatformOverride = null;

    expect(
      calls,
      contains(
        isA<MethodCall>().having(
          (call) => call.method,
          'method',
          'SystemChrome.setEnabledSystemUIMode',
        ),
      ),
    );
  });

  test('Android activity enables edge-to-edge before Flutter content', () {
    final activity =
        File(
          'android/app/src/main/kotlin/com/eminentsite/czechify/MainActivity.kt',
        ).readAsStringSync();
    expect(activity, contains('import androidx.core.view.WindowCompat'));
    expect(
      activity,
      contains('WindowCompat.setDecorFitsSystemWindows(window, false)'),
    );
    expect(
      activity.indexOf('WindowCompat.setDecorFitsSystemWindows(window, false)'),
      lessThan(activity.indexOf('super.onCreate(savedInstanceState)')),
    );
  });

  testWidgets('custom headers update system icons when app theme changes', (
    tester,
  ) async {
    for (final dark in [true, false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? darkTheme() : lightTheme(),
          home: const AppSystemBars(
            child: Scaffold(body: Text('Custom header')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(
        region.value.statusBarIconBrightness,
        dark ? Brightness.light : Brightness.dark,
      );
      expect(
        region.value.systemNavigationBarIconBrightness,
        dark ? Brightness.light : Brightness.dark,
      );
    }
  });
}
