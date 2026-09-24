import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/presentation/providers/course_admission_providers.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/lesson_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/screens/grammar/unit_notebook_screen.dart';
import 'package:czechify/presentation/screens/lesson/lesson_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

/// The Unit 2 pilot's lesson frame: a start screen carries the lesson's title,
/// goal and contents once, so the exercise screens keep only a slim bar.
void main() {
  const lesson = Lesson(
    id: 202,
    unitId: 2,
    orderInUnit: 1,
    title: 'Names: Ask and Answer',
    description: '',
  );
  Future<void> pump(WidgetTester tester, {int at = 0}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lessonSessionProvider.overrideWith(() => _Session(at)),
          lessonAdmissionProvider(
            202,
          ).overrideWith((_) async => LessonAdmission.allowed),
          czechTtsProvider.overrideWithValue(_Tts()),
          unitLessonsProvider(2).overrideWith((_) async => const [lesson]),
          unitLectureStepsProvider(2).overrideWith((_) async => const []),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: const LessonPlayerScreen(lessonId: 202),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the lesson opens on its start screen, then the rule has the '
      'screen to itself', (tester) async {
    await pump(tester);

    expect(find.text('LESSON B · UNIT 2'), findsOneWidget);
    expect(find.text('Names: Ask and Answer'), findsOneWidget);
    expect(find.textContaining('carry on'), findsNothing);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    // The rule, with no lesson title or "Introduction" above it.
    expect(find.text('Call a man pane.'), findsOneWidget);
    expect(find.text('Names: Ask and Answer'), findsNothing);
    expect(find.text('INTRODUCTION'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a resumed lesson says where it carries on; a check question '
      'says in full that it costs no hearts', (tester) async {
    await pump(tester, at: 1);

    expect(find.text("You'll carry on from question 2 of 2."), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final label = find.text('CHECK · NO HEARTS');
    expect(label, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
      isFalse,
      reason: 'the label is cut short next to the Rule button',
    );
    expect(find.text('Rule'), findsOneWidget);
  });
}

class _Session extends LessonSessionNotifier {
  _Session(this.at);
  final int at;

  @override
  LessonSessionState build() => LessonSessionState(
    lesson: const Lesson(
      id: 202,
      unitId: 2,
      orderInUnit: 1,
      title: 'Names: Ask and Answer',
      description: '',
    ),
    exercises: const [
      Exercise(
        id: 2201,
        lessonId: 202,
        type: ExerciseType.teaching,
        prompt: 'Lecture',
        data: {
          'style': 'lecture',
          'heading': 'Speaking to someone',
          'say': 'Call a man pane.',
          'table': [
            ['Mr Novák', 'pane Nováku!'],
          ],
          'examples': [],
          'items': [],
        },
      ),
      Exercise(
        id: 2202,
        lessonId: 202,
        type: ExerciseType.multipleChoice,
        prompt: 'Dear Mr Novák,',
        data: {
          'mode': 'check',
          'options': ['pane Nováku', 'pan Novák'],
          'correct_index': 0,
        },
      ),
    ],
    currentIndex: at,
    resumed: at > 0,
  );

  @override
  Future<void> loadLesson(int lessonId) async {}
}

class _Tts implements CzechTts {
  @override
  final usingFallbackVoice = ValueNotifier(false);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
