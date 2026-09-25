import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/flashcard.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:czechify/domain/repositories/vocabulary_repository.dart';
import 'package:czechify/presentation/providers/course_admission_providers.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/gamification_providers.dart';
import 'package:czechify/presentation/providers/lesson_providers.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/screens/grammar/unit_notebook_screen.dart';
import 'package:czechify/presentation/screens/lesson/lesson_player_screen.dart';
import 'package:czechify/presentation/widgets/common/slide_deck.dart';
import 'package:czechify/presentation/widgets/lesson/lesson_exercise_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lesson_session_harness.dart';
import 'support/localized_app.dart';
import 'support/shipped_exercises.dart';

/// Unit 2 pilot, step 5: the learning screens around the exercises fit a
/// small phone too — the notebook step's comparison and the Rule sheet — and
/// the pre-lesson word list, whose words do not yet match the v1.2 lessons,
/// is skipped.
void main() {
  final unit2 = loadShippedExercises().where((e) => e.lessonId ~/ 100 == 2);

  setUpAll(() async {
    for (final font in {
      'Bricolage Grotesque': 'BricolageGrotesque',
      'Schibsted Grotesk': 'SchibstedGrotesk',
    }.entries) {
      await (FontLoader(font.key)
        ..addFont(rootBundle.load('assets/fonts/${font.value}.ttf'))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  double scrolls(WidgetTester tester, [Finder? within]) {
    var worst = 0.0;
    final scrollables =
        within == null
            ? find.byType(Scrollable)
            : find.descendant(of: within, matching: find.byType(Scrollable));
    for (final s in tester.stateList<ScrollableState>(scrollables)) {
      final p = s.position;
      if (p.axis == Axis.vertical &&
          p.hasContentDimensions &&
          p.maxScrollExtent > worst) {
        worst = p.maxScrollExtent;
      }
    }
    return worst;
  }

  void smallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 20);
    addTearDown(tester.view.reset);
  }

  group('the pre-lesson word list', () {
    Future<LessonSessionState> load(int unitId) async {
      final lesson = Lesson(
        id: unitId * 100 + 1,
        unitId: unitId,
        orderInUnit: 0,
        title: 'Lesson',
        description: '',
      );
      final container = ProviderContainer(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
          curriculumRepositoryProvider.overrideWithValue(
            FakeCurriculumRepository(
              lesson: lesson,
              unit: Unit(
                id: unitId,
                title: 'Unit',
                description: '',
                phase: Phase.a1,
                orderIndex: unitId,
              ),
              exercises: const [
                Exercise(
                  id: 1,
                  lessonId: 1,
                  type: ExerciseType.multipleChoice,
                  prompt: 'Hello?',
                  data: {
                    'options': ['Ahoj', 'Dům'],
                    'correct_index': 0,
                  },
                ),
              ],
            ),
          ),
          vocabularyRepositoryProvider.overrideWithValue(_Words()),
          gamificationProvider.overrideWith(TestGamificationNotifier.new),
          settingsProvider.overrideWith(_Settings.new),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(lessonSessionProvider.notifier)
          .loadLesson(lesson.id);
      return container.read(lessonSessionProvider);
    }

    test('is skipped in Unit 2, whose lessons teach their own words', () async {
      final state = await load(2);
      expect(state.isTeaching, isFalse);
      // The cards are still there for review.
      expect(state.teachCards, isNotEmpty);
    });

    test('is still shown outside the pilot', () async {
      expect((await load(6)).isTeaching, isTrue);
    });
  });

  testWidgets('each Unit 2 notebook step fits before and after "Check '
      'against the model", on paper and typed', (tester) async {
    smallPhone(tester);
    final steps = unit2.where((e) => e.data['style'] == 'notebook').toList();
    expect(steps, isNotEmpty);
    final problems = <String>[];
    for (final step in steps) {
      for (final paper in [true, false]) {
        // The one-time intro has been seen, as on every step after the first.
        SharedPreferences.setMockInitialValues({'notebook_intro_seen': true});
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              settingsProvider.overrideWith(
                () => _Settings(notesOnPaper: paper),
              ),
              czechTtsProvider.overrideWithValue(_Tts()),
            ],
            child: MaterialApp(
              theme: lightTheme(),
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              home: Scaffold(
                body: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    // The lesson's exercise area on an iPhone SE.
                    child: SizedBox(
                      height: 557,
                      child: LessonExerciseViewport(
                        exercise: step,
                        onAnswered: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = '${step.id} ${paper ? 'on paper' : 'typed'}';
        if (scrolls(tester) > 1) problems.add('$label: the task scrolls');
        final check = find.text('Check against the model');
        if (check.evaluate().isEmpty) continue;
        if (!paper) {
          await tester.enterText(find.byType(TextField), 'Dobrý den. Ahoj.');
        }
        await tester.tap(check);
        await tester.pumpAndSettle();
        if (scrolls(tester) > 1) problems.add('$label: the comparison scrolls');
        expect(find.text('All correct'), findsOneWidget, reason: label);
        if (!paper) {
          expect(find.text('Dobrý den. Ahoj.'), findsOneWidget, reason: label);
        }
        expect(tester.takeException(), isNull, reason: label);
      }
    }
    expect(problems, isEmpty);
  });

  testWidgets('the first notebook step shows the intro on a screen of its '
      'own', (tester) async {
    smallPhone(tester);
    final step = unit2.firstWhere((e) => e.data['style'] == 'notebook');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _Settings(notesOnPaper: true)),
          czechTtsProvider.overrideWithValue(_Tts()),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: LessonExerciseViewport(exercise: step, onAnswered: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keep a Czech notebook'), findsOneWidget);
    expect(find.text('Check against the model'), findsNothing);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Keep a Czech notebook'), findsNothing);
    expect(find.text('Check against the model'), findsOneWidget);
  });

  testWidgets('the Rule sheet lists the rules so far and opens each as '
      'slides that fit', (tester) async {
    smallPhone(tester);
    final lessonD =
        unit2.where((e) => e.lessonId == 204).toList();
    final lectures =
        unit2
            .where(
              (e) =>
                  e.type == ExerciseType.teaching &&
                  e.data['style'] == 'lecture',
            )
            .toList();
    final lessons = [
      for (var i = 0; i < 4; i++)
        Lesson(
          id: 201 + i,
          unitId: 2,
          orderInUnit: i,
          title: 'Lesson',
          description: '',
        ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lessonSessionProvider.overrideWith(
            () => _Session(
              LessonSessionState(lesson: lessons[3], exercises: lessonD),
            ),
          ),
          lessonAdmissionProvider(
            204,
          ).overrideWith((_) async => LessonAdmission.allowed),
          czechTtsProvider.overrideWithValue(_Tts()),
          unitLessonsProvider(2).overrideWith((_) async => lessons),
          unitLectureStepsProvider(2).overrideWith((_) async => lectures),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
          home: const LessonPlayerScreen(lessonId: 204),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rule'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(scrolls(tester, sheet), lessThan(1), reason: 'the list scrolls');
    for (final lecture in lectures) {
      await tester.tap(find.byKey(ValueKey('rule-${lecture.id}')));
      await tester.pumpAndSettle();
      final deck = tester.state<SlideDeckState>(
        find.descendant(of: sheet, matching: find.byType(SlideDeck)),
      );
      for (var page = 0; page < deck.length; page++) {
        deck.goTo(page);
        await tester.pump();
        expect(
          scrolls(tester, sheet),
          lessThan(1),
          reason: '${lecture.id} slide ${page + 1} scrolls',
        );
      }
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}

class _Words implements VocabularyRepository {
  @override
  Future<List<Flashcard>> getCardsForLesson(int lessonId) async => const [
    Flashcard(id: 1, wordCz: 'dobrý den', wordEn: 'hello'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsNotifier {
  _Settings({this.notesOnPaper = true});
  final bool notesOnPaper;

  @override
  AppSettings build() => AppSettings(notesOnPaper: notesOnPaper);
}

class _Session extends LessonSessionNotifier {
  _Session(this.initial);
  final LessonSessionState initial;

  @override
  LessonSessionState build() => initial;

  @override
  Future<void> loadLesson(int lessonId) async {}
}

class _Tts implements CzechTts {
  @override
  final usingFallbackVoice = ValueNotifier(false);
  @override
  Future<void> speak(String text, {double? rate}) async {}
  @override
  Future<void> speakSlow(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
