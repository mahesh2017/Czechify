import 'package:ceskina_pro/core/feedback/feedback_service.dart';
import 'package:ceskina_pro/core/feedback/sfx.dart';
import 'package:ceskina_pro/core/theme/app_theme.dart';
import 'package:ceskina_pro/presentation/widgets/celebration/stars_reveal.dart';
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
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Center(
              child: StarsReveal(earned: earned, feedback: feedback),
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

  testWidgets('reduce motion still shows the result', (tester) async {
    // The stars are the score. Dropping them because someone asked for less
    // movement would remove information, not decoration.
    await show(tester, 2, reduceMotion: true);
    expect(filled(tester), 2);
  });
}
