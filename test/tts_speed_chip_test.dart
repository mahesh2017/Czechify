import 'package:ceskina_pro/presentation/providers/settings_providers.dart';
import 'package:ceskina_pro/presentation/widgets/common/lesson_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

/// The control a learner reaches for mid-sentence, when the Settings slider is
/// several taps away and the audio is already past the word they missed.
void main() {
  setUp(() {
    // The settings notifier awaits SharedPreferences on build; with no mock
    // the future never completes and every pumpAndSettle here hangs.
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> pumpChip(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(body: Center(child: TtsSpeedChip())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(TtsSpeedChip)));
  }

  testWidgets('starts at the pace the clips were recorded at', (tester) async {
    await pumpChip(tester);
    expect(find.text('1x'), findsOneWidget);
  });

  testWidgets('cycles forward and wraps back round', (tester) async {
    await pumpChip(tester);

    await tester.tap(find.byType(TtsSpeedChip));
    await tester.pumpAndSettle();
    expect(find.text('1.25x'), findsOneWidget);

    await tester.tap(find.byType(TtsSpeedChip));
    await tester.pumpAndSettle();
    expect(find.text('0.75x'), findsOneWidget);

    await tester.tap(find.byType(TtsSpeedChip));
    await tester.pumpAndSettle();
    expect(find.text('1x'), findsOneWidget);
  });

  testWidgets('writes the shared setting, not a private one', (tester) async {
    final container = await pumpChip(tester);

    await tester.tap(find.byType(TtsSpeedChip));
    await tester.pumpAndSettle();

    // The same value the Settings slider edits, so the two can never disagree
    // about how fast the audio is.
    expect(
      container.read(settingsProvider).ttsSpeechRate,
      closeTo(kNativeTtsSpeechRate * 1.25, 1e-9),
    );
  });

  testWidgets('a rate between two stops shows the nearer one', (tester) async {
    final container = await pumpChip(tester);

    // The Settings slider moves in steps that do not land on these stops, so a
    // learner can leave the rate between two. The chip still has to say
    // something true rather than defaulting to 1x.
    await container
        .read(settingsProvider.notifier)
        .setTtsSpeechRate(kNativeTtsSpeechRate * 1.2);
    await tester.pumpAndSettle();

    expect(find.text('1.25x'), findsOneWidget);
  });

  testWidgets('tapping from an off-stop rate advances from the nearer stop', (
    tester,
  ) async {
    final container = await pumpChip(tester);
    await container
        .read(settingsProvider.notifier)
        .setTtsSpeechRate(kNativeTtsSpeechRate * 0.8);
    await tester.pumpAndSettle();
    expect(find.text('0.75x'), findsOneWidget);

    await tester.tap(find.byType(TtsSpeedChip));
    await tester.pumpAndSettle();
    expect(find.text('1x'), findsOneWidget);
  });
}
