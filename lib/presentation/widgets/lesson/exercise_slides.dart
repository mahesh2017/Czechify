import '../../../domain/entities/enums.dart';
import '../../../domain/entities/exercise.dart';

/// Whether a lesson shows [exercise] as slides (a [SlideDeck]) instead of one
/// page: the kinds of step that have several parts — a rule, a word list, the
/// alphabet, a passage or recording with its questions, a dialogue — or a
/// task brief before doing it (writing, speaking, pronunciation). Every unit
/// has shown them so since A2 was switched on (28 Sep 2026); the rest (a
/// multiple choice, a fill-in) fit one page.
///
/// One place for the decision, because the exercise view and the lesson
/// viewport both act on it: a deck needs bounded height, and a view laid out
/// as a deck inside an unbounded scroll view cannot lay out at all.
bool showsAsSlides(Exercise exercise) {
  return switch (exercise.type) {
    ExerciseType.listeningComprehension ||
    ExerciseType.readingComprehension ||
    ExerciseType.dialogue ||
    ExerciseType.writingTask ||
    ExerciseType.speakingTask ||
    ExerciseType.pronunciation => true,
    ExerciseType.teaching => const {
      'lecture',
      'list',
      'alphabet',
      // Its comparison can be a deck; its other screens scroll themselves.
      'notebook',
    }.contains(exercise.data['style']),
    _ => false,
  };
}
