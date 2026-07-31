import 'package:drift/drift.dart';

/// Gamification state stored in Drift (single-row table).
///
/// Migrated from SharedPreferences for transactional integrity and
/// cross-device sync via the existing sync outbox.
///
/// The `key` column is always 'primary' — this is a single-row table
/// using a fixed key to avoid the complexity of multi-row state merging.
class GamificationStateTable extends Table {
  TextColumn get key => text()();
  IntColumn get hearts => integer().withDefault(const Constant(5))();
  IntColumn get maxHearts => integer().withDefault(const Constant(5))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  IntColumn get totalXp => integer().withDefault(const Constant(0))();
  IntColumn get dailyXp => integer().withDefault(const Constant(0))();
  IntColumn get dailyGoalXp => integer().withDefault(const Constant(50))();
  IntColumn get gems => integer().withDefault(const Constant(0))();
  TextColumn get earnedBadges => text().withDefault(const Constant('[]'))();
  DateTimeColumn get lastHeartRefill => dateTime().nullable()();
  BoolColumn get streakFreezeAvailable =>
      boolean().withDefault(const Constant(true))();
  TextColumn get lastOpenDate => text().nullable()();
  TextColumn get dailyXpResetDate => text().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  @override
  Set<Column> get primaryKey => {key};
}
