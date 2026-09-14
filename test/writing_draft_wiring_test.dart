import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/widgets/lesson/lesson_exercise_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// The draft plumbing runs player → viewport → exercise widget → writing
/// task. It was first written with the provider end in place and nothing
/// passing the draft down, so learners' text was never saved at all.
void main() {
  const writing = Exercise(
    id: 1,
    lessonId: 1,
    type: ExerciseType.writingTask,
    prompt: 'Introduce yourself',
    data: {'prompt_en': 'Introduce yourself', 'min_words': 3},
  );

  Future<void> pump(
    WidgetTester tester, {
    required String initialDraft,
    required ValueChanged<String> onDraftChanged,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: LessonExerciseViewport(
              exercise: writing,
              onAnswered: (_) {},
              initialDraft: initialDraft,
              onDraftChanged: onDraftChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a writing task opens with its saved draft', (tester) async {
    final drafts = <String>[];
    await pump(
      tester,
      initialDraft: 'Dobrý den, jmenuji se Eva.',
      onDraftChanged: drafts.add,
    );

    expect(
      find.widgetWithText(TextField, 'Dobrý den, jmenuji se Eva.'),
      findsOneWidget,
    );
    expect(drafts, isEmpty, reason: 'restoring is not an edit');
  });

  testWidgets('typing in a writing task reports the draft', (tester) async {
    final drafts = <String>[];
    await pump(tester, initialDraft: '', onDraftChanged: drafts.add);

    await tester.enterText(find.byType(TextField), 'Bydlím v Praze.');
    await tester.pump();

    expect(drafts.last, 'Bydlím v Praze.');
  });
}
