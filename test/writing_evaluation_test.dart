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
}
