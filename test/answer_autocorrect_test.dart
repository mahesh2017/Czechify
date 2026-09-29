import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/widgets/common/lesson_ui.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/declension_table_view.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/dialogue_view.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/fill_blank_view.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/writing_task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';
import 'support/slides.dart';

/// Answers are typed in Czech on a phone set up for another language. With
/// autocorrect on, iOS turned "půjdu" into "hey" and "přijít v sedm" into
/// "profit v seem" as the learner typed, and the answer was marked wrong.
void main() {
  Future<void> host(WidgetTester tester, Widget child) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: lightTheme(),
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(body: SizedBox(height: 700, child: child)),
      ),
    ),
  );

  void expectNoAutocorrect(WidgetTester tester) {
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty);
    for (final field in fields) {
      expect(field.autocorrect, isFalse);
    }
  }

  testWidgets('the shared answer field', (tester) async {
    await host(tester, AnswerField(controller: TextEditingController()));
    expectNoAutocorrect(tester);
  });

  testWidgets('a fill-in gap', (tester) async {
    await host(
      tester,
      FillBlankView(
        exercise: const Exercise(
          id: 1,
          lessonId: 1,
          type: ExerciseType.fillBlank,
          prompt: 'Complete',
          data: {
            'sentence': 'Zítra ___ na výstavu.',
            'blank_answers': [
              ['půjdu'],
            ],
          },
        ),
        onAnswered: (_) {},
      ),
    );
    expectNoAutocorrect(tester);
  });

  testWidgets('a dialogue reply', (tester) async {
    await host(
      tester,
      DialogueView(
        exercise: const Exercise(
          id: 1,
          lessonId: 1,
          type: ExerciseType.dialogue,
          prompt: 'Reply',
          data: {
            'lines': [
              {'speaker': 'friend', 'text': 'Můžeš přijít v šest?'},
              {'speaker': 'you', 'text': '___'},
            ],
            'blank_answers': [
              ['Mohl bych přijít v sedm?'],
            ],
          },
        ),
        onAnswered: (_) {},
      ),
    );
    await toLastSlide(tester);
    expectNoAutocorrect(tester);
  });

  testWidgets('a declension table', (tester) async {
    await host(
      tester,
      DeclensionTableView(
        exercise: const Exercise(
          id: 1,
          lessonId: 1,
          type: ExerciseType.declensionTable,
          prompt: 'Fill the table',
          data: {
            'word': 'káva',
            'gender': 'f',
            'cases': ['nominative', 'accusative'],
            'answer_key': {'nominative': 'káva', 'accusative': 'kávu'},
          },
        ),
        onAnswered: (_) {},
      ),
    );
    expectNoAutocorrect(tester);
  });

  testWidgets('a writing page', (tester) async {
    await host(
      tester,
      WritingTaskView(
        exercise: const Exercise(
          id: 1,
          lessonId: 1,
          type: ExerciseType.writingTask,
          prompt: 'Write to your friend.',
          data: {'min_words': 2},
        ),
        onAnswered: (_) {},
      ),
    );
    await toLastSlide(tester);
    expectNoAutocorrect(tester);
  });
}
