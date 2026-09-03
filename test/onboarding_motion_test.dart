import 'dart:async';

import 'package:czechify/l10n/app_localizations.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget host({
    bool disableAnimations = false,
    double textScale = 1,
    CzechTts? tts,
  }) => ProviderScope(
    overrides: [if (tts != null) czechTtsProvider.overrideWithValue(tts)],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: disableAnimations,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
      home: OnboardingScreen(key: ValueKey(disableAnimations)),
    ),
  );

  Future<void> enterSetup(WidgetTester tester) async {
    await tester.tap(find.text('Start learning free'));
    await tester.pumpAndSettle();
  }

  testWidgets('teacher choice has its own visible setup step', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await enterSetup(tester);

    for (var step = 1; step < 4; step++) {
      expect(find.text('$step / 7'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('4 / 7'), findsOneWidget);
    expect(find.text('Choose a rhythm you can keep'), findsOneWidget);
    expect(find.text('Choose a Czech teacher voice'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('5 / 7'), findsOneWidget);
    expect(find.text('Choose a Czech teacher voice'), findsOneWidget);
    expect(find.text('Lenka'), findsOneWidget);
    expect(find.text('Pavel'), findsOneWidget);
    expect(find.text('Choose a rhythm you can keep'), findsNothing);
  });

  testWidgets('teacher preview exposes busy state and ignores duplicate taps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final tts = _BlockingTts();
    await tester.pumpWidget(host(tts: tts));
    await enterSetup(tester);
    for (var step = 1; step <= 4; step++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text(TtsVoiceGender.female.tutorName));
    await tester.pump();
    await tester.pump();
    expect(tts.previewCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(
      find.text(TtsVoiceGender.male.tutorName),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(tts.previewCalls, 1);

    tts.completePreview();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('teacher step remains usable at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(textScale: 2));
    await enterSetup(tester);
    for (var step = 1; step <= 4; step++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Choose a Czech teacher voice'), findsOneWidget);
    expect(find.text('Lenka'), findsOneWidget);
    expect(find.text('Pavel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forward and back transitions use opposite directions', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await enterSetup(tester);

    await tester.tap(find.text('Continue'));
    await tester.pump();

    FractionalTranslation incomingTranslation() => tester.widget(
      find
          .ancestor(
            of: find.byKey(const ValueKey('onboarding-step-2')),
            matching: find.byType(FractionalTranslation),
          )
          .first,
    );

    expect(incomingTranslation().translation.dx, greaterThan(0));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();

    final reverseIncoming = tester.widget<FractionalTranslation>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('onboarding-step-1')),
            matching: find.byType(FractionalTranslation),
          )
          .first,
    );
    expect(reverseIncoming.translation.dx, lessThan(0));
  });

  testWidgets('step changes dismiss focus and reset scroll position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await enterSetup(tester);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(scrollable.position.pixels, 0);
  });

  testWidgets('progress pips interpolate and reduced motion settles at once', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await enterSetup(tester);

    double widthOf(int index) =>
        tester
            .getSize(find.byKey(ValueKey('onboarding-progress-$index')))
            .width;

    final firstActive = widthOf(0);
    final secondIdle = widthOf(1);
    expect(firstActive, greaterThan(secondIdle));

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(widthOf(0), inExclusiveRange(secondIdle, firstActive));
    expect(widthOf(1), inExclusiveRange(secondIdle, firstActive));

    await tester.pumpWidget(host(disableAnimations: true));
    await enterSetup(tester);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(widthOf(0), lessThan(widthOf(1)));
  });
}

class _BlockingTts implements CzechTts {
  final _preview = Completer<void>();
  int previewCalls = 0;

  @override
  Future<void> playVoiceSample(TtsVoiceGender gender) {
    previewCalls++;
    return _preview.future;
  }

  void completePreview() => _preview.complete();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
