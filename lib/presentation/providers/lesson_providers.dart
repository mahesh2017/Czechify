import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import '../../core/feedback/celebration.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/exercise_outcome.dart';
import '../../domain/entities/exercise_attempt_evidence.dart';
import '../../domain/entities/flashcard.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/learning_evidence.dart';
import '../../domain/engines/learning_loop_engine.dart';
import '../../domain/engines/unit_completion_detector.dart';
import 'curriculum_providers.dart';
import 'database_providers.dart';
import 'gamification_providers.dart';
import 'review_providers.dart';
import 'settings_providers.dart';

final _log = Logger('LessonSession');

/// State of a lesson session.
class LessonSessionState {
  final Lesson? lesson;
  final List<Exercise> exercises;
  final int currentIndex;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;
  final int hearts;
  final int totalXp;
  final bool isComplete;
  final bool isCompleting;
  final String? completionError;
  final bool isGameOver;
  final String? lastExplanation;
  final String? lastCorrectAnswer;
  final String? lastGrammarRuleId;
  final ExerciseOutcome? lastOutcome;
  final bool showFeedback;
  final FeedbackStep? feedbackStep;

  /// Exercises answered wrong during the main pass, re-asked at the end.
  final List<Exercise> mistakeQueue;

  /// True once the missed exercises have been appended for a review pass.
  final bool mistakesAppended;

  /// Number of exercises in the original lesson (before mistake re-asks),
  /// so the UI can tell when the learner is in the review-mistakes phase.
  final int originalCount;

  /// New vocabulary this lesson introduces, shown in the teach phase
  /// before exercises begin.
  final List<Flashcard> teachCards;

  /// True while the learner is browsing the new words, before practicing.
  final bool isTeaching;

  /// True when this lesson is part of an exam-prep unit.
  final bool isExamMode;

  /// Remaining seconds on the exam countdown timer.
  final int remainingSeconds;

  /// Consecutive correct answers right now.
  ///
  /// Drives the rising answer tone and the combo chip. A run is what stops
  /// answer #40 feeling identical to answer #4 — the same event has to pay
  /// out differently or it stops registering as a reward at all.
  final int answerStreak;

  /// The longest run in this session, kept for the completion screen.
  final int bestAnswerStreak;

  /// Badges and streak milestones earned by finishing this lesson.
  ///
  /// Held here rather than announced the moment they are awarded, because
  /// they are awarded *during* the commit — before the completion screen
  /// exists. Fired from there, they would arrive ahead of the lesson's own
  /// celebration and steal it.
  final List<Celebration> pendingRewards;

  /// Set when this lesson was the one that finished its unit.
  ///
  /// Nothing in the app detected this before: units were only ever read
  /// backwards, as "which are unlocked", so the moment a learner finished one
  /// passed without any acknowledgement at all.
  final UnitCompleted? unitJustCompleted;

  const LessonSessionState({
    this.lesson,
    this.exercises = const [],
    this.currentIndex = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.skippedCount = 0,
    this.hearts = 5,
    this.totalXp = 0,
    this.isComplete = false,
    this.isCompleting = false,
    this.completionError,
    this.isGameOver = false,
    this.lastExplanation,
    this.lastCorrectAnswer,
    this.lastGrammarRuleId,
    this.lastOutcome,
    this.showFeedback = false,
    this.feedbackStep,
    this.mistakeQueue = const [],
    this.mistakesAppended = false,
    this.originalCount = 0,
    this.teachCards = const [],
    this.isTeaching = false,
    this.isExamMode = false,
    this.remainingSeconds = 0,
    this.answerStreak = 0,
    this.bestAnswerStreak = 0,
    this.pendingRewards = const [],
    this.unitJustCompleted,
  });

