import 'package:czechify/presentation/providers/writing_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI writing scores are bounded and malformed errors are ignored', () {
    final evaluation = WritingEvaluation.fromJson({
      'score': {
        'grammar': -20,
        'vocabulary': 101.4,
        'coherence': double.infinity,
        'overall': 82.6,
      },
      'feedback': 'Keep practising.',
      'errors': [
        {'type': 'case'},
        'not an error object',
      ],
    });

    expect(evaluation.grammar, 0);
    expect(evaluation.vocabulary, 100);
    expect(evaluation.coherence, 0);
    expect(evaluation.overall, 83);
    expect(evaluation.errors, hasLength(1));
  });

  test('a payload that is not an evaluation is refused, not scored', () {
    // `fromJson({})` used to produce a well-formed evaluation scoring zero on
    // everything with no feedback — indistinguishable from a real assessment
    // of a bad answer. A provider returning the wrong shape therefore cost a
    // quota unit and reached the learner as their own failure.
    expect(() => WritingEvaluation.fromJson({}), throwsFormatException);
    expect(
      () => WritingEvaluation.fromJson({'feedback': 'Nice work'}),
      throwsFormatException,
    );
    expect(
      () => WritingEvaluation.fromJson({'score': 'excellent'}),
      throwsFormatException,
    );
    expect(
      () => WritingEvaluation.fromJson({'score': <String, dynamic>{}}),
      throwsFormatException,
    );
    expect(
      () => WritingEvaluation.fromJson({
        'score': {'grammar': 80},
      }),
      throwsFormatException,
      reason: 'an evaluation without an overall score is not an evaluation',
    );
  });

  test('a genuine zero is still a grade', () {
    // Refusing malformed payloads must not refuse a real bad mark.
    final evaluation = WritingEvaluation.fromJson({
      'score': {'grammar': 0, 'vocabulary': 0, 'coherence': 0, 'overall': 0},
      'feedback': 'This does not answer the task.',
      'errors': <dynamic>[],
    });

    expect(evaluation.overall, 0);
    expect(evaluation.feedback, 'This does not answer the task.');
  });
}
