// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_dao.dart';

// ignore_for_file: type=lint
mixin _$ProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $LessonProgressTable get lessonProgress => attachedDatabase.lessonProgress;
  $EarnedBadgesTable get earnedBadges => attachedDatabase.earnedBadges;
  $UserProgressTable get userProgress => attachedDatabase.userProgress;
  $LessonAttemptsTable get lessonAttempts => attachedDatabase.lessonAttempts;
  $RewardLedgerTable get rewardLedger => attachedDatabase.rewardLedger;
  $GamificationStateTableTable get gamificationStateTable =>
      attachedDatabase.gamificationStateTable;
  $ExerciseAttemptsTable get exerciseAttempts =>
      attachedDatabase.exerciseAttempts;
  $LearningEvidenceEventsTable get learningEvidenceEvents =>
      attachedDatabase.learningEvidenceEvents;
  $PlacementProfilesTable get placementProfiles =>
      attachedDatabase.placementProfiles;
  $DelayedTransferAssignmentsTable get delayedTransferAssignments =>
      attachedDatabase.delayedTransferAssignments;
  $ReferralReceiptOutboxTable get referralReceiptOutbox =>
      attachedDatabase.referralReceiptOutbox;
  ProgressDaoManager get managers => ProgressDaoManager(this);
}

class ProgressDaoManager {
  final _$ProgressDaoMixin _db;
  ProgressDaoManager(this._db);
  $$LessonProgressTableTableManager get lessonProgress =>
      $$LessonProgressTableTableManager(
        _db.attachedDatabase,
        _db.lessonProgress,
      );
  $$EarnedBadgesTableTableManager get earnedBadges =>
      $$EarnedBadgesTableTableManager(_db.attachedDatabase, _db.earnedBadges);
  $$UserProgressTableTableManager get userProgress =>
      $$UserProgressTableTableManager(_db.attachedDatabase, _db.userProgress);
  $$LessonAttemptsTableTableManager get lessonAttempts =>
      $$LessonAttemptsTableTableManager(
        _db.attachedDatabase,
        _db.lessonAttempts,
      );
  $$RewardLedgerTableTableManager get rewardLedger =>
      $$RewardLedgerTableTableManager(_db.attachedDatabase, _db.rewardLedger);
  $$GamificationStateTableTableTableManager get gamificationStateTable =>
      $$GamificationStateTableTableTableManager(
        _db.attachedDatabase,
        _db.gamificationStateTable,
      );
  $$ExerciseAttemptsTableTableManager get exerciseAttempts =>
      $$ExerciseAttemptsTableTableManager(
        _db.attachedDatabase,
        _db.exerciseAttempts,
      );
  $$LearningEvidenceEventsTableTableManager get learningEvidenceEvents =>
      $$LearningEvidenceEventsTableTableManager(
        _db.attachedDatabase,
        _db.learningEvidenceEvents,
      );
  $$PlacementProfilesTableTableManager get placementProfiles =>
      $$PlacementProfilesTableTableManager(
        _db.attachedDatabase,
        _db.placementProfiles,
      );
  $$DelayedTransferAssignmentsTableTableManager
  get delayedTransferAssignments =>
      $$DelayedTransferAssignmentsTableTableManager(
        _db.attachedDatabase,
        _db.delayedTransferAssignments,
      );
  $$ReferralReceiptOutboxTableTableManager get referralReceiptOutbox =>
      $$ReferralReceiptOutboxTableTableManager(
        _db.attachedDatabase,
        _db.referralReceiptOutbox,
      );
}
