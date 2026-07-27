import 'dart:convert';
import '../../domain/entities/unit.dart' as entity;
import '../../domain/entities/lesson.dart' as entity;
import '../../domain/entities/exercise.dart' as entity;
import '../../domain/entities/enums.dart';
import '../../domain/repositories/curriculum_repository.dart';
import '../database/database.dart' as db;

/// Concrete implementation of [CurriculumRepository] using Drift.
class DriftCurriculumRepository implements CurriculumRepository {
  final db.AppDatabase _db;

  DriftCurriculumRepository(this._db);

  @override
  Future<List<entity.Unit>> getUnits(Phase phase) async {
    final rows = await _db.curriculumDao.getUnitsByPhase(phase.name);
    return rows.map(_toEntityUnit).toList();
  }

  @override
  Future<entity.Unit> getUnit(int unitId) async {
    final row = await _db.curriculumDao.getUnit(unitId);
    if (row == null) throw Exception('Unit $unitId not found');
    return _toEntityUnit(row);
  }

  @override
  Future<List<entity.Lesson>> getLessons(int unitId) async {
    final rows = await _db.curriculumDao.getLessonsByUnit(unitId);
    return rows.map(_toEntityLesson).toList();
  }

  @override
  Future<entity.Lesson> getLesson(int lessonId) async {
    final row = await _db.curriculumDao.getLesson(lessonId);
    if (row == null) throw Exception('Lesson $lessonId not found');
    return _toEntityLesson(row);
  }

  @override
  Future<List<entity.Exercise>> getExercises(int lessonId) async {
    final rows = await _db.curriculumDao.getExercisesByLesson(lessonId);
    return rows.map(_toEntityExercise).toList();
  }

  // ── Mappers ──

  entity.Unit _toEntityUnit(db.Unit row) {
    return entity.Unit(
      id: row.id,
      title: row.title,
      description: row.description,
      phase: Phase.values.byName(row.phase),
      orderIndex: row.orderIndex,
      grammarTags:
          row.grammarTags.split(',').where((t) => t.isNotEmpty).toList(),
      isExamPrep: row.isExamPrep,
      lessonCount: row.lessonCount,
    );
  }

  entity.Lesson _toEntityLesson(db.Lesson row) {
    return entity.Lesson(
      id: row.id,
      unitId: row.unitId,
      orderInUnit: row.orderInUnit,
      title: row.title,
      description: row.description,
      durationMinutes: row.durationMinutes,
      lessonType: LessonType.values.byName(row.lessonType),
      isReview: row.isReview,
    );
  }

  entity.Exercise _toEntityExercise(db.Exercise row) {
    return entity.Exercise(
      id: row.id,
      lessonId: row.lessonId,
      type: _parseExerciseType(row.type),
      prompt: row.prompt,
      data: jsonDecode(row.data) as Map<String, dynamic>,
      answerKey: row.answerKey,
      grammarRuleId: row.grammarRuleId,
      xpReward: row.xpReward,
    );
  }

  /// Convert snake_case string from DB to ExerciseType enum.
  ExerciseType _parseExerciseType(String type) {
    // Convert snake_case to camelCase
    final camelCase = type.replaceAllMapped(
      RegExp(r'_(.)'),
      (m) => m.group(1)!.toUpperCase(),
    );
    return ExerciseType.values.byName(camelCase);
  }
}
