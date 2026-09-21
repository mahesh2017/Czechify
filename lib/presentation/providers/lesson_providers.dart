import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import '../../core/feedback/celebration.dart';
import '../../data/services/lesson_checkpoint_store.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/exercise_outcome.dart';
import '../../domain/entities/exercise_attempt_evidence.dart';
import '../../domain/entities/flashcard.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/learning_evidence.dart';
import '../../domain/engines/learning_loop_engine.dart';
import '../../domain/engines/unit_completion_detector.dart';
import '../../domain/entities/course_catalog.dart';
import '../../domain/entities/pending_referral_receipt.dart';
import '../../domain/entities/referral_receipt.dart';
import 'curriculum_providers.dart';
import 'database_providers.dart';
import 'gamification_providers.dart';
import 'referral_providers.dart';
import 'review_providers.dart';
import 'settings_providers.dart';
import 'sync_providers.dart';

final _log = Logger('LessonSession');

/// Where an unfinished lesson's position is kept on this device.
final lessonCheckpointStoreProvider = Provider<LessonCheckpointStore>(
  (ref) => LessonCheckpointStore(),
);

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

  /// Text the learner had typed into a writing task when the lesson was last
  /// saved. Read only when the task's field is built; typing after that is
  /// held by the notifier, so a keystroke does not rebuild the player.
  final String writingDraft;

  /// True while showing the question a saved lesson was reopened at.
  final bool resumed;

  /// True when the last attempt to save the lesson's position failed.
  final bool saveFailed;

  /// Bumped by "Try again" so the same question is built afresh, with none of
  /// the previous answer's selections left in place.
  final int retrySeq;

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
    this.writingDraft = '',
    this.resumed = false,
    this.saveFailed = false,
    this.retrySeq = 0,
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
    String? writingDraft,
    bool? resumed,
    bool? saveFailed,
    int? retrySeq,
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
      writingDraft: writingDraft ?? this.writingDraft,
      resumed: resumed ?? this.resumed,
      saveFailed: saveFailed ?? this.saveFailed,
      retrySeq: retrySeq ?? this.retrySeq,
    );
  }

  /// True when the learner is re-answering the questions they missed.
  bool get inMistakeReview => mistakesAppended && currentIndex >= originalCount;

  Exercise? get currentExercise =>
      currentIndex < exercises.length ? exercises[currentIndex] : null;

  /// How far through the lesson proper the learner is, 0..1.
  ///
  /// Measured against [originalCount], not `exercises.length`: the list grows
  /// when missed questions are appended, so dividing by it sent this
  /// backwards — 10/10 became 10/13 the moment the re-ask pass began. The
  /// mistake pass is extra work after a finished lesson, so this saturates at
  /// 1.0 rather than pretending there is more of the lesson left.
  ///
  /// Nothing renders this today; the header shows [inMistakeReview] and
  /// "Question x of y" instead. Kept correct so wiring it up cannot
  /// reintroduce the reversal.
  double get progress {
    final total = originalCount > 0 ? originalCount : exercises.length;
    if (total == 0) return 0.0;
    return (currentIndex / total).clamp(0.0, 1.0);
  }

  double get accuracy {
    final total = correctCount + wrongCount;
    if (total == 0) return 0.0;
    return correctCount / total;
  }

  int get totalExercises => exercises.length;

  bool get lastWasCorrect => lastOutcome == ExerciseOutcome.correct;
  bool get lastWasSkipped => lastOutcome == ExerciseOutcome.skipped;

  /// Whether the feedback for a wrong answer offers "Try again".
  ///
  /// Only on the main pass of a normal lesson, where a miss costs a heart —
  /// the mistake pass already re-asks, and for free. The offer ends once the
  /// ladder reaches the full explanation and answer: trying again after that
  /// would only be copying, so the question returns in the mistake pass.
  bool get canRetry =>
      showFeedback &&
      !isExamMode &&
      !inMistakeReview &&
      lastOutcome == ExerciseOutcome.incorrect &&
      feedbackStep != null &&
      feedbackStep != FeedbackStep.explanation;
}

/// Provider that manages a lesson session.
class LessonSessionNotifier extends Notifier<LessonSessionState> {
  static const _uuid = Uuid();
  static const _draftSaveDelay = Duration(milliseconds: 800);
  int? _answerInFlightIndex;
  String? _attemptId;
  DateTime? _attemptStartedAt;
  String? _presentationId;
  DateTime? _presentationStartedAt;
  final List<ExerciseAttemptEvidence> _exerciseEvidence = [];
  final Map<int, int> _unsuccessfulAttempts = {};

  /// The referral claim held when this attempt began, and its account. Only
  /// an attempt started under a claim can become referral evidence.
  String? _referralClaimId;
  String? _referralAccountId;

