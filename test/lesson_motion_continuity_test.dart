import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/word_order_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

void main() {
  const exercise = Exercise(
    id: 41,
    lessonId: 2,
    type: ExerciseType.wordOrder,
    prompt: 'Build the sentence.',
    data: {
      'words': ['já', 'mám', 'já'],
      'correct_order': [0, 1, 2],
    },
  );

  Widget host({bool reducedMotion = false}) {
    return MaterialApp(
      theme: lightTheme(),
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(
          body: SingleChildScrollView(
            child: WordOrderView(exercise: exercise, onAnswered: (_) {}),
          ),
        ),
      ),
    );
  }

  WordChip chip(WidgetTester tester, int id) {
    final token = find.byKey(ValueKey('word-token-$id'));
    return tester.widget<WordChip>(
      find.descendant(of: token, matching: find.byType(WordChip)),
    );
  }

  testWidgets('duplicate words keep stable identities during rapid moves', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    for (var id = 0; id < 3; id++) {
      expect(find.byKey(ValueKey('word-token-$id')), findsOneWidget);
    }
    expect(chip(tester, 0).placed, isFalse);
    expect(chip(tester, 2).placed, isFalse);

    await tester.tap(find.byKey(const ValueKey('word-token-0')));
    await tester.pump();
    expect(chip(tester, 0).placed, isTrue);

    await tester.tap(find.byKey(const ValueKey('word-token-2')));
    await tester.pump(const Duration(milliseconds: 1));
    expect(chip(tester, 2).placed, isTrue);

    // Move the first duplicate back before either incoming animation settles.
    await tester.tap(find.byKey(const ValueKey('word-token-0')));
    await tester.pump(const Duration(milliseconds: 1));
    expect(chip(tester, 0).placed, isFalse);
    expect(chip(tester, 2).placed, isTrue);
    for (var id = 0; id < 3; id++) {
      expect(find.byKey(ValueKey('word-token-$id')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'moved word reaches its final state immediately with less motion',
    (tester) async {
      await tester.pumpWidget(host(reducedMotion: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('word-token-0')));
      await tester.pump();
      final entranceOpacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(const ValueKey('word-token-0')),
          matching: find.byType(Opacity),
        ),
      );
      expect(entranceOpacity.opacity, 1);
      expect(chip(tester, 0).placed, isTrue);
    },
  );
}
