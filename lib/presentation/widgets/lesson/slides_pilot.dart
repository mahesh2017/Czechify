import '../../../core/config/unit_guide_pilot.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/exercise.dart';

/// Whether a lesson shows [exercise] as slides (a [SlideDeck]) instead of one
/// scrolling page: in the unit-guide pilot, for the kinds of step that have
/// several parts — a rule, a word list, a passage or recording with its
/// questions, a dialogue.
///
/// One place for the decision, because the exercise view and the lesson
/// viewport both act on it: a deck needs bounded height, and a view laid out
/// as a deck inside an unbounded scroll view cannot lay out at all.
bool showsAsSlides(Exercise exercise) {
  if (!unitGuideEnabled(unitOfLesson(exercise.lessonId))) return false;
  return switch (exercise.type) {
    ExerciseType.listeningComprehension ||
    ExerciseType.readingComprehension ||
    ExerciseType.dialogue => true,
    ExerciseType.teaching => const {
      'lecture',
      'list',
    }.contains(exercise.data['style']),
    _ => false,
  };
}
