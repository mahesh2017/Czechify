import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/database/database.dart' show AppDatabase;
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/gamification_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/screens/lesson/lesson_player_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lesson_session_harness.dart';
import 'support/localized_app.dart';

/// Seen on Android on 14 Sep 2026: after a missed listening question the
/// exercise's own "0/1 correct · Retry" sat directly above the lesson's
/// "Try again". Only the lesson's retry is real — it costs a heart and climbs
/// the feedback ladder — so it has to be the only one on screen.
void main() {
  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> missTheQuestion(WidgetTester tester) async {
    await tester.ensureVisible(find.text('tea — coffee'));
    await tester.tap(find.text('tea — coffee'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await settle(tester);
  }

  testWidgets('after a missed listening question, Try again is the only retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          gamificationProvider.overrideWith(TestGamificationNotifier.new),
          // Reaches a platform channel for the installed voices.
          czechTtsAvailableProvider.overrideWith((ref) async => true),
          lessonUnlockedProvider(1).overrideWith((ref) async => true),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
          curriculumRepositoryProvider.overrideWithValue(
            FakeCurriculumRepository(
              unit: const Unit(
                id: 1,
                title: 'Hear, Read & Repair Czech',
                description: '',
                phase: Phase.a1,
                orderIndex: 1,
              ),
              lesson: const Lesson(
                id: 1,
                unitId: 1,
                orderInUnit: 1,
                title: 'Hear Czech in Useful Words',
                description: '',
              ),
              exercises: const [
                Exercise(
                  id: 1,
                  lessonId: 1,
                  type: ExerciseType.listeningComprehension,
                  prompt: 'Listen to the words. Which order did you hear?',
                  data: {
                    'transcript_cz': 'káva, čaj',
                    'questions': [
                      {
                        'question_en': 'What was the order?',
                        'options': ['coffee — tea', 'tea — coffee'],
                        'correct_index': 0,
                      },
                    ],
                  },
                ),
                Exercise(
                  id: 2,
                  lessonId: 1,
                  type: ExerciseType.multipleChoice,
                  prompt: 'What does “káva” mean?',
                  data: {
                    'options': ['coffee', 'tea'],
                    'correct_index': 0,
                  },
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: const LessonPlayerScreen(lessonId: 1),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('What was the order?'), findsOneWidget);

    await missTheQuestion(tester);

    expect(find.text('Not quite'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);

    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(find.text('Not quite'), findsNothing);
    expect(find.text('What was the order?'), findsOneWidget);
    expect(
      find.text('Check answers'),
      findsNothing,
      reason: 'the same question, with the missed selection cleared',
    );

    await missTheQuestion(tester);

    expect(
      find.text('Try again'),
      findsOneWidget,
      reason: 'the second miss still goes through the lesson',
    );
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
