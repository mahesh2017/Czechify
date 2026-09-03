import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:czechify/core/theme/app_motion.dart';
import 'package:czechify/presentation/screens/practice/copybook_screen.dart';
import 'package:czechify/presentation/providers/copybook_providers.dart';
import 'package:czechify/presentation/widgets/common/motion_widgets.dart';

import 'support/localized_app.dart';

void main() {
  testWidgets('persists a completed daily copybook item', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyCopybookProvider.overrideWith(
            (ref) async => const [
              CopybookItem(
                id: 42,
                czech: 'dobrý',
                english: 'good',
                example: 'Dobrý den.',
              ),
              CopybookItem(
                id: 43,
                czech: 'děkuji',
                english: 'thank you',
                example: 'Děkuji za pomoc.',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: CopybookScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Write Czech by hand'), findsOneWidget);
    expect(find.text('děkuji'), findsOneWidget);

    await tester.tap(find.text('dobrý'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final day = DateUtils.dateOnly(DateTime.now()).toIso8601String();
    expect(prefs.getStringList('copybook_done_$day'), contains('42'));
  });

  testWidgets('restored completion stays still and live completion reveals', (
    tester,
  ) async {
    final day = DateUtils.dateOnly(DateTime.now()).toIso8601String();
    SharedPreferences.setMockInitialValues({
      'copybook_done_$day': <String>['42'],
    });
    const items = [
      CopybookItem(
        id: 42,
        czech: 'dobrý',
        english: 'good',
        example: 'Dobrý den.',
      ),
      CopybookItem(
        id: 43,
        czech: 'děkuji',
        english: 'thank you',
        example: 'Děkuji za pomoc.',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dailyCopybookProvider.overrideWith((ref) async => items)],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: CopybookScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final restoredDisclosure = tester.widget<MotionDisclosure>(
      find.byType(MotionDisclosure),
    );
    expect(restoredDisclosure.visible, isFalse);
    expect(restoredDisclosure.duration, Duration.zero);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.tap(find.text('děkuji'));
    await tester.pump();

    final liveDisclosure = tester.widget<MotionDisclosure>(
      find.byType(MotionDisclosure),
    );
    expect(liveDisclosure.visible, isTrue);
    expect(liveDisclosure.duration, AppMotion.reward);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduce motion waits with a still indicator', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyCopybookProvider.overrideWith(
            (ref) => Completer<List<CopybookItem>>().future,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: CopybookScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    // A spinner is motion that never stops, so reduced motion gets a still
    // glyph rather than a permanently turning one.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