  LessonSessionState copyWith({
    Lesson? lesson,
    List<Exercise>? exercises,
    int? currentIndex,
    int? correctCount,
    int? wrongCount,
    int? skippedCount,
    int? hearts,
    int? totalXp,
    bool? isComplete,
    bool? isCompleting,
    String? completionError,
    bool clearCompletionError = false,
    bool? isGameOver,
    String? lastExplanation,
    String? lastCorrectAnswer,
    String? lastGrammarRuleId,
    ExerciseOutcome? lastOutcome,
    bool clearFeedback = false,
    bool? showFeedback,
    FeedbackStep? feedbackStep,
    List<Exercise>? mistakeQueue,
    bool? mistakesAppended,
    int? originalCount,
    List<Flashcard>? teachCards,
    bool? isTeaching,
    bool? isExamMode,
    int? remainingSeconds,
    int? answerStreak,
    int? bestAnswerStreak,
    List<Celebration>? pendingRewards,
    UnitCompleted? unitJustCompleted,
  }) {
    return LessonSessionState(
      lesson: lesson ?? this.lesson,
      exercises: exercises ?? this.exercises,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      skippedCount: skippedCount ?? this.skippedCount,
      hearts: hearts ?? this.hearts,
      totalXp: totalXp ?? this.totalXp,
      isComplete: isComplete ?? this.isComplete,
      isCompleting: isCompleting ?? this.isCompleting,
      completionError:
          clearCompletionError ? null : completionError ?? this.completionError,
      isGameOver: isGameOver ?? this.isGameOver,
      lastExplanation:
          clearFeedback ? null : lastExplanation ?? this.lastExplanation,
      lastCorrectAnswer:
          clearFeedback ? null : lastCorrectAnswer ?? this.lastCorrectAnswer,
      lastGrammarRuleId:
          clearFeedback ? null : lastGrammarRuleId ?? this.lastGrammarRuleId,
      lastOutcome: clearFeedback ? null : lastOutcome ?? this.lastOutcome,
      showFeedback: showFeedback ?? this.showFeedback,
      feedbackStep: clearFeedback ? null : feedbackStep ?? this.feedbackStep,
      mistakeQueue: mistakeQueue ?? this.mistakeQueue,
      mistakesAppended: mistakesAppended ?? this.mistakesAppended,
      originalCount: originalCount ?? this.originalCount,
      teachCards: teachCards ?? this.teachCards,
      isTeaching: isTeaching ?? this.isTeaching,
      isExamMode: isExamMode ?? this.isExamMode,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      answerStreak: answerStreak ?? this.answerStreak,
      bestAnswerStreak: bestAnswerStreak ?? this.bestAnswerStreak,
      pendingRewards: pendingRewards ?? this.pendingRewards,
      unitJustCompleted: unitJustCompleted ?? this.unitJustCompleted,
    );
  }

  /// True when the learner is re-answering the questions they missed.
  bool get inMistakeReview => mistakesAppended && currentIndex >= originalCount;

  Exercise? get currentExercise =>
      currentIndex < exercises.length ? exercises[currentIndex] : null;

  double get progress =>
      exercises.isEmpty ? 0.0 : (currentIndex) / exercises.length;

  double get accuracy {
    final total = correctCount + wrongCount;
    if (total == 0) return 0.0;
    return correctCount / total;
  }

  int get totalExercises => exercises.length;

  bool get lastWasCorrect => lastOutcome == ExerciseOutcome.correct;
  bool get lastWasSkipped => lastOutcome == ExerciseOutcome.skipped;
}

/// Provider that manages a lesson session.
class LessonSessionNotifier extends Notifier<LessonSessionState> {
  static const _uuid = Uuid();
  int? _answerInFlightIndex;
  String? _attemptId;
  DateTime? _attemptStartedAt;
  String? _presentationId;
  DateTime? _presentationStartedAt;
  final List<ExerciseAttemptEvidence> _exerciseEvidence = [];
  final Map<int, int> _unsuccessfulAttempts = {};

  @override
  LessonSessionState build() => const LessonSessionState();

  /// Load a lesson and its exercises from the database.
  /// Hearts come from the global gamification state (regen applied first),
  /// so losses persist across lessons and refill over time.
  Future<void> loadLesson(int lessonId) async {
    _answerInFlightIndex = null;
    _attemptId = _uuid.v4();
    _attemptStartedAt = DateTime.now();
    _presentationId = _uuid.v4();
    _presentationStartedAt = DateTime.now();
    _exerciseEvidence.clear();
    _unsuccessfulAttempts.clear();
    state = const LessonSessionState();
    final gamification = ref.read(gamificationProvider.notifier);
    await gamification.refreshHearts();
    final hearts = ref.read(gamificationProvider).hearts;
    final heartsEnabled = ref.read(settingsProvider).heartsEnabled;

    final repo = ref.read(curriculumRepositoryProvider);
    final lesson = await repo.getLesson(lessonId);
    final unit = await repo.getUnit(lesson.unitId);
    final exercises = await repo.getExercises(lessonId);

    final isExamMode = unit.isExamPrep;
    final isReview = lesson.isReview;

    // Teach before testing: load the vocabulary this lesson introduces so
    // the player can present it before the first exercise.
    // Skip for review lessons — no new vocabulary.
    List<Flashcard> teachCards = const [];
    if (!isReview) {
      try {
        teachCards = await ref
            .read(vocabularyRepositoryProvider)
            .getCardsForLesson(lessonId);
      } catch (_) {
        // No vocab mapping — go straight to exercises.
      }
    }

    state = LessonSessionState(
      lesson: lesson,
      exercises: exercises,
      hearts: isExamMode ? 999 : hearts,
      isGameOver: !isExamMode && heartsEnabled && hearts <= 0,
      originalCount: exercises.length,
      teachCards: teachCards,
      isTeaching: !isReview && teachCards.isNotEmpty,
      isExamMode: isExamMode,
      remainingSeconds: isExamMode ? lesson.durationMinutes * 60 : 0,
    );
  }

