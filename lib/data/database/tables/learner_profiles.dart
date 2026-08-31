import 'package:drift/drift.dart';

/// Account-scoped learner profile that follows the learner across devices.
///
/// The fixed [key] keeps the local database single-account while matching the
/// `(user_id, key)` natural key used by Supabase sync.
class LearnerProfiles extends Table {
  TextColumn get key => text().withDefault(const Constant('primary'))();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  TextColumn get selfAssessedCefr =>
      text().withDefault(const Constant('preA1'))();
  TextColumn get primaryGoal => text().nullable()();
  TextColumn get secondaryGoalsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get examTrack => text().nullable()();
  TextColumn get targetHorizon => text().nullable()();
  TextColumn get focusSkillsJson => text().withDefault(const Constant('[]'))();
  IntColumn get dailyCommitmentMinutes =>
      integer().withDefault(const Constant(15))();
  IntColumn get studyDaysPerWeek => integer().withDefault(const Constant(7))();
  TextColumn get preferredVoice =>
      text().withDefault(const Constant('female'))();
  RealColumn get ttsSpeechRate => real().withDefault(const Constant(0.45))();
  IntColumn get dailyGoalXp => integer().withDefault(const Constant(300))();
  IntColumn get onboardingVersion => integer().withDefault(const Constant(1))();
  IntColumn get onboardingLastStep =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get onboardingCompletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Portable reminder intent. OS authorization and scheduled notification IDs
/// deliberately remain device-local and never enter this table.
class ReminderPreferences extends Table {
  TextColumn get key => text().withDefault(const Constant('primary'))();
  BoolColumn get wantsReminder =>
      boolean().withDefault(const Constant(false))();
  IntColumn get preferredHour => integer().nullable()();
  IntColumn get preferredMinute => integer().nullable()();
  TextColumn get daysOfWeekJson =>
      text().withDefault(const Constant('[1,2,3,4,5,6,7]'))();
  BoolColumn get catchUpEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get allowGoalSpecificText =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
