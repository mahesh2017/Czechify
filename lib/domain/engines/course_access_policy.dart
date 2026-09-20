import '../entities/course_catalog.dart';
import '../entities/curriculum_entitlement.dart';
import '../entities/monetization_snapshot.dart';

enum CourseAccessSource { free, referral, legacy, core, migrationGrace, staff }

class CourseAccess {
  final Map<int, Set<CourseAccessSource>> sourcesByUnit;
  final Set<int> reverificationUnitIds;

  CourseAccess({
    required Map<int, Set<CourseAccessSource>> sourcesByUnit,
    Set<int> reverificationUnitIds = const {},
  }) : sourcesByUnit = Map.unmodifiable({
         for (final entry in sourcesByUnit.entries)
           entry.key: Set<CourseAccessSource>.unmodifiable(entry.value),
       }),
       reverificationUnitIds = Set.unmodifiable(reverificationUnitIds);

  Set<int> get accessibleUnitIds => Set.unmodifiable(sourcesByUnit.keys);
  bool canAccessUnit(int unitId) => sourcesByUnit.containsKey(unitId);
}

/// Commercial access only. No XP, lesson completion, placement or heart input.
class CourseAccessPolicy {
  const CourseAccessPolicy();

  CourseAccess evaluate({
    required CourseCatalog catalog,
    required String? accountId,
    required DateTime now,
    required bool offline,
    MonetizationSnapshot? snapshot,
    CurriculumEntitlement staff = CurriculumEntitlement.none,
  }) {
    final allUnits = catalog.allUnitIds;
    final sources = <int, Set<CourseAccessSource>>{};
    void grant(Iterable<int> ids, CourseAccessSource source) {
      for (final id in ids.where(allUnits.contains)) {
        sources.putIfAbsent(id, () => <CourseAccessSource>{}).add(source);
      }
    }

    grant(catalog.freeUnitIds, CourseAccessSource.free);
    // The existing staff repository is already account-scoped; its caller
    // must supply only that account's override, never a global cached value.
    if (accountId != null && accountId.isNotEmpty && staff.isActiveAt(now)) {
      grant(allUnits, CourseAccessSource.staff);
    }

    final validSnapshot =
        accountId != null &&
        accountId.isNotEmpty &&
        snapshot != null &&
        snapshot.userId == accountId &&
        snapshot.revision >= 0;
    final needsVerification = <int>{};
    if (validSnapshot) {
      for (final permanent in snapshot.permanentGrants.where(
        (g) => !g.revoked,
      )) {
        grant(
          [permanent.unitId],
          switch (permanent.source) {
            PermanentGrantSource.referral => CourseAccessSource.referral,
            PermanentGrantSource.legacy => CourseAccessSource.legacy,
            PermanentGrantSource.staffPermanent => CourseAccessSource.staff,
          },
        );
      }
      if (snapshot.core.isActiveAt(now, offline: offline)) {
        grant(allUnits, CourseAccessSource.core);
      } else if (offline && snapshot.core.isActiveAt(now, offline: false)) {
        needsVerification.addAll(allUnits);
      }
      if (snapshot.migrationGraceUntil?.isAfter(now) ?? false) {
        grant(allUnits, CourseAccessSource.migrationGrace);
      }
    }
    needsVerification.removeAll(sources.keys);
    return CourseAccess(
      sourcesByUnit: sources,
      reverificationUnitIds: needsVerification,
    );
  }
}