  /// Leave the teach phase and start the exercises.
  void startExercises() {
    state = state.copyWith(isTeaching: false);
  }

  /// Called when the current exercise is answered.
  Future<void> onExerciseAnswered({
    required ExerciseOutcome outcome,
    String? explanation,
    String? correctAnswer,
    int xpEarned = 10,
    Set<SupportKind> supports = const {},
  }) async {
    final exercise = state.currentExercise;
    if (exercise == null) return;
    final answerIndex = state.currentIndex;
    if (state.showFeedback || _answerInFlightIndex == answerIndex) return;
    _answerInFlightIndex = answerIndex;
    final isCorrect = outcome == ExerciseOutcome.correct;
    final isIncorrect = outcome == ExerciseOutcome.incorrect;
    final isSkipped = outcome == ExerciseOutcome.skipped;
    final presentationId = _presentationId ??= _uuid.v4();

    var newHearts = state.hearts;
    final heartsEnabled = ref.read(settingsProvider).heartsEnabled;
    if (isIncorrect &&
        heartsEnabled &&
        !state.isExamMode &&
        !state.inMistakeReview) {
      // Deduct from the global hearts pool so the loss persists.
      newHearts = await ref.read(gamificationProvider.notifier).onWrongAnswer();
    }

    // During the main pass, remember wrong exercises so we can re-ask
    // them once at the end (only if there are hearts left to continue).
    var mistakeQueue = state.mistakeQueue;
    var exercises = state.exercises;
    FeedbackStep? feedbackStep;
    if (isIncorrect) {
      final priorFailures = _unsuccessfulAttempts[exercise.id] ?? 0;
      final loopState = const LearningLoopEngine().advance(
        LearningLoopState(
          phase:
              state.inMistakeReview
                  ? LearningPhase.repair
                  : LearningPhase.retrieve,
          unsuccessfulAttempts: priorFailures,
        ),
        correct: false,
        independent: supports.isEmpty,
        now: DateTime.now(),
      );
      _unsuccessfulAttempts[exercise.id] = loopState.unsuccessfulAttempts;
      feedbackStep = loopState.feedbackStep;
    }
    if (isIncorrect && !state.mistakesAppended) {
      mistakeQueue = [...state.mistakeQueue, exercise];
    } else if (isIncorrect &&
        state.inMistakeReview &&
        (_unsuccessfulAttempts[exercise.id] ?? 0) < 4) {
      exercises = [...state.exercises, exercise];
    }

    _exerciseEvidence.add(
      ExerciseAttemptEvidence(
        presentationId: presentationId,
        exerciseId: exercise.id,
        phase:
            state.inMistakeReview
                ? ExerciseEvidencePhase.immediateRepair
                : ExerciseEvidencePhase.initial,
        outcome: outcome,
        answeredAt: DateTime.now(),
      ),
    );
    final answeredAt = DateTime.now();
    try {
      if (ref.exists(databaseProvider)) {
        await ref
            .read(databaseProvider)
            .progressDao
            .recordLearningEvidence(
              LearningEvidence(
                evidenceId: 'lesson:$presentationId',
                lessonId: state.lesson?.id ?? exercise.lessonId,
                exerciseId: exercise.id,
                skill: _learningSkillFor(exercise.type),
                phase:
                    state.inMistakeReview
                        ? LearningPhase.repair
                        : LearningPhase.retrieve,
                correct: isCorrect,
                novelTask: false,
                supports: supports,
                conceptKeys: {
                  if (exercise.grammarRuleId case final key?) key,
                  ...?((exercise.data['concept_tags'] as List?)
                      ?.whereType<String>()),
                },
                responseLatency: answeredAt.difference(
                  _presentationStartedAt ?? answeredAt,
                ),
                observedAt: answeredAt,
              ),
            );
        ref.invalidate(learningEvidenceProvider);
      }
    } catch (error, stackTrace) {
      _log.fine(
        'Learning evidence will be recovered from lesson commit',
        error,
        stackTrace,
      );
    }

    // A run survives only on correct answers. Skipping breaks it too —
    // otherwise skipping every hard question would keep a streak alive, which
    // would reward avoiding exactly the work that teaches.
    final answerStreak = isCorrect ? state.answerStreak + 1 : 0;

    // Show feedback card
    state = state.copyWith(
      answerStreak: answerStreak,
      bestAnswerStreak:
          answerStreak > state.bestAnswerStreak
              ? answerStreak
              : state.bestAnswerStreak,
      correctCount: state.correctCount + (isCorrect ? 1 : 0),
      wrongCount: state.wrongCount + (isIncorrect ? 1 : 0),
      skippedCount: state.skippedCount + (isSkipped ? 1 : 0),
      hearts: newHearts,
      totalXp: state.totalXp + (isCorrect ? xpEarned : 0),
      lastExplanation:
          !isIncorrect || (_unsuccessfulAttempts[exercise.id] ?? 0) >= 3
              ? explanation
              : null,
      lastCorrectAnswer:
          !isIncorrect || (_unsuccessfulAttempts[exercise.id] ?? 0) >= 4
              ? correctAnswer
              : null,
      lastGrammarRuleId: exercise.grammarRuleId,
      lastOutcome: outcome,
      showFeedback: true,
      feedbackStep: feedbackStep,
      mistakeQueue: mistakeQueue,
      exercises: exercises,
    );
  }

