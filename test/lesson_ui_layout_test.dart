import 'package:ceskina_pro/core/theme/app_theme.dart';
import 'package:ceskina_pro/presentation/widgets/common/lesson_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shared learning-loop primitives are dropped into scroll views all over
/// the app, where the incoming height constraint is unbounded. A widget that
/// quietly requires a bounded height asserts on every frame and paints nothing
/// at all — which is exactly how the review summary shipped blank once, with
/// only the pinned footer visible.
///
/// These pump each primitive inside a [ListView] and fail on any exception.
void main() {
  // AudioPairButtons carries the playback-speed chip, which reads the stored
  // rate, so these primitives now need a scope and a prefs stub the way they
  // have one in the running app.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child) => ProviderScope(
    child: MaterialApp(
      theme: lightTheme(),
      home: Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [child]),
      ),
    ),
  );

  group('survives an unbounded height', () {
    testWidgets('StatStrip', (tester) async {
      await tester.pumpWidget(
        host(
          const StatStrip(
            cells: [
              StatCell(value: '94%', label: 'Accuracy'),
              StatCell(value: '+40', label: 'XP earned'),
              // Deliberately long, so one cell is taller than the others and
              // the strip actually has to resolve a height.
              StatCell(value: '15/16', label: 'Correct answers this lesson'),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('94%'), findsOneWidget);
    });

    testWidgets('ScoreRing', (tester) async {
      await tester.pumpWidget(
        host(
          const Center(
            child: ScoreRing(fraction: 0.94, label: '94%', caption: 'accuracy'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('94%'), findsOneWidget);
    });

    testWidgets('AudioPairButtons with a label long enough to wrap', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AudioPairButtons(
            onPlay: () {},
            playLabel: 'Hear the alphabet (letter names)',
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      // The play button owns its row now, so a wrapping label just makes it
      // taller instead of breaking alignment with a fixed-height sibling.
      final play = tester.getSize(
        find.ancestor(
          of: find.text('Hear the alphabet (letter names)'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(play.height, greaterThanOrEqualTo(48));

      // And the speed control sits under it rather than competing for width.
      expect(find.byType(TtsSpeedSelector), findsOneWidget);
      for (final label in ['0.75x', '1x', '1.25x']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('QuizOptionTile', (tester) async {
      await tester.pumpWidget(
        host(
          const QuizOptionTile(
            keyLabel: 'A',
            text: 'Dobrý den',
            state: OptionState.idle,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // 44pt minimum target.
      expect(
        tester.getSize(find.byType(QuizOptionTile)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('AnswerField', (tester) async {
      await tester.pumpWidget(
        host(AnswerField(controller: TextEditingController())),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('KeyCta', (tester) async {
      await tester.pumpWidget(host(KeyCta(label: 'Check', onPressed: () {})));
      expect(tester.takeException(), isNull);
      expect(find.text('Check'), findsOneWidget);
    });

    testWidgets('SegmentPips, both the pip and the fallback track form', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const SegmentPips(count: 4, currentIndex: 1)),
      );
      expect(tester.takeException(), isNull);

      // Above a dozen steps it falls back to a plain track.
      await tester.pumpWidget(
        host(const SegmentPips(count: 30, currentIndex: 12)),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('KeyCta is disabled when it has no callback', (tester) async {
    await tester.pumpWidget(
      host(const KeyCta(label: 'Check', onPressed: null)),
    );
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
