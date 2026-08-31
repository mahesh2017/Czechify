import 'package:czechify/domain/entities/learner_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-exam goals discard an irrelevant exam horizon', () {
    final profile = LearnerProfileDraft(
      displayName: ' Anna ',
      primaryGoal: LearningGoal.workAndCareer,
      goalHorizon: GoalHorizon.withinThreeMonths,
      focuses: const {
        LearningFocus.speaking,
        LearningFocus.vocabularyAndGrammar,
      },
    ).complete(completedAt: DateTime.utc(2026, 8, 30));

    expect(profile.displayName, 'Anna');
    expect(profile.goalHorizon, isNull);
    expect(profile.onboardingVersion, LearnerProfile.currentOnboardingVersion);
  });

  test('exam goals retain their broad target horizon', () {
    final profile = LearnerProfileDraft(
      primaryGoal: LearningGoal.permanentResidenceA2,
      goalHorizon: GoalHorizon.threeToSixMonths,
    ).complete(completedAt: DateTime.utc(2026, 8, 30));

    expect(profile.goalHorizon, GoalHorizon.threeToSixMonths);
  });

  test('study commitments expose minutes and days rather than XP', () {
    expect(StudyCommitment.light.minutesPerStudyDay, 5);
    expect(StudyCommitment.light.daysPerWeek, 3);
    expect(StudyCommitment.steady.minutesPerStudyDay, 15);
    expect(StudyCommitment.steady.daysPerWeek, 5);
    expect(StudyCommitment.intensive.minutesPerStudyDay, 45);
    expect(StudyCommitment.intensive.daysPerWeek, 7);
  });
}
