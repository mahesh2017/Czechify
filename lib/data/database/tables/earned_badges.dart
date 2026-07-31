import 'package:drift/drift.dart';

/// Earned badges table — tracks which badges the user has unlocked.
class EarnedBadges extends Table {
  TextColumn get badgeId => text()();
  DateTimeColumn get earnedAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  @override
  Set<Column> get primaryKey => {badgeId};
}
