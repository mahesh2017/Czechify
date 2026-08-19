import 'package:ceskina_pro/presentation/providers/settings_providers.dart';
import 'package:ceskina_pro/presentation/widgets/common/lesson_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

/// The pace control a learner reaches for mid-lesson. It replaced a "Slower"
/// button that replayed one phrase at 0.6x — and on teaching cards did not
/// even do that, because play-all is a toggle and any tap during playback
/// stopped it.
void main() {
  setUp(() {
    // The settings notifier awaits SharedPreferences on build; with no mock
    // the future never completes and every pumpAndSettle here hangs.
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> pumpSelector(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(body: Center(child: TtsSpeedSelector())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(TtsSpeedSelector)),
    );
  }

  testWidgets('every speed is visible without pressing anything', (
    tester,
  ) async {
    await pumpSelector(tester);

    // The point of replacing the cycling chip: you can see what you can pick
    // and which one you are on, rather than tapping to find out.
    expect(find.text('Slow'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Fast'), findsOneWidget);
  });

  testWidgets('starts on the pace the clips were recorded at', (tester) async {
    final container = await pumpSelector(tester);
    expect(
      TtsSpeedSelector.nearestStopIndex(
        container.read(settingsProvider).ttsSpeechRate,
      ),
      kTtsSpeedStops.indexOf(1.0),
    );
  });

  testWidgets('picking a speed writes the shared setting', (tester) async {
    final container = await pumpSelector(tester);

    await tester.tap(find.text('Fast'));
    await tester.pumpAndSettle();

    // The same value the Settings slider edits, so the two can never disagree
    // about how fast the audio is.
    expect(
      container.read(settingsProvider).ttsSpeechRate,
      closeTo(kNativeTtsSpeechRate * 1.25, 1e-9),
    );

    await tester.tap(find.text('Slow'));
    await tester.pumpAndSettle();
    expect(
      container.read(settingsProvider).ttsSpeechRate,
      closeTo(kNativeTtsSpeechRate * 0.75, 1e-9),
    );
  });

  testWidgets('tapping the speed already selected changes nothing', (
    tester,
  ) async {
    final container = await pumpSelector(tester);
    final before = container.read(settingsProvider).ttsSpeechRate;

    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).ttsSpeechRate, before);
  });

  group('a rate between two stops', () {
    test('resolves to the nearer one rather than defaulting', () {
      // The Settings slider moves in steps that do not land on these stops, so
      // a learner can leave the rate between two and the control still has to
      // show something true.
      expect(
        TtsSpeedSelector.nearestStopIndex(kNativeTtsSpeechRate * 1.2),
        kTtsSpeedStops.indexOf(1.25),
      );
      expect(
        TtsSpeedSelector.nearestStopIndex(kNativeTtsSpeechRate * 0.8),
        kTtsSpeedStops.indexOf(0.75),
      );
    });

    test('an extreme rate clamps to an end stop rather than going out of range', () {
      expect(TtsSpeedSelector.nearestStopIndex(kNativeTtsSpeechRate * 0.2), 0);
      expect(
        TtsSpeedSelector.nearestStopIndex(kNativeTtsSpeechRate * 5),
        kTtsSpeedStops.length - 1,
      );
    });
  });
}
