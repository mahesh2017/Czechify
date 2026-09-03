import 'dart:async';

import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exam_result.dart';
import 'package:czechify/domain/repositories/exam_repository.dart';
import 'package:czechify/domain/repositories/speech_ports.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/stt_providers.dart';
import 'package:czechify/presentation/screens/exam/mock_exam_screen.dart';
import 'package:czechify/presentation/widgets/common/record_button.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart'
    show QuestionPrompt;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('rapid next taps advance only one exam question', (tester) async {
    await _pumpExam(tester);

    await tester.tap(find.text('Start Exam'));
    await tester.pump();
    expect(find.text('Question one'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pump();
    // Let the Material tap ripple and input-debounce timer finish; neither is
    // part of the question transition under test.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Question two'), findsOneWidget);
    expect(find.text('Question three'), findsNothing);
    expect(find.text('Q2/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('countdown ticks do not rebuild the active question', (
    tester,
  ) async {
    await _pumpExam(tester);
    await tester.tap(find.text('Start Exam'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final before = tester.widget<QuestionPrompt>(find.byType(QuestionPrompt));
    await tester.pump(const Duration(seconds: 1));
    final after = tester.widget<QuestionPrompt>(find.byType(QuestionPrompt));

    expect(identical(after, before), isTrue);
    expect(find.text('Question one'), findsOneWidget);
  });

  testWidgets('exam question uses directional incoming-only motion', (
    tester,
  ) async {
    await _pumpExam(tester);
    await tester.tap(find.text('Start Exam'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump();

    final transition = find.byKey(const ValueKey('0:1'));
    expect(transition, findsOneWidget);
    expect(find.text('Question one'), findsNothing);
    expect(find.text('Question two'), findsOneWidget);
    final translation = tester.widget<FractionalTranslation>(
      find.descendant(
        of: transition,
        matching: find.byType(FractionalTranslation),
      ),
    );
    expect(translation.translation.dx, greaterThan(0));
  });

  testWidgets('exam question snaps to its final state with reduced motion', (
    tester,
  ) async {
    await _pumpExam(tester, disableAnimations: true);
    tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('Start Exam'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed!();
    await tester.pump();
    tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('Next'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed!();
    await tester.pump();
    await tester.pump();

    final transition = find.byKey(const ValueKey('0:1'));
    final translation = tester.widget<FractionalTranslation>(
      find.descendant(
        of: transition,
        matching: find.byType(FractionalTranslation),
      ),
    );
    expect(translation.translation, Offset.zero);
  });

  testWidgets('leaving and returning cannot apply a stale speaking result', (
    tester,
  ) async {
    final transcriber = _ControlledTranscriber();
    await _pumpExam(
      tester,
      repository: _SpeakingExamRepository(),
      transcriber: transcriber,
    );
    await tester.tap(find.text('Start Exam'));
    await tester.pump();

    await tester.ensureVisible(find.byType(RecordButton));
    await tester.tap(find.byType(RecordButton));
    await tester.pump();
    expect(find.text('Listening...'), findsOneWidget);

    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(transcriber.stopCalls, 1);

    await tester.tap(find.text('Previous'));
    await tester.pump();
    transcriber.complete('Ahoj');
    await tester.pump();

    expect(find.text('Speak one'), findsOneWidget);
    expect(find.textContaining(' / 100'), findsNothing);
    expect(find.textContaining('Heard:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid finish input submits the exam exactly once', (
    tester,
  ) async {
    final repository = _FinishingExamRepository();
    await _pumpExam(tester, repository: repository);
    await tester.tap(find.text('Start Exam'));
    await tester.pump();

    final finish = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Finish Exam'),
        matching: find.byType(FilledButton),
      ),
    );
    finish.onPressed!();
    finish.onPressed!();
    await tester.pump();

    expect(repository.saveCalls, 1);
    expect(find.text('Evaluating your answers...'), findsOneWidget);

    repository.complete();
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 1);
    expect(find.text('Exam results'), findsOneWidget);
  });
}

Future<void> _pumpExam(
  WidgetTester tester, {
  ExamRepository? repository,
  LiveTranscriber? transcriber,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        examRepositoryProvider.overrideWithValue(
          repository ?? _FakeExamRepository(),
        ),
        liveTranscriberProvider.overrideWithValue(
          transcriber ?? _FakeTranscriber(),
        ),
      ],
      child: MaterialApp(
        theme: lightTheme(),
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        builder:
            disableAnimations
                ? (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                )
                : null,
        home: const MockExamScreen(level: ExamLevel.a2),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Start Exam'));
  await tester.pump();
}

class _SpeakingExamRepository extends _FakeExamRepository {
  @override
  Future<MockExam> getMockExam(
    ExamLevel level, {
    ExamProduct product = ExamProduct.permanentResidence,
  }) async => MockExam(
    level: level,
    blueprint: _FakeExamRepository._blueprint,
    totalTimeMinutes: 5,
    sections: const [
      MockExamSection(
        type: ExamSectionType.speaking,
        timeLimitMinutes: 5,
        maxScore: 2,
        questions: [
          {'prompt': 'Speak one', 'target_text': 'Ahoj', 'points': 1},
          {'prompt': 'Speak two', 'target_text': 'Dobrý den', 'points': 1},
        ],
      ),
    ],
  );
}

class _FinishingExamRepository extends _FakeExamRepository {
  final _saveCompletion = Completer<ExamResult>();
  ExamResult? _pendingResult;
  int saveCalls = 0;

  void complete() => _saveCompletion.complete(_pendingResult!);

  @override
  Future<MockExam> getMockExam(
    ExamLevel level, {
    ExamProduct product = ExamProduct.permanentResidence,
  }) async => MockExam(
    level: level,
    blueprint: _FakeExamRepository._blueprint,
    totalTimeMinutes: 5,
    sections: const [
      MockExamSection(
        type: ExamSectionType.reading,
        timeLimitMinutes: 5,
        maxScore: 1,
        questions: [
          {
            'prompt': 'Only question',
            'options': ['One A', 'One B'],
            'correct_answer': 0,
            'points': 1,
          },
        ],
      ),
    ],
  );

  @override
  Future<ExamResult> saveResult(ExamResult result) {
    saveCalls++;
    _pendingResult = result;
    return _saveCompletion.future;
  }
}

class _FakeExamRepository implements ExamRepository {
  static const _blueprint = ExamBlueprint(
    product: ExamProduct.permanentResidence,
    version: 'test',
    effectiveDate: '2026-01-01',
    scoringRule: ExamScoringRule.rawPointsWrittenSpeakingGate,
  );

  @override
  Future<MockExam> getMockExam(
    ExamLevel level, {
    ExamProduct product = ExamProduct.permanentResidence,
  }) async => MockExam(
    level: level,
    blueprint: _blueprint,
    totalTimeMinutes: 5,
    sections: const [
      MockExamSection(
        type: ExamSectionType.reading,
        timeLimitMinutes: 5,
        maxScore: 3,
        questions: [
          {
            'prompt': 'Question one',
            'options': ['One A', 'One B'],
            'correct_answer': 0,
            'points': 1,
          },
          {
            'prompt': 'Question two',
            'options': ['Two A', 'Two B'],
            'correct_answer': 0,
            'points': 1,
          },
          {
            'prompt': 'Question three',
            'options': ['Three A', 'Three B'],
            'correct_answer': 0,
            'points': 1,
          },
        ],
      ),
    ],
  );

  @override
  Future<List<ExamResult>> getResults(
    ExamLevel level, {
    ExamProduct? product,
  }) async => const [];

  @override
  Future<ExamResult> saveResult(ExamResult result) async => result;
}

class _FakeTranscriber implements LiveTranscriber {
  @override
  Future<String> listenFor({
    Duration timeout = const Duration(seconds: 30),
  }) async => 'Ahoj';

  @override
  Future<bool> supportsCzech() async => true;

  @override
  Future<void> stop() async {}
}

class _ControlledTranscriber implements LiveTranscriber {
  final _completion = Completer<String>();
  int stopCalls = 0;

  void complete(String value) => _completion.complete(value);

  @override
  Future<String> listenFor({Duration timeout = const Duration(seconds: 30)}) =>
      _completion.future;

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<bool> supportsCzech() async => true;
}
