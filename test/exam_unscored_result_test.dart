import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exam_result.dart';
import 'package:czechify/domain/repositories/exam_repository.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/screens/exam/mock_exam_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

/// Writing and speaking are scored outside the grader. When the evaluator is
/// offline, fails, or the learner left the task blank, there is no score — and
/// that used to reach the result screen as a 0, rendered in red beside the
/// sections they did answer, and folded into the overall percentage.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('an unscored writing task reads as not assessed', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ReadingAndWritingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [examRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: const MockExamScreen(level: ExamLevel.a2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start Exam'));
    await tester.tap(find.text('Start Exam'));
    await tester.pumpAndSettle();

    // Answer the reading question, then move on to the writing section and
    // leave it blank — nothing scores it, so it is never assessed.
    await tester.tap(find.text('Prague'));
    await tester.pump();
    await tester.ensureVisible(find.text('Next Section'));
    await tester.tap(find.text('Next Section'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Finish Exam'));
    await tester.tap(find.text('Finish Exam'));
    await tester.pumpAndSettle();

    expect(find.text('Exam results'), findsOneWidget);

    /// The value rendered beside [label] in the score table.
    Finder valueOf(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.text('Not assessed'),
    );

    // Reading was answered, so it keeps a real number.
    expect(find.text('100 / 100'), findsOneWidget);

    // Writing was never scored, and without it there is no honest overall.
    // Neither may show a number the learner did not earn.
    expect(valueOf('Writing'), findsOneWidget);
    expect(valueOf('Overall'), findsOneWidget);

    // And the learner is told why, rather than left to infer it.
    expect(
      find.textContaining('unscored'),
      findsWidgets,
      reason: 'the result should say the paper is partly unscored',
    );

    // The stored attempt carries the same distinction.
    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.writingScore, isNull);
    expect(repository.saved.single.totalScore, isNull);
    expect(repository.saved.single.readingScore, 100);
  });
}

class _ReadingAndWritingRepository implements ExamRepository {
  final List<ExamResult> saved = [];

  static const _blueprint = ExamBlueprint(
    product: ExamProduct.permanentResidence,
    version: 'test',
    effectiveDate: '2026-01-01',
    scoringRule: ExamScoringRule.rawPointsWrittenSpeakingGate,
  );

  MockExam get _paper => const MockExam(
    id: 'reading-and-writing',
    level: ExamLevel.a2,
    blueprint: _blueprint,
    totalTimeMinutes: 10,
    sections: [
      MockExamSection(
        type: ExamSectionType.reading,
        timeLimitMinutes: 5,
        maxScore: 1,
        questions: [
          {
            'prompt': 'Where is the castle?',
            'options': ['Prague', 'Brno'],
            'correct_answer': 0,
            'points': 1,
          },
        ],
      ),
      MockExamSection(
        type: ExamSectionType.writing,
        timeLimitMinutes: 5,
        maxScore: 1,
        questions: [
          {'prompt': 'Write about your day.', 'min_words': 5, 'points': 1},
        ],
      ),
    ],
  );

  @override
  Future<MockExam> getMockExam(
    ExamLevel level, {
    ExamProduct product = ExamProduct.permanentResidence,
  }) async => _paper;

  @override
  Future<MockExam?> findMockExam(
    ExamLevel level,
    String id, {
    ExamProduct product = ExamProduct.permanentResidence,
  }) async => _paper.id == id ? _paper : null;

  @override
  Future<List<ExamResult>> getResults(
    ExamLevel level, {
    ExamProduct? product,
  }) async => const [];

  @override
  Future<ExamResult> saveResult(ExamResult result) async {
    saved.add(result);
    return result;
  }
}
