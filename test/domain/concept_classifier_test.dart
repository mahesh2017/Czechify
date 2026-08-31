import 'package:czechify/domain/engines/concept_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classifier = ConceptClassifier();

  test('classifies only concepts supported by explicit metadata', () {
    final concepts = classifier.classify(
      exerciseType: 'fill_blank',
      ruleName: 'Perfective and imperfective verbs',
      rulePattern: 'Formal vs informal requests',
      ruleExplanation: 'Long vs short vowels can change meaning.',
      caseAffected: 'accusative',
    );

    expect(concepts, {
      'case:accusative': 'Accusative case',
      'verb_aspect': 'Verb aspect',
      'register': 'Formal and informal register',
      'vowel_length': 'Vowel length',
    });
  });

  test('does not diagnose a generic speaking or pronunciation failure', () {
    expect(classifier.classify(exerciseType: 'pronunciation'), isEmpty);
    expect(classifier.classify(exerciseType: 'speaking_task'), isEmpty);
  });

  test('exercise type directly supports word-order classification', () {
    expect(classifier.classify(exerciseType: 'word_order'), {
      'word_order': 'Word order',
    });
  });

  test('explicit content metadata enables communicative-function evidence', () {
    expect(
      classifier.classify(
        exerciseType: 'dialogue',
        conceptTags: const ['register'],
        communicativeFunction: 'Request clarification',
      ),
      {
        'register': 'Formal and informal register',
        'communicative_function:request_clarification':
            'Communicative function: Request clarification',
      },
    );
  });
}
