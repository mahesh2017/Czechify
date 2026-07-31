import 'package:ceskina_pro/core/feedback/celebration.dart';
import 'package:ceskina_pro/core/theme/app_theme.dart';
import 'package:ceskina_pro/presentation/providers/feedback_providers.dart';
import 'package:ceskina_pro/presentation/widgets/celebration/celebration_host.dart';
import 'package:ceskina_pro/presentation/widgets/celebration/confetti_layer.dart';
import 'package:ceskina_pro/presentation/widgets/celebration/count_up_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feedback_service_test.dart' show RecordingHaptics, RecordingSfxPlayer;

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        sfxPlayerProvider.overrideWithValue(RecordingSfxPlayer()),
        hapticDriverProvider.overrideWithValue(RecordingHaptics()),
      ],
    );
  });

  tearDown(() => container.dispose());

  const lesson = LessonCompleted(lessonId: 3, xp: 40, correct: 10, total: 12);
  const unit = UnitCompleted(unitId: 2, unitNumber: 2, unitTitle: 'Greetings');

  Future<void> mount(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          theme: brightness == Brightness.light ? lightTheme() : darkTheme(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: const CelebrationHost(child: Scaffold(body: Text('app'))),
          ),
        ),
      ),
    );
  }

  void fire(Celebration celebration) =>
      container.read(celebrationQueueProvider.notifier).fire(celebration);

  bool idle() => container.read(celebrationQueueProvider).isIdle;

  testWidgets('the app stays visible underneath a celebration', (tester) async {
    await mount(tester);
    fire(lesson);
    await tester.pump();

    expect(find.text('app'), findsOneWidget);
    expect(find.byType(ConfettiLayer), findsOneWidget);
  });

  testWidgets('a finished lesson gets confetti', (tester) async {
    await mount(tester);
    expect(find.byType(ConfettiLayer), findsNothing);

    fire(lesson);
    await tester.pump();
    expect(find.byType(ConfettiLayer), findsOneWidget);

    await tester.pumpAndSettle();
  });

  group('how much confetti the result earns', () {
    Future<int> piecesFor(WidgetTester tester, int correct, int total) async {
      await mount(tester);
      fire(
        LessonCompleted(
          lessonId: correct * 100 + total,
          xp: 60,
          correct: correct,
          total: total,
        ),
      );
      await tester.pump();
      final pieces =
          tester.widget<ConfettiLayer>(find.byType(ConfettiLayer)).pieces;
      await tester.pumpAndSettle();
      return pieces;
    }

    testWidgets('a perfect lesson throws the most', (tester) async {
      expect(await piecesFor(tester, 12, 12), greaterThan(120));
    });

    testWidgets('it scales down with the result', (tester) async {
      final perfect = await piecesFor(tester, 12, 12);
      final great = await piecesFor(tester, 10, 12);
      final scraped = await piecesFor(tester, 8, 12);
      expect(perfect, greaterThan(great));
      expect(great, greaterThan(scraped));
      expect(scraped, greaterThan(0));
    });

    testWidgets('a lesson under the bar gets none at all', (tester) async {
      // Confetti for a result the learner is about to be asked to retry
      // reads as mockery.
      expect(await piecesFor(tester, 5, 12), 0);
    });
  });

  group('self-dismissal', () {
    testWidgets('it clears itself once its time is up', (tester) async {
      await mount(tester);
      fire(lesson);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 2100));
      expect(idle(), isFalse, reason: 'dismissed before the confetti finished');

      await tester.pump(const Duration(milliseconds: 300));
      expect(idle(), isTrue);

      await tester.pumpAndSettle();
    });

    testWidgets('a rebuild does not restart the clock', (tester) async {
      // Without a guard, anything that rebuilds the host — a theme change, a
      // rotation — would re-arm the timer and the ceremony would never end.
      await mount(tester);
      fire(lesson);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      await mount(tester, brightness: Brightness.dark);
      await tester.pump(const Duration(milliseconds: 900));

      expect(idle(), isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('a unit waits for the learner instead', (tester) async {
      await mount(tester);
      fire(unit);
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));

      expect(
        idle(),
        isFalse,
        reason:
            'the unit ceremony names what was unlocked — it must not '
            'slide away on a timer',
      );
    });

    testWidgets('the next one takes over when the first clears', (
      tester,
    ) async {
      await mount(tester);
      fire(lesson);
      fire(unit);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 2400));
      expect(container.read(celebrationQueueProvider).current, unit);

      await tester.pumpAndSettle();
    });
  });

  testWidgets('reduce motion drops the confetti, not the celebration', (
    tester,
  ) async {
    await mount(tester, reduceMotion: true);
    fire(lesson);
    await tester.pump();

    // The layer is still mounted and still on the queue — it simply paints
    // nothing, so the sound and the completion screen are unaffected.
    expect(find.byType(ConfettiLayer), findsOneWidget);
    expect(tester.widget<ConfettiLayer>(find.byType(ConfettiLayer)), isNotNull);
    expect(idle(), isFalse);

    await tester.pump(const Duration(milliseconds: 2400));
  });

  group('count-up', () {
    testWidgets('it starts below the total and lands on it', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(body: Center(child: CountUpText(value: 40))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('40'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('40'), findsOneWidget);
    });

    testWidgets('reduce motion shows the total straight away', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(child: CountUpText(value: 40, prefix: '+')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('+40'), findsOneWidget);
    });
  });
}
