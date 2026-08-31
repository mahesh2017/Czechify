/// The learner's primary reason for studying Czech.
enum LearningGoal {
  everydayLife,
  permanentResidenceA2,
  citizenshipB1,
  workAndCareer,
  study,
  familyAndRelationships,
  travelAndCulture,
}

extension LearningGoalKind on LearningGoal {
  bool get isExamGoal =>
      this == LearningGoal.permanentResidenceA2 ||
      this == LearningGoal.citizenshipB1;
}

/// A self-assessment, kept separate from tested placement evidence.
enum LearnerCzechLevel { preA1, a1, a2, b1OrHigher, unsure }

/// The skill areas the learner would like the plan to emphasize first.
enum LearningFocus {
  speaking,
  listening,
  reading,
  writing,
  vocabularyAndGrammar,
  lifeAndInstitutions,
}

/// A deliberately broad target window; an exact exam date is not needed to
/// produce a useful learning plan.
enum GoalHorizon {
  withinThreeMonths,
  threeToSixMonths,
  sixToTwelveMonths,
  laterOrUnsure,
}

/// Human-readable study commitments. XP remains an implementation detail of
/// the gamification system and is derived by the UI when onboarding finishes.
enum StudyCommitment { light, steady, focused, intensive }

extension StudyCommitmentSchedule on StudyCommitment {
  int get minutesPerStudyDay => switch (this) {
    StudyCommitment.light => 5,
    StudyCommitment.steady => 15,
    StudyCommitment.focused => 30,
    StudyCommitment.intensive => 45,
  };

  int get daysPerWeek => switch (this) {
    StudyCommitment.light => 3,
    StudyCommitment.steady => 5,
    StudyCommitment.focused => 6,
    StudyCommitment.intensive => 7,
  };
}

enum TutorPreference { lenka, pavel }

/// Immutable in-progress answers held by onboarding.
///
/// Persistence deliberately sits outside this domain object. The same draft
/// can later be installed into a local/cloud profile store without coupling
/// the onboarding UI to a particular backend.
class LearnerProfileDraft {
  LearnerProfileDraft({
    this.displayName = '',
    this.primaryGoal = LearningGoal.everydayLife,
    this.currentLevel = LearnerCzechLevel.preA1,
    Iterable<LearningFocus> focuses = const {
      LearningFocus.speaking,
      LearningFocus.listening,
    },
    this.goalHorizon,
    this.commitment = StudyCommitment.steady,
    this.tutor = TutorPreference.lenka,
    this.remindersEnabled = false,
    this.reminderMinutesAfterMidnight = 19 * 60,
  }) : assert(
         reminderMinutesAfterMidnight >= 0 &&
             reminderMinutesAfterMidnight < 24 * 60,
       ),
       focuses = Set.unmodifiable(focuses);

  final String displayName;
  final LearningGoal primaryGoal;
  final LearnerCzechLevel currentLevel;
  final Set<LearningFocus> focuses;
  final GoalHorizon? goalHorizon;
  final StudyCommitment commitment;
  final TutorPreference tutor;
  final bool remindersEnabled;
  final int reminderMinutesAfterMidnight;

  LearnerProfileDraft copyWith({
    String? displayName,
    LearningGoal? primaryGoal,
    LearnerCzechLevel? currentLevel,
    Iterable<LearningFocus>? focuses,
    GoalHorizon? goalHorizon,
    bool clearGoalHorizon = false,
    StudyCommitment? commitment,
    TutorPreference? tutor,
    bool? remindersEnabled,
    int? reminderMinutesAfterMidnight,
  }) => LearnerProfileDraft(
    displayName: displayName ?? this.displayName,
    primaryGoal: primaryGoal ?? this.primaryGoal,
    currentLevel: currentLevel ?? this.currentLevel,
    focuses: focuses ?? this.focuses,
    goalHorizon: clearGoalHorizon ? null : (goalHorizon ?? this.goalHorizon),
    commitment: commitment ?? this.commitment,
    tutor: tutor ?? this.tutor,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderMinutesAfterMidnight:
        reminderMinutesAfterMidnight ?? this.reminderMinutesAfterMidnight,
  );

  LearnerProfile complete({DateTime? completedAt}) => LearnerProfile(
    displayName: displayName.trim(),
    primaryGoal: primaryGoal,
    currentLevel: currentLevel,
    focuses: focuses,
    goalHorizon: primaryGoal.isExamGoal ? goalHorizon : null,
    commitment: commitment,
    tutor: tutor,
    remindersEnabled: remindersEnabled,
    reminderMinutesAfterMidnight: reminderMinutesAfterMidnight,
    onboardingCompletedAt: completedAt ?? DateTime.now().toUtc(),
  );
}

/// Completed, structured onboarding profile ready for persistence.
class LearnerProfile {
  LearnerProfile({
    required this.displayName,
    required this.primaryGoal,
    required this.currentLevel,
    required Iterable<LearningFocus> focuses,
    required this.goalHorizon,
    required this.commitment,
    required this.tutor,
    required this.remindersEnabled,
    required this.reminderMinutesAfterMidnight,
    required this.onboardingCompletedAt,
    this.onboardingVersion = currentOnboardingVersion,
  }) : assert(
         reminderMinutesAfterMidnight >= 0 &&
             reminderMinutesAfterMidnight < 24 * 60,
       ),
       focuses = Set.unmodifiable(focuses);

  static const int currentOnboardingVersion = 2;

  final String displayName;
  final LearningGoal primaryGoal;
  final LearnerCzechLevel currentLevel;
  final Set<LearningFocus> focuses;
  final GoalHorizon? goalHorizon;
  final StudyCommitment commitment;
  final TutorPreference tutor;
  final bool remindersEnabled;
  final int reminderMinutesAfterMidnight;
  final DateTime onboardingCompletedAt;
  final int onboardingVersion;
}
