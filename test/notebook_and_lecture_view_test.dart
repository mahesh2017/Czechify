import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/services/notebook_store.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:czechify/presentation/widgets/common/slide_deck.dart';
import 'package:czechify/presentation/widgets/lesson/exercise_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

/// The two new teaching surfaces of plan v1.2: the notebook step (write from
/// memory, then compare) and the lecture step (explanation, table, examples,
/// common mistake).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const notebook = Exercise(
    id: 6003,
    lessonId: 101,
    type: ExerciseType.teaching,
    prompt: 'Notebook',
    data: {
      'type': 'teaching',
      'style': 'notebook',
      'kind': 'capture',
      'heading': 'Start your Unit 6 page',
      'instruction': 'From memory, write the four café phrases.',
      'items': [
        {'cz': 'Dám si kávu.', 'en': "I'll have a coffee."},
      ],
    },
  );

  const lecture = Exercise(
    id: 6101,
    lessonId: 102,
    type: ExerciseType.teaching,
    prompt: 'Lecture',
    data: {
      'type': 'teaching',
      'style': 'lecture',
      'grammar_rule_id': 'GR-050',
      'step': 1,
      'steps': 2,
      'heading': 'What changes',
      'say': 'Feminine words ending in -a change -a to -u.',
      'table': [
        ['káva', 'kávu'],
        ['voda', 'vodu'],
      ],
      'examples': [
        {'cz': 'Dám si kávu.', 'en': "I'll have a coffee."},
        {'cz': 'Chci vodu.', 'en': 'I want water.'},
      ],
      'common_mistake': {'wrong': 'Dám si káva.', 'right': 'Dám si kávu.'},
      'items': [
        {'cz': 'Dám si kávu.', 'en': "I'll have a coffee."},
      ],
    },
  );

  Future<List<ExerciseResult>> pump(
    WidgetTester tester,
    Exercise exercise, {
    bool onPaper = true,
  }) async {
    final results = <ExerciseResult>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _Settings(onPaper: onPaper)),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          // A phone's exercise area: both steps are decks and need a
          // bounded height, as the lesson gives them.
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: ExerciseWidget(exercise: exercise, onAnswered: results.add),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // A learner's first notebook step opens on the one-time intro.
    if (exercise.data['style'] == 'notebook') {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    return results;
  }

  testWidgets('the model stays hidden until the learner has written', (
    tester,
  ) async {
    final results = await pump(tester, notebook);

    expect(find.text('Start your Unit 6 page'), findsOneWidget);
    expect(find.text('Dám si kávu.'), findsNothing);
    expect(find.text("I don't have a pen right now"), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'paper by default');

    await tester.tap(find.text('Check against the model'));
    await tester.pumpAndSettle();

    expect(find.text('Dám si kávu.'), findsOneWidget);
    expect(find.text("I don't have a pen right now"), findsNothing);
    expect(results, isEmpty, reason: 'revealing does not end the step');

    await tester.tap(find.text('Corrected my notes'));
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    final counts = await NotebookStore().outcomeCounts();
    expect(counts[NotebookOutcome.corrected], 1);
  });

  testWidgets('"I don\'t have a pen right now" moves on and keeps the step '
      'for later', (
    tester,
  ) async {
    final results = await pump(tester, notebook);

    await tester.tap(find.text("I don't have a pen right now"));
    await tester.pumpAndSettle();

    expect(results, hasLength(1), reason: 'never blocks the lesson');
    final todos = await NotebookStore().todos();
    expect(todos.single.exerciseId, 6003);
    expect(todos.single.model.single.cz, 'Dám si kávu.');
  });

  testWidgets('with notes in the app, the learner types instead', (
    tester,
  ) async {
    await pump(tester, notebook, onPaper: false);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text("I don't have a pen right now"), findsNothing);
  });

  testWidgets('a lecture step shows its explanation, table and the mistake '
      'to avoid, then hands over to the check', (tester) async {
    final results = await pump(tester, lecture);

    // Slide by slide, as the learner turns them.
    bool seen(Finder finder) => finder.evaluate().isNotEmpty;
    var kicker = false, say = false, table = false, mistake = false;
    while (true) {
      kicker |= seen(find.text('LEARN · STEP 1 OF 2'));
      say |= seen(find.text('Feminine words ending in -a change -a to -u.'));
      table |= seen(find.text('kávu')) && seen(find.text('vodu'));
      mistake |= seen(find.textContaining('Dám si káva.', findRichText: true));
      if (!seen(find.byKey(SlideDeck.nextKey))) break;
      await tester.tap(find.byKey(SlideDeck.nextKey));
      await tester.pumpAndSettle();
    }
    expect([kicker, say, table, mistake], [true, true, true, true]);

    await tester.tap(find.text('Got it — check me'));
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

class _Settings extends SettingsNotifier {
  _Settings({required this.onPaper});

  final bool onPaper;

  @override
  AppSettings build() => AppSettings(notesOnPaper: onPaper);
}
