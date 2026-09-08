import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/presentation/widgets/lesson/lesson_exercise_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';
import 'support/shipped_exercises.dart';

/// The shipped exercises, rendered on a small screen and at 200% text.
///
/// `lesson_exercise_viewport_test.dart` renders the same content at 400x700
/// and default text, which every exercise already survived — so nothing caught
/// that 109 of the 151 listening exercises overflowed on a 320x568 phone, or
/// that at 200% text the listening, matching, reading and error-correction
/// families all did. An overflow here is content the learner cannot reach.
///
/// The rule these layouts follow: anything that grows with the text scale goes
/// inside the scrollable. Only an action may be pinned outside it.
void main() {
  const configs = [
    (label: '320x568 at default text', size: Size(320, 568), scale: 1.0),
    (label: '400x700 at 200% text', size: Size(400, 700), scale: 2.0),
  ];

  /// Types still known to overflow, by configuration.
  ///
  /// `matching` is not fixed here on purpose: `matching_view.dart` is also
  /// changed by the open "recorded teacher voice" PR, and editing it now would
  /// manufacture a conflict. Fix it once that lands and delete the entry —
  /// this test fails if the set stops matching reality in either direction, so
  /// it cannot rot into a silent exclusion.
  const knownOverflowing = <String, Set<ExerciseType>>{
    '320x568 at default text': {},
    '400x700 at 200% text': {ExerciseType.matching},
  };

  for (final config in configs) {
    testWidgets('shipped exercises fit ${config.label}', (tester) async {
      tester.view.physicalSize = config.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final exercises =
          loadShippedExercises()
              .where((e) => LessonExerciseViewport.usesBoundedHeight(e.type))
              .toList();
      expect(exercises, hasLength(478));

      final overflowing = <ExerciseType>{};
      final examples = <String>[];

      for (final exercise in exercises) {
        // Overflow is reported through FlutterError rather than thrown, so it
        // has to be captured rather than caught.
        final errors = <String>[];
        final priorOnError = FlutterError.onError;
        FlutterError.onError =
            (details) => errors.add(details.exceptionAsString());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: lightTheme(),
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(config.scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
              home: Scaffold(
                body: LessonExerciseViewport(
                  key: ValueKey(exercise.id),
                  exercise: exercise,
                  onAnswered: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        FlutterError.onError = priorOnError;

        if (errors.isNotEmpty) {
          overflowing.add(exercise.type);
          if (examples.length < 5) {
            examples.add(
              'exercise ${exercise.id} (${exercise.type.name}): ${errors.first}',
            );
          }
        }
      }

      // Leave the tree empty so a failure reports the counts, not a pending
      // render of the last exercise.
      await tester.pumpWidget(const SizedBox());

      expect(
        overflowing,
        knownOverflowing[config.label],
        reason:
            'Exercise types overflowing at ${config.label} changed.\n'
            'If a type was fixed, remove it from knownOverflowing.\n'
            'If a type regressed, it has content the learner cannot reach.\n'
            '${examples.join('\n')}',
      );
    });
  }
}
