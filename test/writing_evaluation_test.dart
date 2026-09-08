import 'package:czechify/presentation/providers/writing_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI writing scores are bounded and malformed errors are ignored', () {
    // Out of range is a real judgement expressed sloppily; reading a 101 as
    // 100 loses nothing.
    final evaluation = WritingEvaluation.fromJson({
      'score': {
        'grammar': -20,
        'vocabulary': 101.4,
        'coherence': 64,
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
    expect(evaluation.coherence, 64);
    expect(evaluation.overall, 83);
    expect(evaluation.errors, hasLength(1));
  });

  test('a missing criterion is refused rather than invented', () {
    // Requiring only `overall` was the same defect as requiring nothing, with
    // a smaller blast radius: this payload produced three criterion scores of
    // zero the client had made up, shown beside a real 85 as though they
    // carried the same weight. A default is a claim about the learner's
    // writing, and there is no default that is safe to make.
    expect(
      () => WritingEvaluation.fromJson({
        'score': {'overall': 85},
        'feedback': 'Good effort.',
      }),
      throwsFormatException,
    );

    for (final missing in ['grammar', 'vocabulary', 'coherence', 'overall']) {
      final score = {
        'grammar': 80,
        'vocabulary': 80,
        'coherence': 80,
        'overall': 80,
      }..remove(missing);
      expect(
        () => WritingEvaluation.fromJson({
          'score': score,
          'feedback': 'Good effort.',
        }),
        throwsFormatException,
        reason: 'an evaluation missing $missing is not an evaluation',
      );
    }

    // Not a number at all, and a number that is not one either.
    expect(
      () => WritingEvaluation.fromJson({
        'score': {
          'grammar': 'good',
          'vocabulary': 80,
          'coherence': 80,
          'overall': 80,
        },
        'feedback': 'Good effort.',
      }),
      throwsFormatException,
    );
    expect(
      () => WritingEvaluation.fromJson({
        'score': {
          'grammar': double.infinity,
          'vocabulary': 80,
          'coherence': 80,
          'overall': 80,
        },
        'feedback': 'Good effort.',
      }),
      throwsFormatException,
    );
  });

  test('an evaluation with no feedback is not an evaluation', () {
    // Scores without the reasoning are a mark with nothing to learn from, and
    // the empty string this used to substitute reads as one the model chose
    // not to give.
    expect(
      () => WritingEvaluation.fromJson({
        'score': {
          'grammar': 80,
          'vocabulary': 80,
          'coherence': 80,
          'overall': 80,
        },
      }),
      throwsFormatException,
    );
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
        'feedback': 'Good effort.',
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
