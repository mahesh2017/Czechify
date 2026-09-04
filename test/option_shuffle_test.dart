import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stable option shuffle preserves the answer and retry order', () {
    const options = ['správně', 'wrong one', 'wrong two', 'wrong three'];
    final first = shuffledOptions(
      options: options,
      correctIndex: 0,
      seed: 4012,
    );
    final retry = shuffledOptions(
      options: options,
      correctIndex: 0,
      seed: 4012,
    );

    expect(retry.options, first.options);
    expect(retry.correctIndex, first.correctIndex);
    expect(first.options[first.correctIndex], 'správně');
    expect(first.options.toSet(), options.toSet());
  });

  test('different exercise seeds do not leave every answer first', () {
    const options = ['correct', 'distractor 1', 'distractor 2', 'distractor 3'];
    final positions = <int>{
      for (var seed = 4000; seed < 4048; seed++)
        shuffledOptions(
          options: options,
          correctIndex: 0,
          seed: seed,
        ).correctIndex,
    };

    expect(positions.length, greaterThan(1));
    expect(positions, containsAll(<int>[0, 1, 2, 3]));
  });

  test('question copies retain metadata while remapping the answer', () {
    final source = <String, dynamic>{
      'question_en': 'Choose one',
      'options': <String>['yes', 'no', 'maybe'],
      'correct_index': 1,
      'explanation': 'The recording says no.',
    };
    final shuffled = shuffledQuestion(source, seed: 17);

    expect(shuffled['question_en'], source['question_en']);
    expect(shuffled['explanation'], source['explanation']);
    final options = (shuffled['options'] as List<dynamic>).cast<String>();
    expect(options[shuffled['correct_index'] as int], 'no');
    expect(source['options'], ['yes', 'no', 'maybe']);
  });
}
