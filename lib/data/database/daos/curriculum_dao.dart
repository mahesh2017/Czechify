import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/units.dart';
import '../tables/lessons.dart';
import '../tables/exercises.dart';
import '../tables/grammar_rules.dart';

part 'curriculum_dao.g.dart';

/// Data access object for curriculum-related queries.
@DriftAccessor(tables: [Units, Lessons, Exercises, GrammarRules])
class CurriculumDao extends DatabaseAccessor<AppDatabase>
    with _$CurriculumDaoMixin {
  CurriculumDao(super.db);

  // ── Units ──

  Future<List<Unit>> getUnitsByPhase(String phase) {
    return (select(units)
          ..where((u) => u.phase.equals(phase) & u.isActive.equals(true))
          ..orderBy([(u) => OrderingTerm.asc(u.orderIndex)]))
        .get();
  }

  Future<Unit?> getUnit(int unitId) {
    return (select(units)..where(
      (u) => u.id.equals(unitId) & u.isActive.equals(true),
    )).getSingleOrNull();
  }

  Future<int> insertUnit(UnitsCompanion unit) => into(units).insert(unit);

  /// Upsert so content updates in a new app version reach existing installs.
  Future<void> insertUnits(List<UnitsCompanion> unitList) =>
      batch((b) => b.insertAllOnConflictUpdate(units, unitList));

  // ── Lessons ──

  Future<List<Lesson>> getLessonsByUnit(int unitId) {
    return (select(lessons)
          ..where((l) => l.unitId.equals(unitId) & l.isActive.equals(true))
          ..orderBy([(l) => OrderingTerm.asc(l.orderInUnit)]))
        .get();
  }

  Future<Lesson?> getLesson(int lessonId) {
    return (select(lessons)..where(
      (l) => l.id.equals(lessonId) & l.isActive.equals(true),
    )).getSingleOrNull();
  }

  Future<void> insertLessons(List<LessonsCompanion> lessonList) =>
      batch((b) => b.insertAllOnConflictUpdate(lessons, lessonList));

  // ── Exercises ──

  Future<List<Exercise>> getExercisesByLesson(int lessonId) {
    return (select(exercises)
          ..where((e) => e.lessonId.equals(lessonId) & e.isActive.equals(true))
          // Exercise IDs are the stable sequence within every bundled lesson.
          // An explicit order keeps SQLite query planning from changing the
          // pedagogical flow (exposure -> perception -> guided production).
          ..orderBy([(e) => OrderingTerm.asc(e.id)]))
        .get();
  }

  Future<void> insertExercises(List<ExercisesCompanion> exerciseList) =>
      batch((b) => b.insertAllOnConflictUpdate(exercises, exerciseList));

  // ── Grammar Rules ──

  Future<List<GrammarRule>> getGrammarRulesByUnit(int unitId) {
    return (select(grammarRules)
      ..where((g) => g.unitId.equals(unitId) & g.isActive.equals(true))).get();
  }

  Future<List<GrammarRule>> getAllGrammarRules() {
    return (select(grammarRules)
          ..where((g) => g.isActive.equals(true))
          ..orderBy([
            (g) => OrderingTerm.asc(g.unitId),
            (g) => OrderingTerm.asc(g.id),
          ]))
        .get();
  }

  Future<GrammarRule?> getGrammarRuleById(String id) {
    return (select(grammarRules)..where(
      (g) => g.id.equals(id) & g.isActive.equals(true),
    )).getSingleOrNull();
  }

  Future<void> insertGrammarRules(List<GrammarRulesCompanion> ruleList) =>
      batch((b) => b.insertAllOnConflictUpdate(grammarRules, ruleList));

  // ── Seed check ──

  Future<bool> isSeeded() async {
    final result =
        await customSelect(
          'SELECT COUNT(*) AS c FROM units WHERE is_active = 1',
        ).getSingle();
    return result.read<int>('c') > 0;
  }
}
