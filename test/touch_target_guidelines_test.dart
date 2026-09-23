import 'package:czechify/presentation/providers/course_admission_providers.dart';
import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/database/database.dart' show AppDatabase;
import 'package:czechify/domain/engines/daily_arrival_engine.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/flashcard.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/srs_card.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:czechify/domain/repositories/vocabulary_repository.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/daily_arrival_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/gamification_providers.dart';
import 'package:czechify/presentation/providers/review_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/screens/arrival/daily_arrival_screen.dart';
import 'package:czechify/presentation/screens/home/home_screen.dart';
import 'package:czechify/presentation/screens/lesson/delayed_transfer_screen.dart';
import 'package:czechify/presentation/screens/lesson/lesson_player_screen.dart';
import 'package:czechify/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:czechify/presentation/screens/review/srs_review_screen.dart';
import 'package:czechify/presentation/widgets/lesson/lesson_exercise_viewport.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lesson_session_harness.dart';
import 'support/localized_app.dart';
import 'support/shipped_exercises.dart';

const _lesson = Lesson(
  id: 1,
  unitId: 1,
  orderInUnit: 1,
  title: 'Greetings',
  description: 'Meet someone',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font
        in {
          'Bricolage Grotesque': 'BricolageGrotesque',
          'Schibsted Grotesk': 'SchibstedGrotesk',
        }.entries) {
      await (FontLoader(font.key)
        ..addFont(rootBundle.load('assets/fonts/${font.value}.ttf'))).load();
    }
  });
  late AppDatabase database;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  Future<void> mount(
    WidgetTester tester,
    Widget screen,
    double scale, {
    ReviewSessionState? review,
    DailyArrivalKind? arrival,
    Exercise? lessonExercise,
  }) async {
    // Tap-target size depends on width and text scale, not on height. A short
    // view only adds scrolling, and androidTapTargetGuideline measures a
    // control scrolled half under a fixed header at its visible size — at
    // 360×640 it failed onboarding's 61px-tall name field as 40.5px. A tall
    // view shows every control whole; check() proves nothing scrolls.
    tester.view.physicalSize = const Size(360, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          gamificationProvider.overrideWith(TestGamificationNotifier.new),
          czechTtsAvailableProvider.overrideWith((_) async => true),
          czechTtsProvider.overrideWithValue(_SilentTts()),
          continueLessonProvider.overrideWith(
            (_) async => const NextLessonInfo(
              lesson: _lesson,
              unitTitle: 'First conversations',
            ),
          ),
          revisitLessonProvider.overrideWith((_) async => null),
          dueCardCountProvider.overrideWith((_) async => 8),
          dueTransferProvider.overrideWith((_) async => []),
          if (review != null)
            reviewSessionProvider.overrideWith(() => _Review(review)),
          if (arrival != null)
            dailyArrivalStateProvider.overrideWith(
              (_) async => DailyArrivalState(
                kind: arrival,
                learnerName: 'Alex',
                streak: 3,
                dailyXp: 10,
                dailyGoalXp: 50,
                dueReviews: 8,
                lessonId: 1,
                lessonTitle: 'Greetings',
                unitTitle: 'First conversations',
              ),
            ),
          lessonAdmissionProvider(
            1,
          ).overrideWith((_) async => LessonAdmission.allowed),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
          curriculumRepositoryProvider.overrideWithValue(
            FakeCurriculumRepository(
              lesson: _lesson,
              unit: const Unit(
                id: 1,
                title: 'First conversations',
                description: '',
                phase: Phase.a1,
                orderIndex: 1,
              ),
              exercises: [lessonExercise ?? _choice],
            ),
          ),
        ],
        child: MaterialApp(
          theme: lightTheme().copyWith(platform: TargetPlatform.android),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> check(WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pump();
    try {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
    // Every control was measured whole only if nothing is below the fold.
    for (final scrollable in tester.stateList<ScrollableState>(
      find.byType(Scrollable),
    )) {
      final position = scrollable.position;
      if (position.axis == Axis.vertical) {
        expect(
          position.maxScrollExtent,
          0,
          reason: 'a control could be out of view; make the test view taller',
        );
      }
    }
  }

  final shipped = loadShippedExercises();
  for (final scale in [1.0, 2.0]) {
    testWidgets('Home targets at ${scale}x', (tester) async {
      await mount(tester, const HomeScreen(), scale);
      await check(tester);
    });
    testWidgets('lesson player targets at ${scale}x', (tester) async {
      await mount(tester, const LessonPlayerScreen(lessonId: 1), scale);
      await check(tester);
      await tester.ensureVisible(find.text('Goodbye'));
      await tester.tap(find.text('Goodbye'));
      await tester.pumpAndSettle();
      await check(tester);
    });
    for (final kind in DailyArrivalKind.values) {
      testWidgets('Daily Arrival ${kind.name} targets at ${scale}x', (
        tester,
      ) async {
        await mount(tester, const DailyArrivalScreen(), scale, arrival: kind);
        await check(tester);
      });
    }
    for (final type in shipped.map((e) => e.type).toSet()) {
      final exercise = shipped.firstWhere((e) => e.type == type);
      testWidgets('exercise ${type.name} targets at ${scale}x', (tester) async {
        await mount(
          tester,
          Scaffold(
            body: LessonExerciseViewport(
              exercise: exercise,
              onAnswered: (_) {},
            ),
          ),
          scale,
        );
        await check(tester);
      });
    }
    for (final direction in CardDirection.values) {
      for (final flipped in [false, true]) {
        testWidgets(
          'review ${direction.name} flipped=$flipped targets at ${scale}x',
          (tester) async {
            await mount(
              tester,
              const SrsReviewScreen(),
              scale,
              review: ReviewSessionState(
                isLoading: false,
                isFlipped: flipped,
                dueCards: [
                  SessionCard(
                    ReviewCard(
                      flashcard: const Flashcard(
                        id: 1,
                        wordCz: 'pes',
                        wordEn: 'dog',
                        exampleCz: 'To je pes.',
                        exampleEn: 'That is a dog.',
                      ),
                      srs: SrsCard(
                        id: '1',
                        cardType: CardType.vocabulary,
                        due: DateTime(2026),
                        state: CardState.review,
                        reps: 3,
                      ),
                    ),
                    direction,
                  ),
                ],
              ),
            );
            await check(tester);
          },
        );
      }
    }
    testWidgets('onboarding all steps targets at ${scale}x', (tester) async {
      await mount(tester, const OnboardingScreen(), scale);
      await check(tester);
      await tester.tap(find.text('Start learning free'));
      await tester.pumpAndSettle();
      for (var step = 1; step <= 7; step++) {
        expect(find.text('$step / 7'), findsOneWidget);
        await check(tester);
        if (step < 7) {
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
        }
      }
    });
  }
}

const _choice = Exercise(
  id: 1,
  lessonId: 1,
  type: ExerciseType.multipleChoice,
  prompt: 'What does “Dobrý den” mean?',
  data: {
    'options': ['Good day', 'Goodbye'],
    'correct_index': 0,
    'question_cz': 'Dobrý den',
  },
  answerKey: 'Good day',
);

class _SilentTts implements CzechTts {
  @override
  final ValueNotifier<bool> usingFallbackVoice = ValueNotifier(false);
  @override
  Future<void> speak(String text, {double? rate}) async {}
  @override
  Future<void> stop() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Review extends ReviewSessionNotifier {
  _Review(this.initial);
  final ReviewSessionState initial;
  @override
  ReviewSessionState build() => initial;
  @override
  Future<void> loadDueCards() async {}
}
