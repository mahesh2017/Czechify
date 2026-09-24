import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/screens/lesson/delayed_transfer_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// A delayed transfer re-tests a missed question a week later with another
/// question from the same lesson. It used to take the lesson's first other
/// exercise, which in most lessons is the teaching card.
void main() {
  Exercise item(int id, ExerciseType type, {String? mode}) => Exercise(
    id: id,
    lessonId: 602,
    type: type,
    prompt: '',
    data: {if (mode != null) 'mode': mode},
  );

  final lesson = [
    item(6420, ExerciseType.teaching),
    item(6421, ExerciseType.multipleChoice, mode: 'check'),
    item(6422, ExerciseType.fillBlank, mode: 'guided'),
    item(6430, ExerciseType.listeningComprehension),
    item(6431, ExerciseType.fillBlank),
    item(6432, ExerciseType.dictation),
  ];

  test('never a teaching card, lecture check or guided item', () {
    final variant = transferVariant(lesson, 6432);
    expect(variant?.type, isNot(ExerciseType.teaching));
    expect(variant?.mode, ExerciseMode.scored);
  });

  test('prefers a question of the same type as the one missed', () {
    expect(transferVariant(lesson, 6431)?.id, isNot(6431));
    final lessonWithTwoBlanks = [...lesson, item(6433, ExerciseType.fillBlank)];
    expect(transferVariant(lessonWithTwoBlanks, 6431)?.id, 6433);
  });

  test('falls back to any other scored question', () {
    expect(transferVariant(lesson, 6430)?.id, 6431);
  });

  test('none when the lesson has no other scored question', () {
    expect(
      transferVariant([item(1, ExerciseType.teaching), item(2, ExerciseType.dictation)], 2),
      isNull,
    );
  });
}
