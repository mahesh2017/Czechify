import 'dart:convert';

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

/// A bank holds several interchangeable papers and [getMockExam] draws one at
/// random per attempt. The checkpoint used to record only the level and the
/// indices, so resuming overlaid the saved answers onto whichever paper the
/// next draw returned — and because every shipped bank's papers have identical
/// section lengths, the index bounds check could never notice.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const blueprint = ExamBlueprint(
    product: ExamProduct.permanentResidence,
    version: '2026-04-11',
    effectiveDate: '2026-04-11',
    scoringRule: ExamScoringRule.rawPointsWrittenSpeakingGate,
  );

  /// Two papers of exactly the same shape, distinguishable only by their text.
  MockExam paper(String id, String label) => MockExam(
    id: id,
    level: ExamLevel.a2,
    blueprint: blueprint,
    totalTimeMinutes: 5,
    sections: [
      MockExamSection(
        type: ExamSectionType.reading,
        timeLimitMinutes: 5,
        maxScore: 1,
        questions: [
          {
            'prompt': '$label question one',
            'options': ['$label A', '$label B'],
            'correct_answer': 0,
            'points': 1,
          },
        ],
      ),
    ],
  );

  void seedCheckpoint({
    required String examId,
    String blueprintVersion = '2026-04-11',
  }) {
    SharedPreferences.setMockInitialValues({
      'exam_checkpoint_a2': jsonEncode({
        'level': 'a2',
        'exam_id': examId,
        'blueprint_version': blueprintVersion,
        'section_index': 0,
        'question_index': 0,
        'seconds_left': 200,
        'answers': {
          '0': {'0': 1},
        },
        'saved_at': DateTime.now().toIso8601String(),
      }),
    });
  }

  Future<void> pumpExam(WidgetTester tester, ExamRepository repository) async {
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
  }

  testWidgets('resuming returns to the paper the answers were given to', (
    tester,
  ) async {
    seedCheckpoint(examId: 'a2-practice-1');
    // The draw lands on the other paper, which is the case that used to
    // silently corrupt the attempt.
    final repository = _TwoPaperRepository(
      papers: [paper('a2-practice-1', 'First'), paper('a2-practice-2', 'Second')],
      drawn: 'a2-practice-2',
    );

    await pumpExam(tester, repository);
    await tester.ensureVisible(find.text('Resume Exam'));
    await tester.tap(find.text('Resume Exam'));
    await tester.pumpAndSettle();

    expect(find.text('First question one'), findsOneWidget);
    expect(find.text('Second question one'), findsNothing);
  });

  testWidgets('a checkpoint whose paper is gone is discarded, not remapped', (
    tester,
  ) async {
    seedCheckpoint(examId: 'a2-retired-paper');
    final repository = _TwoPaperRepository(
      papers: [paper('a2-practice-1', 'First'), paper('a2-practice-2', 'Second')],
      drawn: 'a2-practice-2',
    );

    await pumpExam(tester, repository);

    // No resume is offered, and the attempt starts clean on the drawn paper.
    expect(find.text('Resume Exam'), findsNothing);
    await tester.ensureVisible(find.text('Start Exam'));
    await tester.tap(find.text('Start Exam'));
    await tester.pumpAndSettle();
    expect(find.text('Second question one'), findsOneWidget);
  });

  testWidgets('a paper reissued under a new blueprint is not resumed', (
    tester,
  ) async {
    // Same id, older blueprint: the questions behind that id may have changed.
    seedCheckpoint(examId: 'a2-practice-1', blueprintVersion: '2025-01-01');
    final repository = _TwoPaperRepository(
      papers: [paper('a2-practice-1', 'First'), paper('a2-practice-2', 'Second')],
      drawn: 'a2-practice-1',
    );

    await pumpExam(tester, repository);

    expect(find.text('Resume Exam'), findsNothing);
  });
}

class _TwoPaperRepository implements ExamRepository {
  _TwoPaperRepository({required this.papers, required this.drawn});

  final List<MockExam> papers;

  /// Stands in for the random draw, pinned so the test is not a coin flip.
  final String drawn;

  @override
  Future<MockExam> getMockExam(
    ExamLevel level, {
    ExamProduct product = ExamProduct.permanentResidence,
  }) async => papers.firstWhere((p) => p.id == drawn);

  @override
  Future<MockExam?> findMockExam(
    ExamLevel level,
    String id, {
    ExamProduct product = ExamProduct.permanentResidence,
  }) async {
    for (final paper in papers) {
      if (paper.id == id) return paper;
    }
    return null;
  }

  @override
  Future<List<ExamResult>> getResults(
    ExamLevel level, {
    ExamProduct? product,
  }) async => const [];

  @override
  Future<ExamResult> saveResult(ExamResult result) async => result;
}
