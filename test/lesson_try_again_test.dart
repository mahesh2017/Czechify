import 'package:czechify/domain/engines/learning_loop_engine.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/gamification_providers.dart';
import 'package:czechify/presentation/providers/lesson_providers.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lesson_session_harness.dart';

/// "Try again" sits on top of the feedback ladder rather than replacing it:
/// every retry is a real attempt that costs a heart, the explanation and the
/// answer still arrive only on the third and fourth miss, and the offer ends
/// once the answer has been shown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ({ProviderContainer container, LessonSessionNotifier session, _Hearts hearts})
  start({
    int hearts = 5,
    bool examMode = false,
    bool inMistakePass = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        curriculumRepositoryProvider.overrideWithValue(
          FakeCurriculumRepository(),
        ),
        gamificationProvider.overrideWith(_Hearts.new),
        settingsProvider.overrideWith(_Settings.new),
        lessonSessionProvider.overrideWith(
          () => _Session(
            hearts: hearts,
            examMode: examMode,
            inMistakePass: inMistakePass,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (
      container: container,
      session: container.read(lessonSessionProvider.notifier),
      hearts: container.read(gamificationProvider.notifier) as _Hearts,
    );
  }

  Future<void> miss(LessonSessionNotifier session) => session.onExerciseAnswered(
    outcome: ExerciseOutcome.incorrect,
    explanation: 'Greetings take the formal form here.',
    correctAnswer: 'Dobrý den',
  );

  test('a miss offers Try again without giving the answer away', () async {
    final t = start();

    await miss(t.session);

    final state = t.container.read(lessonSessionProvider);
    expect(state.canRetry, isTrue);
    expect(state.feedbackStep, FeedbackStep.signal);
    expect(state.lastExplanation, isNull);
    expect(state.lastCorrectAnswer, isNull);
    expect(t.hearts.lost, 1);
  });

  test('Try again re-asks the same question, and missing it again costs '
      'another heart', () async {
    final t = start();
    await miss(t.session);

    await t.session.retryCurrentExercise();

    var state = t.container.read(lessonSessionProvider);
    expect(state.showFeedback, isFalse);
    expect(state.currentIndex, 0, reason: 'the same question, not the next');
    expect(state.exercises, hasLength(2), reason: 'no copy is inserted');
    expect(state.retrySeq, 1, reason: 'the question is rebuilt fresh');
    expect(state.lastOutcome, isNull);

    await miss(t.session);

    state = t.container.read(lessonSessionProvider);
    expect(t.hearts.lost, 2);
    expect(state.hearts, 3);
    expect(state.feedbackStep, FeedbackStep.selfRepair);
    expect(
      state.mistakeQueue,
      hasLength(1),
      reason: 'missed twice, but it comes back once in the mistake pass',
    );
  });

  test('the ladder explains on the third miss, answers on the fourth, and '
      'then stops offering Try again', () async {
    final t = start();

    await miss(t.session);
    await t.session.retryCurrentExercise();
    await miss(t.session);
    await t.session.retryCurrentExercise();
    await miss(t.session);

    var state = t.container.read(lessonSessionProvider);
    expect(state.feedbackStep, FeedbackStep.cue);
    expect(state.lastExplanation, 'Greetings take the formal form here.');
    expect(state.lastCorrectAnswer, isNull);
    expect(state.canRetry, isTrue);

    await t.session.retryCurrentExercise();
    await miss(t.session);

    state = t.container.read(lessonSessionProvider);
    expect(state.feedbackStep, FeedbackStep.explanation);
    expect(state.lastCorrectAnswer, 'Dobrý den');
    expect(state.canRetry, isFalse, reason: 'retrying now is only copying');
    expect(t.hearts.lost, 4);

    await t.session.retryCurrentExercise();
    expect(
      t.container.read(lessonSessionProvider).showFeedback,
      isTrue,
      reason: 'a retry that is not offered does nothing',
    );
  });

  test('getting it right on Try again moves on as normal', () async {
    final t = start();
    await miss(t.session);
    await t.session.retryCurrentExercise();

    await t.session.onExerciseAnswered(outcome: ExerciseOutcome.correct);

    var state = t.container.read(lessonSessionProvider);
    expect(state.canRetry, isFalse);
    expect(state.correctCount, 1);
    expect(state.wrongCount, 1);

    await t.session.nextExercise();
    state = t.container.read(lessonSessionProvider);
    expect(state.currentIndex, 1);
    expect(state.showFeedback, isFalse);
  });

  test('with no hearts left, Try again ends the lesson instead', () async {
    final t = start(hearts: 1);
    await miss(t.session);
    expect(t.container.read(lessonSessionProvider).hearts, 0);

    await t.session.retryCurrentExercise();

    expect(t.container.read(lessonSessionProvider).isGameOver, isTrue);
  });

  test('an exam never offers Try again', () async {
    final t = start(examMode: true);

    await miss(t.session);
    await t.session.retryCurrentExercise();

    final state = t.container.read(lessonSessionProvider);
    expect(state.canRetry, isFalse);
    expect(state.showFeedback, isTrue);
    expect(t.hearts.lost, 0);
  });

  test('the mistake pass re-asks on its own and offers no Try again', () async {
    final t = start(inMistakePass: true);

    await miss(t.session);

    expect(t.container.read(lessonSessionProvider).canRetry, isFalse);
    expect(t.hearts.lost, 0, reason: 'the mistake pass is free');
  });
}

const _lesson = Lesson(
  id: 7,
  unitId: 1,
  orderInUnit: 0,
  title: 'Greetings',
  description: '',
);

const _exercises = [
  Exercise(
    id: 1,
    lessonId: 7,
    type: ExerciseType.multipleChoice,
    prompt: 'Greet a stranger',
    data: {
      'options': ['Ahoj', 'Dobrý den'],
      'correct_index': 1,
    },
  ),
  Exercise(
    id: 2,
    lessonId: 7,
    type: ExerciseType.multipleChoice,
    prompt: 'Say goodbye',
    data: {
      'options': ['Na shledanou', 'Dobrý den'],
      'correct_index': 0,
    },
  ),
];

class _Session extends LessonSessionNotifier {
  _Session({
    required this.hearts,
    required this.examMode,
    required this.inMistakePass,
  });

  final int hearts;
  final bool examMode;
  final bool inMistakePass;

  @override
  LessonSessionState build() => LessonSessionState(
    lesson: _lesson,
    exercises: inMistakePass ? [..._exercises, _exercises.first] : _exercises,
    originalCount: _exercises.length,
    currentIndex: inMistakePass ? _exercises.length : 0,
    mistakesAppended: inMistakePass,
    hearts: examMode ? 999 : hearts,
    isExamMode: examMode,
  );
}

/// Counts the hearts a session takes, starting from the session's own pool.
class _Hearts extends TestGamificationNotifier {
  int lost = 0;

  @override
  Future<int> onWrongAnswer() async {
    lost++;
    return ref.read(lessonSessionProvider).hearts - 1;
  }
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}
