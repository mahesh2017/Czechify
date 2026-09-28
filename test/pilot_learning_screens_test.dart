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

import 'support/course_units.dart';
import 'support/lesson_session_harness.dart';
import 'support/localized_app.dart';
import 'support/shipped_exercises.dart';

/// Pilot, step 5: the learning screens around the exercises fit a small phone
/// too — the notebook step's comparison and the Rule sheet — and the
/// pre-lesson word list, whose words do not yet match the v1.2 lessons, is
/// skipped. Covers every unit switched on ([courseUnits]).
void main() {
  final shipped = loadShippedExercises();
  final pilot =
      shipped.where((e) => courseUnits.contains(e.lessonId ~/ 100)).toList();

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

    test('is skipped: each lesson teaches its own words', () async {
      final state = await load(courseUnits.first);
      expect(state.isTeaching, isFalse);
      // The cards are still there for review.
      expect(state.teachCards, isNotEmpty);
    });
  });

  testWidgets('each pilot notebook step fits before and after "Check '
      'against the model", on paper and typed', (tester) async {
    smallPhone(tester);
    final steps = pilot.where((e) => e.data['style'] == 'notebook').toList();
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
          // Notes as long as a learner writes them, not one phrase.
          await tester.enterText(
            find.byType(TextField),
            'Dobrý den. Ahoj.\nten muž, ten pes, ten dům\n'
            'ta žena, ta káva, ta kniha\nto dítě, to auto, to okno',
          );
        }
        await tester.tap(check);
        await tester.pumpAndSettle();
        if (scrolls(tester) > 1) problems.add('$label: the comparison scrolls');
        // A long model or long notes put the comparison on slides; what the
        // learner typed comes first, the answers last.
        if (!paper) {
          expect(
            find.textContaining('Dobrý den. Ahoj.'),
            findsOneWidget,
            reason: label,
          );
        }
        while (find.text('All correct').evaluate().isEmpty &&
            find.byKey(SlideDeck.nextKey).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(SlideDeck.nextKey));
          await tester.pumpAndSettle();
          if (scrolls(tester) > 1) {
            problems.add('$label: a comparison slide scrolls');
          }
        }
        expect(find.text('All correct'), findsOneWidget, reason: label);
        expect(tester.takeException(), isNull, reason: label);
      }
    }
    expect(problems, isEmpty);
  });

  testWidgets('the first notebook step shows the intro on a screen of its '
      'own', (tester) async {
    smallPhone(tester);
    final step = pilot.firstWhere((e) => e.data['style'] == 'notebook');
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

  testWidgets('in the last lesson of each pilot unit, the Rule sheet lists '
      'the rules so far and opens each as slides that fit', (tester) async {
    smallPhone(tester);
    bool isLecture(Exercise e) =>
        e.type == ExerciseType.teaching && e.data['style'] == 'lecture';
    var sheetsOpened = 0;
    for (final unit in courseUnits) {
      final exercises = pilot.where((e) => e.lessonId ~/ 100 == unit).toList();
      final lessonIds = {for (final e in exercises) e.lessonId}.toList()..sort();
      final lessons = [
        for (final (i, id) in lessonIds.indexed)
          Lesson(
            id: id,
            unitId: unit,
            orderInUnit: i,
            title: 'Lesson',
            description: '',
          ),
      ];
      final last = lessons.last;
      final current = exercises.where((e) => e.lessonId == last.id).toList();
      final lectures = exercises.where(isLecture).toList();
      // What the sheet lists at the last lesson's first step: every earlier
      // lesson's rules, and that step if it is one.
      final listed = [
        for (final l in lectures)
          if (l.lessonId != last.id || l.id == current.first.id) l,
      ];
      if (listed.isEmpty) continue;

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            lessonSessionProvider.overrideWith(
              () => _Session(LessonSessionState(lesson: last, exercises: current)),
            ),
            lessonAdmissionProvider(
              last.id,
            ).overrideWith((_) async => LessonAdmission.allowed),
            czechTtsProvider.overrideWithValue(_Tts()),
            unitLessonsProvider(unit).overrideWith((_) async => lessons),
            unitLectureStepsProvider(unit).overrideWith((_) async => lectures),
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
            home: LessonPlayerScreen(lessonId: last.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recap'));
      await tester.pumpAndSettle();
      sheetsOpened++;

      final sheet = find.byType(BottomSheet);
      Future<void> checkSlides(Exercise lecture) async {
        final deck = tester.state<SlideDeckState>(
          find.descendant(of: sheet, matching: find.byType(SlideDeck)),
        );
        for (var page = 0; page < deck.length; page++) {
          deck.goTo(page);
          await tester.pump();
          expect(
            scrolls(tester, sheet),
            lessThan(1),
            reason: 'Unit $unit: ${lecture.id} slide ${page + 1} scrolls',
          );
        }
      }

      if (listed.length == 1) {
        // One rule opens straight away.
        await checkSlides(listed.single);
      } else {
        expect(
          scrolls(tester, sheet),
          lessThan(1),
          reason: 'Unit $unit: the list scrolls',
        );
        for (final lecture in listed) {
          await tester.tap(find.byKey(ValueKey('rule-${lecture.id}')));
          await tester.pumpAndSettle();
          await checkSlides(lecture);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull, reason: 'Unit $unit');
    }
    expect(sheetsOpened, greaterThan(0), reason: 'no Rule sheet was checked');
  });

  testWidgets('Recap reopens a word list this lesson already taught, '
      'and "Back to the lesson" returns to the same step', (tester) async {
    smallPhone(tester);
    // Past the one-time notebook intro, so the step is the task itself.
    SharedPreferences.setMockInitialValues({'notebook_intro_seen': true});
    final lesson = pilot.where((e) => e.lessonId == 201).toList();
    final wordList = lesson.firstWhere((e) => e.id == 2101);
    final notebook = lesson.indexWhere((e) => e.id == 2102);
    const unit = Lesson(
      id: 201,
      unitId: 2,
      orderInUnit: 0,
      title: 'Lesson',
      description: '',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lessonSessionProvider.overrideWith(
            () => _Session(
              LessonSessionState(
                lesson: unit,
                exercises: lesson,
                currentIndex: notebook,
                resumed: true,
              ),
            ),
          ),
          lessonAdmissionProvider(
            201,
          ).overrideWith((_) async => LessonAdmission.allowed),
          czechTtsProvider.overrideWithValue(_Tts()),
          unitLessonsProvider(2).overrideWith((_) async => [unit]),
          unitLectureStepsProvider(2).overrideWith((_) async => []),
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
          home: const LessonPlayerScreen(lessonId: 201),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Resuming offers a fresh start as well as carrying on.
    expect(find.text('Start from the beginning'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recap'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    // The only thing taught before the notebook step is the word list, so it
    // opens straight away, as the lesson showed it.
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(wordList.data['heading'] as String),
      ),
      findsWidgets,
    );
    final deck = tester.state<SlideDeckState>(
      find.descendant(of: sheet, matching: find.byType(SlideDeck)),
    );
    deck.goTo(deck.length - 1);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Back to the lesson')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    // Nothing was answered: the learner is on the notebook step still.
    expect(find.text('Check against the model'), findsOneWidget);
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
