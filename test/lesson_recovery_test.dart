import 'dart:convert';

import 'package:czechify/data/services/lesson_checkpoint_store.dart';
import 'package:czechify/domain/engines/learning_loop_engine.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';
import 'package:czechify/domain/entities/flashcard.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:czechify/domain/repositories/vocabulary_repository.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/gamification_providers.dart';
import 'package:czechify/presentation/providers/lesson_providers.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lesson_session_harness.dart';

/// A lesson left part-way — by Leave, or by Android ending the app in the
/// background — reopens where it was. Each test uses a fresh container for
/// the reopen, so nothing carries over except what was saved on the device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer device({
    List<Exercise> exercises = _exercises,
    bool exam = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        curriculumRepositoryProvider.overrideWithValue(
          FakeCurriculumRepository(
            lesson: _lesson,
            unit: exam ? _examUnit : _unit,
            exercises: exercises,
          ),
        ),
        vocabularyRepositoryProvider.overrideWithValue(_NoVocabulary()),
        gamificationProvider.overrideWith(TestGamificationNotifier.new),
        settingsProvider.overrideWith(_Settings.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<LessonSessionNotifier> open(ProviderContainer container) async {
    final session = container.read(lessonSessionProvider.notifier);
    await session.loadLesson(_lesson.id);
    return session;
  }

  Future<void> answerAndMoveOn(LessonSessionNotifier session) async {
    await session.onExerciseAnswered(outcome: ExerciseOutcome.correct);
    await session.nextExercise();
  }

  test('reopening resumes at the same question with the same score', () async {
    final first = device();
    await answerAndMoveOn(await open(first));
    first.dispose();

    final second = device();
    await open(second);

    final state = second.read(lessonSessionProvider);
    expect(state.resumed, isTrue);
    expect(state.currentIndex, 1);
    expect(state.correctCount, 1);
    expect(state.totalXp, 10);
    expect(state.showFeedback, isFalse);
  });

  test('opening a lesson that was never started is not a resume', () async {
    final container = device();
    await open(container);

    final state = container.read(lessonSessionProvider);
    expect(state.resumed, isFalse);
    expect(state.currentIndex, 0);
  });

  test('a writing draft is saved shortly after typing stops', () async {
    final first = device();
    final session = await open(first);

    session.updateWritingDraft('Dobrý den, jmenuji se Eva.');
    // No explicit save: the pause after typing is what saves it.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    first.dispose();

    final second = device();
    await open(second);
    expect(
      second.read(lessonSessionProvider).writingDraft,
      'Dobrý den, jmenuji se Eva.',
    );
  });

  test('a missed question comes back with its feedback ladder intact', () async {
    final first = device();
    await (await open(first)).onExerciseAnswered(
      outcome: ExerciseOutcome.incorrect,
      explanation: 'Formal greeting',
      correctAnswer: 'Dobrý den',
    );
    first.dispose();

    final second = device();
    final session = await open(second);
    var state = second.read(lessonSessionProvider);
    expect(state.showFeedback, isTrue);
    expect(state.feedbackStep, FeedbackStep.signal);
    expect(state.canRetry, isTrue);
    expect(state.mistakeQueue, hasLength(1));

    await session.retryCurrentExercise();
    await session.onExerciseAnswered(outcome: ExerciseOutcome.incorrect);

    state = second.read(lessonSessionProvider);
    expect(
      state.feedbackStep,
      FeedbackStep.selfRepair,
      reason: 'the earlier miss still counts after reopening',
    );
    expect(state.mistakeQueue, hasLength(1));
  });

  test('finishing the lesson leaves nothing to resume', () async {
    final first = device();
    final session = await open(first);
    await answerAndMoveOn(session);
    await answerAndMoveOn(session);
    expect(first.read(lessonSessionProvider).isComplete, isTrue);
    first.dispose();

    expect(await LessonCheckpointStore().load(_lesson.id), isNull);
    final second = device();
    await open(second);
    expect(second.read(lessonSessionProvider).currentIndex, 0);
    expect(second.read(lessonSessionProvider).resumed, isFalse);
  });

  test('a lesson whose content changed starts over', () async {
    final first = device();
    await answerAndMoveOn(await open(first));
    first.dispose();

    final second = device(
      exercises: [
        _exercises.first,
        const Exercise(
          id: 2,
          lessonId: 7,
          type: ExerciseType.multipleChoice,
          prompt: 'Say goodbye politely',
          data: {
            'options': ['Na shledanou', 'Čau'],
            'correct_index': 0,
          },
        ),
      ],
    );
    await open(second);

    expect(second.read(lessonSessionProvider).currentIndex, 0);
    expect(second.read(lessonSessionProvider).resumed, isFalse);
    expect(await LessonCheckpointStore().load(_lesson.id), isNull);
  });

  test('a damaged checkpoint starts the lesson over and is removed', () async {
    final first = device();
    await answerAndMoveOn(await open(first));
    first.dispose();

    final prefs = await SharedPreferences.getInstance();
    final all =
        jsonDecode(prefs.getString(LessonCheckpointStore.preferenceKey)!)
            as Map<String, dynamic>;
    (all['${_lesson.id}'] as Map<String, dynamic>)['index'] = 99;
    await prefs.setString(LessonCheckpointStore.preferenceKey, jsonEncode(all));

    final second = device();
    await open(second);

    expect(second.read(lessonSessionProvider).currentIndex, 0);
    expect(second.read(lessonSessionProvider).correctCount, 0);
    expect(await LessonCheckpointStore().load(_lesson.id), isNull);
  });

  test('an exam is never saved for resuming', () async {
    final container = device(exam: true);
    await answerAndMoveOn(await open(container));

    expect(container.read(lessonSessionProvider).isExamMode, isTrue);
    expect(await LessonCheckpointStore().load(_lesson.id), isNull);
  });
}

const _lesson = Lesson(
  id: 7,
  unitId: 1,
  orderInUnit: 0,
  title: 'Greetings',
  description: '',
);

const _unit = Unit(
  id: 1,
  title: 'Unit 1',
  description: '',
  phase: Phase.a1,
  orderIndex: 1,
);

const _examUnit = Unit(
  id: 1,
  title: 'Mock exam',
  description: '',
  phase: Phase.a1,
  orderIndex: 1,
  isExamPrep: true,
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

/// No teach phase, and no database behind the lesson.
class _NoVocabulary implements VocabularyRepository {
  @override
  Future<List<Flashcard>> getCardsForLesson(int lessonId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}
