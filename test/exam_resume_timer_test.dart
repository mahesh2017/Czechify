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

/// The live timer runs off a wall-clock deadline precisely so backgrounding
/// cannot pause it. Resume handed the stored seconds straight back, so quitting
/// the app did what backgrounding could not — leaving and returning could
/// extend a timed section by hours.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void seedCheckpoint({required int secondsLeft, required Duration ago}) {
    SharedPreferences.setMockInitialValues({
      'exam_checkpoint_a2': jsonEncode({
        'level': 'a2',
        'exam_id': 'timed-paper',
        'blueprint_version': 'test',
        'section_index': 0,
        'question_index': 0,
        'seconds_left': secondsLeft,
        'answers': <String, dynamic>{},
        'saved_at': DateTime.now().subtract(ago).toIso8601String(),
      }),
    });
  }

  Future<void> pumpAndResume(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          examRepositoryProvider.overrideWithValue(_TimedRepository()),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: const MockExamScreen(level: ExamLevel.a2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Resume Exam'));
    await tester.tap(find.text('Resume Exam'));
    await tester.pump();
  }

  /// The countdown as shown, in seconds.
  int shownSeconds(WidgetTester tester) {
    final clock = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere(
          (text) => RegExp(r'\d+:\d{2}$').hasMatch(text),
          orElse: () => '',
        );
    expect(clock, isNotEmpty, reason: 'no countdown on screen');
    final match = RegExp(r'(\d+):(\d{2})$').firstMatch(clock)!;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  testWidgets('time spent away is taken off the section clock', (tester) async {
    // 5 minutes left when the app was quit, 3 minutes ago.
    seedCheckpoint(secondsLeft: 300, ago: const Duration(minutes: 3));
    await pumpAndResume(tester);

    // Roughly 2 minutes should remain, not the full 5.
    expect(shownSeconds(tester), lessThanOrEqualTo(121));
    expect(shownSeconds(tester), greaterThan(90));
  });

  testWidgets('a section whose time ran out while away does not restart', (
    tester,
  ) async {
    seedCheckpoint(secondsLeft: 60, ago: const Duration(hours: 2));
    await pumpAndResume(tester);

    expect(shownSeconds(tester), 0);
  });

  testWidgets('an immediate resume keeps essentially all the time', (
    tester,
  ) async {
    seedCheckpoint(secondsLeft: 300, ago: Duration.zero);
    await pumpAndResume(tester);

    expect(shownSeconds(tester), greaterThan(295));
  });
}

class _TimedRepository implements ExamRepository {
  static const _blueprint = ExamBlueprint(
    product: ExamProduct.permanentResidence,
    version: 'test',
    effectiveDate: '2026-01-01',
    scoringRule: ExamScoringRule.rawPointsWrittenSpeakingGate,
  );

  static const _paper = MockExam(
    id: 'timed-paper',
    level: ExamLevel.a2,
    blueprint: _blueprint,
    totalTimeMinutes: 30,
    sections: [
      MockExamSection(
        type: ExamSectionType.reading,
        timeLimitMinutes: 30,
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
  Future<ExamResult> saveResult(ExamResult result) async => result;
}