  /// Advance to the next exercise or complete the lesson.
  Future<void> nextExercise() async {
    if (state.isCompleting) return;
    _answerInFlightIndex = null;
    // Check game over FIRST — even if the last question.
    // Skip in exam mode (no hearts).
    final heartsEnabled = ref.read(settingsProvider).heartsEnabled;
    if (!state.isExamMode && heartsEnabled && state.hearts <= 0) {
      state = state.copyWith(isGameOver: true);
      return;
    }

    final nextIndex = state.currentIndex + 1;

    if (nextIndex >= state.exercises.length) {
      // End of the current list. In exam mode, finish immediately.
      // Otherwise, re-ask mistakes once before finishing.
      if (!state.isExamMode &&
          !state.mistakesAppended &&
          state.mistakeQueue.isNotEmpty) {
        state = state.copyWith(
          exercises: [...state.exercises, ...state.mistakeQueue],
          currentIndex: nextIndex,
          showFeedback: false,
          clearFeedback: true,
          mistakesAppended: true,
        );
        _presentationId = _uuid.v4();
        _presentationStartedAt = DateTime.now();
        return;
      }
      // Lesson complete
      await _onLessonComplete();
      return;
    }

    state = state.copyWith(
      currentIndex: nextIndex,
      showFeedback: false,
      clearFeedback: true,
    );
    _presentationId = _uuid.v4();
    _presentationStartedAt = DateTime.now();
  }

  /// Retry the lesson from the beginning.
  /// Requires at least one heart — hearts persist across attempts.
  Future<void> retry() async {
    final gamification = ref.read(gamificationProvider.notifier);
    await gamification.refreshHearts();
    final hearts = ref.read(gamificationProvider).hearts;
    _attemptId = _uuid.v4();
    _attemptStartedAt = DateTime.now();
    _presentationId = _uuid.v4();
    _presentationStartedAt = DateTime.now();
    _exerciseEvidence.clear();
    _unsuccessfulAttempts.clear();

    // Restore the original exercise list (drop any appended mistake re-asks).
    final baseExercises =
        state.originalCount > 0 && state.originalCount <= state.exercises.length
            ? state.exercises.sublist(0, state.originalCount)
            : state.exercises;

    state = LessonSessionState(
      lesson: state.lesson,
      exercises: baseExercises,
      hearts: hearts,
      isGameOver: ref.read(settingsProvider).heartsEnabled && hearts <= 0,
      originalCount: baseExercises.length,
    );
  }

