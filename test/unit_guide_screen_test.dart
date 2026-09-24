import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:czechify/presentation/screens/grammar/unit_guide_screen.dart';
import 'package:czechify/presentation/screens/grammar/unit_notebook_screen.dart';
import 'package:czechify/presentation/widgets/lesson/exercise_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

/// The Unit 2 pilot of the unit guide: grammar first (by lesson, the last
/// finished lesson open), then key phrases, then the notebook page collapsed
/// unless the unit's closing check asked for it.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const lessons = [
    Lesson(id: 201, unitId: 2, orderInUnit: 0, title: 'Hello', description: ''),
    Lesson(id: 202, unitId: 2, orderInUnit: 1, title: 'Names', description: ''),
    Lesson(id: 203, unitId: 2, orderInUnit: 2, title: 'Origin', description: ''),
    Lesson(id: 204, unitId: 2, orderInUnit: 3, title: 'Mission', description: ''),
  ];

  Exercise lecture(int id, int lessonId, String heading, String right) => Exercise(
    id: id,
    lessonId: lessonId,
    type: ExerciseType.teaching,
    prompt: 'Lecture',
    data: {
      'style': 'lecture',
      'heading': heading,
      'say': 'Explanation of $heading.',
      'table': [
        ['cue', right],
      ],
      'examples': const [],
      'items': const [],
    },
  );

  final lectures = [
    lecture(2201, 202, 'Formal or friendly', 'Dobrý den.'),
    lecture(2203, 202, 'Speaking to someone', 'pane Nováku!'),
    lecture(2302, 203, 'Polite words', 'prosím'),
  ];

  const page = {
    'title_cz': 'Pozdravy',
    'can_do': {'cz': 'Pozdravím.', 'en': 'I can greet people.'},
    'words': [
      {'cz': 'Dobrý den.', 'en': 'Hello.'},
    ],
    'pattern': {'rule_plain': 'vy for strangers.'},
    'my_sentences_models': [
      {'cz': 'Jmenuju se Anna.', 'en': 'My name is Anna.'},
    ],
  };

  Future<void> pump(
    WidgetTester tester, {
    Set<int> completed = const {},
    bool openNotebook = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unlockedUnitIdsProvider.overrideWith((ref) async => {1, 2}),
          modelNotebookPagesProvider.overrideWith((ref) async => {2: page}),
          unitLessonsProvider(2).overrideWith((ref) async => lessons),
          unitLectureStepsProvider(2).overrideWith((ref) async => lectures),
          unitCheckItemsProvider(2).overrideWith(
            (ref) async => [(cz: 'Dobrý den × Ahoj', en: 'formal × friendly')],
          ),
          completedLessonIdsProvider.overrideWith((ref) async => completed),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: UnitGuideScreen(unitId: 2, openNotebook: openNotebook),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a new learner sees the goal, rules labelled by the lesson that '
      'teaches them, and the notebook page closed', (tester) async {
    await pump(tester);

    expect(find.text('I can greet people.'), findsOneWidget);
    expect(find.text('Lesson B · Names'), findsOneWidget);
    expect(find.text('Formal or friendly'), findsOneWidget);
    // Lesson A is the one they are on; B and C say once each that they have
    // not been reached yet.
    expect(find.text('Not reached yet'), findsNWidgets(2));
    // Nothing opens by itself before its lesson.
    expect(find.text('Explanation of Formal or friendly.'), findsNothing);
    await tester.scrollUntilVisible(find.text('Your notebook page'), 300);
    expect(find.text('Your notebook page'), findsOneWidget);
    expect(find.text('Save page as image'), findsNothing);
  });

  testWidgets('after Lesson B its rules are open; the lesson in progress is '
      'reached but closed', (tester) async {
    await pump(tester, completed: {201, 202});

    expect(find.text('Not reached yet'), findsNothing);
    expect(find.text('Explanation of Formal or friendly.'), findsOneWidget);
    expect(find.text('Explanation of Speaking to someone.'), findsOneWidget);
    expect(find.text('Explanation of Polite words.'), findsNothing);
  });

  testWidgets('a rule not reached yet still opens on tap', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Speaking to someone'));
    await tester.pumpAndSettle();

    expect(find.text('Explanation of Speaking to someone.'), findsOneWidget);
    expect(find.text('pane Nováku!'), findsOneWidget);
  });

  testWidgets('from the closing check the notebook page opens, with plain '
      'section names and a real checklist', (tester) async {
    await pump(tester, openNotebook: true);

    expect(find.text('Key phrases'), findsWidgets);
    expect(find.text('The rule'), findsOneWidget);
    expect(find.text('Your own sentences (examples)'), findsOneWidget);
    expect(find.text('Check ✓'), findsNothing);

    final item = find.text('Dobrý den × Ahoj');
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('unit_guide_checked_2'), ['0']);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpUnitCheck(WidgetTester tester, int unitId) async {
    final lessonId = unitId * 100 + 4;
    final check = Exercise(
      id: unitId * 1000 + 409,
      lessonId: lessonId,
      type: ExerciseType.teaching,
      prompt: 'Notebook',
      data: const {
        'style': 'notebook',
        'kind': 'unit_check',
        'heading': 'Check your page',
        'instruction': 'Compare your page with the model.',
        'items': [
          {'cz': 'Dobrý den × Ahoj', 'en': 'formal × friendly'},
        ],
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_OnPaper.new),
          lessonProvider(lessonId).overrideWith(
            (ref) async => Lesson(
              id: lessonId,
              unitId: unitId,
              orderInUnit: 3,
              title: 'Mission',
              description: '',
            ),
          ),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExerciseWidget(exercise: check, onAnswered: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check against the model'));
    await tester.pumpAndSettle();
  }

  testWidgets('the closing check links to the whole model page in Unit 2', (
    tester,
  ) async {
    await pumpUnitCheck(tester, 2);
    expect(find.text('See the whole model page'), findsOneWidget);
  });

  testWidgets('outside the pilot the closing check has no link', (
    tester,
  ) async {
    await pumpUnitCheck(tester, 6);
    expect(find.text('See the whole model page'), findsNothing);
  });

  test('the pilot covers Unit 2 only', () {
    expect(unitGuideEnabled(2), isTrue);
    expect(unitGuideEnabled(6), isFalse);
    expect(unitGuideEnabled(null), isFalse);
    expect(lessonLetter(0), 'A');
    expect(lessonLetter(3), 'D');
  });
}

class _OnPaper extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(notesOnPaper: true);
}
