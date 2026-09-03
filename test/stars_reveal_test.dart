import 'package:czechify/core/feedback/celebration.dart';
import 'package:czechify/core/feedback/feedback_service.dart';
import 'package:czechify/core/feedback/sfx.dart';
import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/presentation/widgets/celebration/stars_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_service_test.dart' show RecordingHaptics, RecordingSfxPlayer;

/// Stars arriving one at a time turn a single fact — the score — into three
/// beats of payoff. These pin that they land, and that they land audibly.
void main() {
  late RecordingSfxPlayer player;
  late RecordingHaptics haptics;
  late FeedbackService feedback;

  setUp(() {
    player = RecordingSfxPlayer();
    haptics = RecordingHaptics();
    feedback = FeedbackService(player, () => true, () => true, haptics);
  });

  Future<void> show(
    WidgetTester tester,
    int earned, {
    bool reduceMotion = false,
    bool announceLandings = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Center(
              child: StarsReveal(
                earned: earned,
                feedback: feedback,
                announceLandings: announceLandings,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Long enough for all three steps and their landing animations.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  int filled(WidgetTester tester) =>
      tester
          .widgetList<Icon>(find.byType(Icon))
          .where((icon) => icon.icon == Icons.star_rounded)
          .length;

  testWidgets('the scale is always three, however many were earned', (
    tester,
  ) async {
    // A five-star scale makes three feel like a failure; three makes one
    // feel like a start.
    await show(tester, 1);
    expect(find.byType(Icon), findsNWidgets(3));
  });

  testWidgets('one star fills for a bare pass', (tester) async {
    await show(tester, 1);
    expect(filled(tester), 1);
  });

  testWidgets('all three fill for a perfect lesson', (tester) async {
    await show(tester, 3);
    expect(filled(tester), 3);
  });

  testWidgets('a star visibly scales between landing and rest', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Scaffold(body: StarsReveal(earned: 1, feedback: feedback)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(
      CelebrationTimeline.starStep - const Duration(milliseconds: 1),
    );
    expect(filled(tester), 0);
    await tester.pump(const Duration(milliseconds: 1));

    double scale() =>
        tester
            .widget<Transform>(find.byKey(const ValueKey('star-scale-0')))
            .transform
            .storage[0];

    expect(filled(tester), 1);
    final intermediateScales = <double>[scale()];
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      intermediateScales.add(scale());
    }
    expect(
      intermediateScales.any((value) => (value - 1).abs() > 0.01),
      isTrue,
      reason: 'the filled star must visibly travel before resting at 1.0',
    );

    await tester.pumpAndSettle();
    expect(scale(), closeTo(1.0, 0.001));
  });

  testWidgets('none fill when the lesson fell short', (tester) async {
    await show(tester, 0);
    expect(filled(tester), 0);
  });

  testWidgets('each star lands with its own rising note', (tester) async {
    // The same three notes a run of correct answers uses, so the reward
    // vocabulary stays consistent across the app.
    await show(tester, 3);
    expect(player.played, [Sfx.correct1, Sfx.correct2, Sfx.correct3]);
  });

  testWidgets('the last star is the one you feel most', (tester) async {
    await show(tester, 2);
    expect(haptics.fired.last, Haptic.heavy);
  });

  testWidgets('no stars means no sound', (tester) async {
    await show(tester, 0);
    expect(player.played, isEmpty);
  });

  testWidgets('a parent ceremony can own the sensory impact', (tester) async {
    await show(tester, 3, announceLandings: false);
    expect(filled(tester), 3);
    expect(player.played, isEmpty);
    expect(haptics.fired, isEmpty);
  });

  testWidgets('reduce motion still shows the result', (tester) async {
    // The stars are the score. Dropping them because someone asked for less
    // movement would remove information, not decoration.
    await show(tester, 2, reduceMotion: true);
    expect(filled(tester), 2);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('an initial delay holds the first star back', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Scaffold(
          body: Center(
            child: StarsReveal(
              earned: 3,
              feedback: feedback,
              initialDelay: const Duration(milliseconds: 400),
            ),
          ),
        ),
      ),
    );

    // A larger ceremony asks for this delay so the stars do not land on top of
    // the moment that introduces them; nothing may land before it elapses.
    await tester.pump(const Duration(milliseconds: 200));
    expect(filled(tester), 0);
    expect(player.played, isEmpty);

    // Long enough for the held first landing and all three steps after it.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(filled(tester), 3);
  });
}