  /// Persist the attempt before showing success or awarding completion XP.
  Future<void> _onLessonComplete() async {
    final lesson = state.lesson;
    final attemptId = _attemptId;
    final startedAt = _attemptStartedAt;
    if (lesson == null || attemptId == null || startedAt == null) return;

    state = state.copyWith(isCompleting: true, clearCompletionError: true);
    final accuracy = state.accuracy;
    try {
      final gamification = ref.read(gamificationProvider.notifier);
      // The XP the learner watched climb is the XP that gets recorded. These
      // used to be two unrelated numbers: the HUD summed each exercise's
      // authored `xp_reward` while the database received a flat 10/15/20 by
      // accuracy, so a lesson that displayed 125 XP committed 20. Accuracy
      // still shapes the award, but through the answers it is computed from
      // rather than as a second, competing rule.
      final activityXp = state.totalXp;
      // Read before committing: this is what distinguishes finishing a unit
      // from replaying a lesson inside one that was already finished.
      final completedBefore =
          await ref.read(progressRepositoryProvider).getCompletedLessonIds();
      final committed = await ref
          .read(progressRepositoryProvider)
          .recordCompletion(
            attemptId: attemptId,
            unitId: lesson.unitId,
            lessonId: lesson.id,
            score: accuracy,
            correctCount: state.correctCount,
            incorrectCount: state.wrongCount,
            skippedCount: state.skippedCount,
            startedAt: startedAt,
            activityXp: activityXp,
            exerciseEvidence: List.unmodifiable(_exerciseEvidence),
          );

      final rewards =
          committed
              ? await gamification.refreshAfterCommittedLesson()
              : const <Celebration>[];
      ref.invalidate(completedLessonIdsProvider);
      ref.invalidate(dueCardCountProvider);
      state = state.copyWith(
        isCompleting: false,
        isComplete: true,
        pendingRewards: rewards,
        unitJustCompleted: await _unitFinishedBy(lesson, completedBefore),
      );
    } catch (error, stackTrace) {
      _log.warning('Failed to commit lesson completion', error, stackTrace);
      state = state.copyWith(
        isCompleting: false,
        completionError: 'Couldn’t save this attempt. Please try again.',
      );
    }
  }

  /// The unit this lesson just finished, or null if it did not finish one.
  ///
  /// Only gathers the inputs; the decision itself lives in
  /// [UnitCompletionDetector], where it can be tested without a database.
  Future<UnitCompleted?> _unitFinishedBy(
    Lesson lesson,
    Set<int> completedBefore,
  ) async {
    if (completedBefore.contains(lesson.id)) return null;
    try {
      final curriculum = ref.read(curriculumRepositoryProvider);
      final unit = await curriculum.getUnit(lesson.unitId);
      final milestone = const UnitCompletionDetector().evaluate(
        lesson: lesson,
        unit: unit,
        unitLessons: await curriculum.getLessons(lesson.unitId),
        phaseUnits: await curriculum.getUnits(unit.phase),
        completedBefore: completedBefore,
        completedNow:
            await ref.read(progressRepositoryProvider).getCompletedLessonIds(),
      );
      if (milestone == null) return null;

      return UnitCompleted(
        unitId: milestone.unitId,
        unitNumber: milestone.number,
        unitTitle: milestone.title,
        nextUnitTitle: milestone.nextTitle,
      );
    } catch (error, stackTrace) {
      // A missed celebration must never cost the learner their progress,
      // which is already committed by this point.
      _log.fine('Could not evaluate unit completion', error, stackTrace);
      return null;
    }
  }
}

/// Provider for the lesson session.
final lessonSessionProvider =
    NotifierProvider<LessonSessionNotifier, LessonSessionState>(
      LessonSessionNotifier.new,
    );

LearningSkill _learningSkillFor(ExerciseType type) => switch (type) {
  ExerciseType.readingComprehension => LearningSkill.reading,
  ExerciseType.listening ||
  ExerciseType.listeningComprehension ||
  ExerciseType.dictation => LearningSkill.listening,
  ExerciseType.writingTask || ExerciseType.translation => LearningSkill.writing,
  ExerciseType.speakingTask ||
  ExerciseType.pronunciation ||
  ExerciseType.dialogue => LearningSkill.speaking,
  ExerciseType.matching => LearningSkill.vocabulary,
  _ => LearningSkill.grammar,
};
