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

import 'support/pilot_units.dart';
import 'support/lesson_session_harness.dart';

/// Warm-up guesses, lecture checks and guided practice are teaching, not
/// testing (plan v1.2, decision 1). A miss there costs no heart, is not
/// re-asked in the mistake pass and shows its answer at once; only guided
/// practice earns XP. Scored items behave exactly as before.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ({ProviderContainer container, LessonSessionNotifier session, _Hearts hearts})
  start(String? mode) {
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        curriculumRepositoryProvider.overrideWithValue(
          FakeCurriculumRepository(),
        ),
        gamificationProvider.overrideWith(_Hearts.new),
        settingsProvider.overrideWith(_Settings.new),
        lessonSessionProvider.overrideWith(() => _Session(mode)),
      ],
    );
    addTearDown(container.dispose);
    return (
      container: container,
      session: container.read(lessonSessionProvider.notifier),
      hearts: container.read(gamificationProvider.notifier) as _Hearts,
    );
  }

  Future<void> answer(LessonSessionNotifier session, ExerciseOutcome outcome) =>
      session.onExerciseAnswered(
        outcome: outcome,
        explanation: 'Feminine -a becomes -u: kávu.',
        correctAnswer: 'kávu',
        xpEarned: 5,
      );

  test('ExerciseMode reads data.mode and treats anything else as scored', () {
    expect(ExerciseMode.fromData('guided'), ExerciseMode.guided);
    expect(ExerciseMode.fromData('check'), ExerciseMode.check);
    expect(ExerciseMode.fromData('predict'), ExerciseMode.predict);
    expect(ExerciseMode.fromData(null), ExerciseMode.scored);
    // A typo in content must never switch hearts off for a question.
    expect(ExerciseMode.fromData('guidded'), ExerciseMode.scored);
    expect(ExerciseMode.fromData(3), ExerciseMode.scored);
  });

  for (final mode in ['guided', 'check', 'predict']) {
    test('a missed $mode item costs no heart, is not re-asked and shows '
        'its answer at once', () async {
      final t = start(mode);

      await answer(t.session, ExerciseOutcome.incorrect);

      final state = t.container.read(lessonSessionProvider);
      expect(t.hearts.lost, 0);
      expect(state.hearts, 5);
      expect(state.mistakeQueue, isEmpty);
      expect(state.wrongCount, 0, reason: 'not part of the lesson score');
      expect(state.lastExplanation, 'Feminine -a becomes -u: kávu.');
      expect(state.lastCorrectAnswer, 'kávu');
      expect(state.feedbackStep, isNull);
      expect(state.canRetry, isFalse);
      expect(state.showFeedback, isTrue);
    });
  }

  test('a wrong guess does not break the answer streak', () async {
    final t = start('predict');
    t.session.state = t.session.state.copyWith(answerStreak: 4);

    await answer(t.session, ExerciseOutcome.incorrect);

    expect(t.container.read(lessonSessionProvider).answerStreak, 4);
  });

  test('only guided practice earns XP', () async {
    final guided = start('guided');
    await answer(guided.session, ExerciseOutcome.correct);
    expect(guided.container.read(lessonSessionProvider).totalXp, 5);

    for (final mode in ['check', 'predict']) {
      final t = start(mode);
      await answer(t.session, ExerciseOutcome.correct);
      final state = t.container.read(lessonSessionProvider);
      expect(state.totalXp, 0, reason: mode);
      expect(state.correctCount, 0, reason: mode);
    }
  });

  test('a scored miss still costs a heart and climbs the ladder', () async {
    final t = start(null);

    await answer(t.session, ExerciseOutcome.incorrect);

    final state = t.container.read(lessonSessionProvider);
    expect(t.hearts.lost, 1);
    expect(state.mistakeQueue, hasLength(1));
    expect(state.feedbackStep, FeedbackStep.signal);
    expect(state.lastCorrectAnswer, isNull);
    expect(state.canRetry, isTrue);
  });
}

class _Session extends LessonSessionNotifier {
  _Session(this.mode);

  final String? mode;

  @override
  LessonSessionState build() {
    final exercises = [
      Exercise(
        id: 1,
        lessonId: outsidePilotLesson(1),
        type: ExerciseType.fillBlank,
        prompt: 'Dám si ___.',
        data: {'type': 'fill_blank', if (mode != null) 'mode': mode},
      ),
    ];
    return LessonSessionState(
      lesson: Lesson(
        id: outsidePilotLesson(1),
        unitId: outsidePilotUnit,
        orderInUnit: 1,
        title: 'Choose the useful object form',
        description: '',
        durationMinutes: 12,
        lessonType: LessonType.practice,
      ),
      exercises: exercises,
      originalCount: exercises.length,
      hearts: 5,
    );
  }
}

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
