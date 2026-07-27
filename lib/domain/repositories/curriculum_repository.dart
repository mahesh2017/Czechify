import '../entities/unit.dart';
import '../entities/lesson.dart';
import '../entities/exercise.dart';

import '../entities/enums.dart';

/// Abstract interface for curriculum data access.
abstract class CurriculumRepository {
  Future<List<Unit>> getUnits(Phase phase);
  Future<Unit> getUnit(int unitId);
  Future<List<Lesson>> getLessons(int unitId);
  Future<Lesson> getLesson(int lessonId);
  Future<List<Exercise>> getExercises(int lessonId);
}