  /// The loaded exercises, fingerprinted. A saved position is only restored
  /// into the same content; an update that changes the lesson discards it.
  String _contentSignature = '';

  /// The writing task's live text. Kept out of [state] so typing does not
  /// rebuild the player, and saved a moment after the learner stops typing.
  String _writingDraft = '';
  Timer? _draftSave;

  @override
  LessonSessionState build() {
    ref.onDispose(() => _draftSave?.cancel());
    return const LessonSessionState();
  }

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
    _draftSave?.cancel();
    _writingDraft = '';
    state = const LessonSessionState();
    final gamification = ref.read(gamificationProvider.notifier);
    await gamification.refreshHearts();
    final hearts = ref.read(gamificationProvider).hearts;
    final heartsEnabled = ref.read(settingsProvider).heartsEnabled;

    final repo = ref.read(curriculumRepositoryProvider);
    final lesson = await repo.getLesson(lessonId);
    final unit = await repo.getUnit(lesson.unitId);
    final exercises = await repo.getExercises(lessonId);

    _contentSignature = jsonEncode([
      for (final e in exercises)
        [
          e.id,
          e.type.name,
          e.prompt,
          e.data,
          e.answerKey,
          e.grammarRuleId,
          e.xpReward,
        ],
    ]);
    final isExamMode = unit.isExamPrep;
    final isReview = lesson.isReview;
    await _captureReferralClaim(lesson.unitId, isExamMode: isExamMode);

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
    if (!isExamMode) await _restoreCheckpoint();
  }

  /// Called as the learner types into a writing task.
  void updateWritingDraft(String text) {
    if (text == _writingDraft) return;
    _writingDraft = text;
    _draftSave?.cancel();
    _draftSave = Timer(_draftSaveDelay, () => unawaited(_saveCheckpoint()));
  }

  /// Leave the teach phase and start the exercises.
  Future<void> startExercises() async {
    state = state.copyWith(isTeaching: false);
    await _saveCheckpoint();
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
    // A question already answered in this attempt — through "Try again" or in
    // the mistake pass — is repair, not a first retrieval.
    final repeated = _exerciseEvidence.any((e) => e.exerciseId == exercise.id);
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
      // "Try again" can miss the same question more than once; it still comes
      // back only once in the mistake pass.
      if (!state.mistakeQueue.any((queued) => queued.id == exercise.id)) {
        mistakeQueue = [...state.mistakeQueue, exercise];
      }
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
            repeated
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
                    repeated
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
      // The feedback ladder: a miss is signalled first, the explanation
      // arrives on the third, and the answer itself only on the fourth.
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
    await _saveCheckpoint();
  }

  /// Saves the lesson's position now, including typing not yet saved.
  Future<void> saveProgress() => _saveCheckpoint();

  /// Asks the question the learner just missed again, straight away.
  ///
  /// The same position is presented afresh rather than a copy inserted after
  /// it, so "question x of y" and the lesson's progress do not run ahead. Each
  /// further miss costs another heart and climbs the feedback ladder. A
  /// writing task keeps its text, so it can be corrected rather than retyped.
  Future<void> retryCurrentExercise() async {
    if (!state.canRetry || state.isCompleting) return;
    if (ref.read(settingsProvider).heartsEnabled && state.hearts <= 0) {
      state = state.copyWith(isGameOver: true);
      return;
    }
    _answerInFlightIndex = null;
    _presentationId = _uuid.v4();
    _presentationStartedAt = DateTime.now();
    state = state.copyWith(
      showFeedback: false,
      clearFeedback: true,
      writingDraft: _writingDraft,
      resumed: false,
      retrySeq: state.retrySeq + 1,
    );
    await _saveCheckpoint();
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
          writingDraft: '',
          resumed: false,
        );
        _presentationId = _uuid.v4();
        _presentationStartedAt = DateTime.now();
        _writingDraft = '';
        await _saveCheckpoint();
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
      writingDraft: '',
      resumed: false,
    );
    _presentationId = _uuid.v4();
    _presentationStartedAt = DateTime.now();
    _writingDraft = '';
    await _saveCheckpoint();
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
    _draftSave?.cancel();
    _writingDraft = '';

    // Restore the original exercise list (drop any appended mistake re-asks).
    final baseExercises =
        state.originalCount > 0 && state.originalCount <= state.exercises.length
            ? state.exercises.sublist(0, state.originalCount)
            : state.exercises;

    // An exam stays an exam across a retry: the countdown restarts, hearts
    // stay out of it, and nextExercise() keeps skipping the mistake re-asks.
    final isExamMode = state.isExamMode;
    final lesson = state.lesson;
    if (lesson != null) {
      await _captureReferralClaim(lesson.unitId, isExamMode: isExamMode);
    }
    state = LessonSessionState(
      lesson: lesson,
      exercises: baseExercises,
      hearts: isExamMode ? 999 : hearts,
      isGameOver:
          !isExamMode &&
          ref.read(settingsProvider).heartsEnabled &&
          hearts <= 0,
      originalCount: baseExercises.length,
      isExamMode: isExamMode,
      remainingSeconds: isExamMode ? (lesson?.durationMinutes ?? 0) * 60 : 0,
    );
    await _saveCheckpoint();
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
      final referralReceipt = _referralReceiptFor(
        lesson.id,
        attemptId,
        startedAt,
      );
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
            referralReceipt: referralReceipt,
          );
      if (committed && referralReceipt != null) drainReferralReceipts(ref);

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
      await _saveCheckpoint();
    } catch (error, stackTrace) {
      _log.warning('Failed to commit lesson completion', error, stackTrace);
      state = state.copyWith(
        isCompleting: false,
        completionError: 'Couldn’t save this attempt. Please try again.',
      );
    }
  }

  /// Records the referral claim the signed-in account holds as this attempt
  /// begins. Only the free units qualify, and never in exam mode. Any failure
  /// just means this attempt is not referral evidence; learning is unaffected.
  Future<void> _captureReferralClaim(
    int unitId, {
    required bool isExamMode,
  }) async {
    _referralClaimId = null;
    _referralAccountId = null;
    if (isExamMode ||
        !CourseCatalog.a1ReferralV1.freeUnitIds.contains(unitId)) {
      return;
    }
    try {
      final account = ref.read(backendServiceProvider).userId;
      if (account == null) return;
      final claim = await ref.read(referralStoreProvider).activeClaim(account);
      if (claim == null) return;
      _referralClaimId = claim;
      _referralAccountId = account;
    } catch (error, stack) {
      _log.fine('No referral claim for this attempt', error, stack);
    }
  }

  /// A receipt for this completed attempt, when it began under a claim and
  /// the same account is still signed in. Null when any exercise is missing
  /// its first interaction.
  PendingReferralReceipt? _referralReceiptFor(
    int lessonId,
    String attemptId,
    DateTime startedAt,
  ) {
    final claim = _referralClaimId;
    final account = _referralAccountId;
    if (claim == null || account == null) return null;
    if (ref.read(backendServiceProvider).userId != account) return null;
    final receipt = ReferralReceipt.fromAttempt(
      claimId: claim,
      lessonId: lessonId,
      attemptId: attemptId,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      exercises: state.exercises,
      evidence: _exerciseEvidence,
    );
    return receipt == null
        ? null
        : PendingReferralReceipt(accountId: account, receipt: receipt);
  }

  /// Saves where this attempt is, so leaving or losing the app does not lose
  /// it. Device-only, like the mock exam's checkpoint. Exams are not saved
  /// here, and finishing the lesson removes its entry.
  Future<void> _saveCheckpoint() async {
    _draftSave?.cancel();
    final lesson = state.lesson;
    if (lesson == null || state.isExamMode) return;
    final snapshot = state;
    final checkpoint =
        snapshot.isComplete
            ? null
            : <String, dynamic>{
              'version': 1,
              'signature': _contentSignature,
              'attempt': _attemptId,
              'started': _attemptStartedAt?.toIso8601String(),
              'presentation': _presentationId,
              'index': snapshot.currentIndex,
              'exercises': [for (final e in snapshot.exercises) e.id],
              'mistakes': [for (final e in snapshot.mistakeQueue) e.id],
              'appended': snapshot.mistakesAppended,
              'correct': snapshot.correctCount,
              'wrong': snapshot.wrongCount,
              'skipped': snapshot.skippedCount,
              'xp': snapshot.totalXp,
              'streak': snapshot.answerStreak,
              'bestStreak': snapshot.bestAnswerStreak,
              'teaching': snapshot.isTeaching,
              'feedback': snapshot.showFeedback,
              'outcome': snapshot.lastOutcome?.name,
              'explanation': snapshot.lastExplanation,
              'answer': snapshot.lastCorrectAnswer,
              'rule': snapshot.lastGrammarRuleId,
              'step': snapshot.feedbackStep?.name,
              'draft': _writingDraft,
              'referral':
                  _referralClaimId == null
                      ? null
                      : {
                        'claim': _referralClaimId,
                        'account': _referralAccountId,
                      },
              'failures': {
                for (final entry in _unsuccessfulAttempts.entries)
                  '${entry.key}': entry.value,
              },
              'evidence': [
                for (final e in _exerciseEvidence)
                  {
                    'presentation': e.presentationId,
                    'exercise': e.exerciseId,
                    'phase': e.phase.name,
                    'outcome': e.outcome.name,
                    'answered': e.answeredAt.toIso8601String(),
                  },
              ],
            };
    try {
      await ref
          .read(lessonCheckpointStoreProvider)
          .write(lesson.id, checkpoint);
      if (state.lesson?.id == lesson.id && state.saveFailed) {
        state = state.copyWith(saveFailed: false);
      }
    } catch (error, stack) {
      _log.warning('Could not save lesson checkpoint', error, stack);
      if (state.lesson?.id == lesson.id) {
        state = state.copyWith(saveFailed: true);
      }
    }
  }

  /// Puts back a position saved by [_saveCheckpoint], if it still fits.
  ///
  /// Anything unreadable, or saved against different content, is discarded
  /// and the lesson starts from the beginning: a lost position costs a few
  /// questions, a position replayed into the wrong questions corrupts the
  /// attempt. Nothing about the attempt changes until every field has parsed.
  Future<void> _restoreCheckpoint() async {
    final lesson = state.lesson!;
    final store = ref.read(lessonCheckpointStoreProvider);
    try {
      final saved = await store.load(lesson.id);
      if (saved == null) return;
      if (saved['version'] != 1 || saved['signature'] != _contentSignature) {
        await store.write(lesson.id, null);
        return;
      }
      final byId = {for (final e in state.exercises) e.id: e};
      Exercise exerciseFor(Object? id) =>
          byId[id] ?? (throw const FormatException('Unknown exercise'));
      final exercises = [
        for (final id in saved['exercises'] as List) exerciseFor(id),
      ];
      final index = saved['index'] as int;
      if (index < 0 || index >= exercises.length) {
        throw const FormatException('Position outside the lesson');
      }
      final evidence =
          (saved['evidence'] as List).map((raw) {
            final e = raw as Map;
            return ExerciseAttemptEvidence(
              presentationId: e['presentation'] as String,
              exerciseId: e['exercise'] as int,
              phase: ExerciseEvidencePhase.values.byName(e['phase'] as String),
              outcome: ExerciseOutcome.values.byName(e['outcome'] as String),
              answeredAt: DateTime.parse(e['answered'] as String),
            );
          }).toList();
      final failures = {
        for (final entry in (saved['failures'] as Map).entries)
          int.parse(entry.key as String): entry.value as int,
      };
      final attemptId = saved['attempt'] as String;
      final startedAt = DateTime.parse(saved['started'] as String);
      final presentationId = saved['presentation'] as String;
      final draft = saved['draft'] as String;
      final showFeedback = saved['feedback'] as bool;
      // A checkpoint written before claims were recorded carries no claim:
      // that attempt began before any claim this build knows about.
      final referral = saved['referral'] as Map?;
      final referralClaim = referral?['claim'] as String?;
      final referralAccount = referral?['account'] as String?;
      final restored = state.copyWith(
        exercises: exercises,
        currentIndex: index,
        mistakeQueue: [
          for (final id in saved['mistakes'] as List) exerciseFor(id),
        ],
        mistakesAppended: saved['appended'] as bool,
        correctCount: saved['correct'] as int,
        wrongCount: saved['wrong'] as int,
        skippedCount: saved['skipped'] as int,
        totalXp: saved['xp'] as int,
        answerStreak: saved['streak'] as int,
        bestAnswerStreak: saved['bestStreak'] as int,
        isTeaching: saved['teaching'] as bool,
        showFeedback: showFeedback,
        lastOutcome: switch (saved['outcome']) {
          final String name => ExerciseOutcome.values.byName(name),
          _ => null,
        },
        lastExplanation: saved['explanation'] as String?,
        lastCorrectAnswer: saved['answer'] as String?,
        lastGrammarRuleId: saved['rule'] as String?,
        feedbackStep: switch (saved['step']) {
          final String name => FeedbackStep.values.byName(name),
          _ => null,
        },
        writingDraft: draft,
        // Reopening before answering anything is simply starting.
        resumed: index > 0 || showFeedback,
      );
      _attemptId = attemptId;
      _attemptStartedAt = startedAt;
      _presentationId = presentationId;
      // Time away is not response latency.
      _presentationStartedAt = DateTime.now();
      _exerciseEvidence.addAll(evidence);
      _unsuccessfulAttempts.addAll(failures);
      _referralClaimId = referralClaim;
      _referralAccountId = referralAccount;
      _writingDraft = draft;
      state = restored;
    } catch (error, stack) {
      _log.fine('Discarding unreadable lesson checkpoint', error, stack);
      try {
        await store.write(lesson.id, null);
      } catch (_) {
        // Still unreadable next time, and discarded again then.
      }
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
