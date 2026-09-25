import 'dart:math' as math;

import 'package:czechify/core/config/unit_guide_pilot.dart';
import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/engines/learning_loop_engine.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/presentation/providers/course_admission_providers.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/lesson_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/screens/grammar/unit_notebook_screen.dart';
import 'package:czechify/presentation/screens/lesson/lesson_player_screen.dart';
import 'package:czechify/presentation/widgets/common/lesson_ui.dart';
import 'package:czechify/presentation/widgets/lesson/lesson_exercise_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';
import 'support/shipped_exercises.dart';

/// In the pilot, answer feedback is laid over the exercise instead of pushing
/// it up, so a learner never scrolls to see their marked answer.
///
/// Every scored exercise of the pilot units is shown in the real lesson
/// screen on an iPhone SE, with the feedback a first miss gets (the prompt,
/// Try again and the rule link) and the feedback a right answer gets. Before
/// the sheet was laid over, it took 235-373 pt and 37 of Unit 2's 38 scored
/// exercises had to scroll after a miss.
void main() {
  /// A first miss with the rule link, the tallest common sheet, used to be
  /// about 287 pt.
  const missLimit = 200.0;

  /// A right answer's sheet grows with its explanation, which is content: up
  /// to three lines of it fit this.
  const rightLimit = 240.0;

  /// Folded down: the verdict and Continue.
  const foldedLimit = 100.0;

  setUpAll(() async {
    for (final font in {
      'Bricolage Grotesque': 'BricolageGrotesque',
      'Schibsted Grotesk': 'SchibstedGrotesk',
    }.entries) {
      await (FontLoader(font.key)
        ..addFont(rootBundle.load('assets/fonts/${font.value}.ttf'))).load();
    }
  });

  final scored =
      loadShippedExercises()
          .where(
            (e) =>
                unitGuideEnabled(unitOfLesson(e.lessonId)) &&
                e.type != ExerciseType.teaching &&
                // Always handed in unscored, so never a miss.
                e.type != ExerciseType.writingTask,
          )
          .toList();

  Future<void> open(
    WidgetTester tester,
    Exercise exercise, {
    required bool feedback,
    required bool correct,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final lesson = Lesson(
      id: exercise.lessonId,
      unitId: unitOfLesson(exercise.lessonId),
      orderInUnit: exercise.lessonId % 100 - 1,
      title: 'Lesson',
      description: '',
    );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          lessonSessionProvider.overrideWith(
            () => _Session(
              lesson,
              exercise,
              feedback: feedback,
              correct: correct,
            ),
          ),
          lessonAdmissionProvider(
            exercise.lessonId,
          ).overrideWith((_) async => LessonAdmission.allowed),
          czechTtsProvider.overrideWithValue(_Tts()),
          unitLessonsProvider(lesson.unitId).overrideWith((_) async => [lesson]),
          unitLectureStepsProvider(
            lesson.unitId,
          ).overrideWith((_) async => const []),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
          home: LessonPlayerScreen(lessonId: exercise.lessonId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
  }

  testWidgets('the feedback sheet lies over the exercise without moving it, '
      'stays short, and folds down to show the whole answered exercise', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 20);
    addTearDown(tester.view.reset);
    expect(scored, isNotEmpty);

    final problems = <String>[];
    var tallest = 0.0;
    for (final exercise in scored) {
      await open(tester, exercise, feedback: false, correct: false);
      final viewport = find.byType(LessonExerciseViewport);
      final before = tester.getRect(viewport);

      for (final correct in [false, true]) {
        final label = '${exercise.id} ${correct ? 'right' : 'first miss'}';
        await open(tester, exercise, feedback: true, correct: correct);
        final sheet = find.byType(FeedbackSheet);

        if (tester.getRect(viewport) != before) {
          problems.add('$label: the exercise moved when the sheet appeared');
        }
        final height = tester.getSize(sheet).height;
        tallest = math.max(tallest, height);
        if (height > (correct ? rightLimit : missLimit)) {
          problems.add('$label: sheet ${height.round()} pt');
        }

        await tester.tap(find.byKey(FeedbackSheet.foldKey));
        await tester.pumpAndSettle();
        final folded = tester.getRect(sheet);
        if (folded.height > foldedLimit) {
          problems.add('$label: folded sheet ${folded.height.round()} pt');
        }
        // Nothing of the exercise may be left under the folded sheet.
        // Buttons are left out: a real answer finishes the exercise and
        // takes its Check or Next away, and this test shows the sheet
        // without answering.
        final buttons = find.descendant(
          of: viewport,
          matching: find.byWidgetPredicate(
            (w) => w is KeyCta || w is ButtonStyleButton,
          ),
        );
        final inButtons = find
            .descendant(of: buttons, matching: find.byType(Text))
            .evaluate()
            .toSet();
        for (final text in find
            .descendant(of: viewport, matching: find.byType(Text))
            .evaluate()
            .where((e) => !inButtons.contains(e))) {
          final box = text.renderObject! as RenderBox;
          if (!box.attached || !box.hasSize || box.size.isEmpty) continue;
          final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
          if (bottom > folded.top + 0.5) {
            problems.add(
              '$label: "${(text.widget as Text).data}" is under the folded '
              'sheet',
            );
            break;
          }
        }
        expect(tester.takeException(), isNull, reason: label);
      }
    }
    await tester.pumpWidget(const SizedBox());

    expect(problems, isEmpty, reason: 'tallest sheet ${tallest.round()} pt');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('a first miss offers Try again beside Continue and the rule as '
      'an icon; folding is remembered only for that question', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final withRule = scored.firstWhere((e) => e.grammarRuleId != null);
    await open(tester, withRule, feedback: true, correct: false);

    final tryAgain = find.byKey(FeedbackSheet.secondaryKey);
    expect(tryAgain, findsOneWidget);
    expect(
      tester.getCenter(tryAgain).dy,
      moreOrLessEquals(tester.getCenter(find.text('Continue')).dy, epsilon: 1),
      reason: 'Try again sits beside Continue',
    );
    expect(find.byKey(FeedbackSheet.titleActionKey), findsOneWidget);
    expect(find.text('View grammar rule'), findsNothing);

    await tester.tap(find.byKey(FeedbackSheet.foldKey));
    await tester.pumpAndSettle();
    expect(find.byKey(FeedbackSheet.secondaryKey), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.byKey(FeedbackSheet.foldKey));
    await tester.pumpAndSettle();
    expect(find.byKey(FeedbackSheet.secondaryKey), findsOneWidget);
  });
}

class _Session extends LessonSessionNotifier {
  _Session(
    this.lesson,
    this.exercise, {
    required this.feedback,
    required this.correct,
  });
  final Lesson lesson;
  final Exercise exercise;
  final bool feedback;
  final bool correct;

  @override
  LessonSessionState build() => LessonSessionState(
    lesson: lesson,
    // A second item, so the sheet says Continue rather than Finish.
    exercises: [exercise, exercise],
    showFeedback: feedback,
    lastOutcome:
        !feedback
            ? null
            : correct
            ? ExerciseOutcome.correct
            : ExerciseOutcome.incorrect,
    // What the lesson shows: a right answer's explanation; on a first miss
    // only the step's prompt, with Try again and the rule link.
    lastExplanation: correct ? exercise.data['explanation'] as String? : null,
    lastGrammarRuleId: feedback ? exercise.grammarRuleId : null,
    feedbackStep: feedback && !correct ? FeedbackStep.signal : null,
  );

  @override
  Future<void> loadLesson(int lessonId) async {}
}

class _Tts implements CzechTts {
  @override
  final usingFallbackVoice = ValueNotifier(false);
  @override
  Future<void> speak(String text, {double? rate}) async {}
  @override
  Future<void> speakSlow(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
