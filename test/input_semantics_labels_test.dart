import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/widgets/lesson/exercise_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';
import 'support/shipped_exercises.dart';

/// What TalkBack hears when it lands on an answer field.
///
/// Giving inputs a 48dp tap area wrapped each field in a labelled, merged
/// semantics node. That repeated a label the field already had — dictation
/// read "Type what you heard" twice — and named every fill-in-the-blank gap
/// with the exercise's raw sentence, underscores and glosses included.
void main() {
  final shipped = loadShippedExercises();
  final blankPattern = RegExp(r'_+');
  int blanksIn(Exercise e) =>
      '${e.data['sentence']}'.split(blankPattern).length - 1;

  Future<List<String>> fieldLabels(WidgetTester tester, Exercise exercise) async {
    // Disposed inside the test body: flutter_test checks for a live handle
    // before any addTearDown callback runs.
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [czechTtsProvider.overrideWithValue(_SilentTts())],
          child: MaterialApp(
            theme: lightTheme(),
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            // The listening panel pulses for as long as it is shown, so
            // nothing would ever settle with motion on.
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExerciseWidget(exercise: exercise, onAnswered: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return [
        for (final node in tester.semantics.simulatedAccessibilityTraversal())
          if (node.getSemanticsData().flagsCollection.isTextField)
            node.getSemanticsData().label,
      ];
    } finally {
      semantics.dispose();
    }
  }

  testWidgets('dictation names its field once', (tester) async {
    final dictation = shipped.firstWhere((e) => e.type.name == 'dictation');

    expect(await fieldLabels(tester, dictation), ['Type what you heard']);
  });

  testWidgets('a single blank is simply the answer field', (tester) async {
    final oneBlank = shipped.firstWhere(
      (e) => e.data['sentence'] is String && blanksIn(e) == 1,
    );

    expect(await fieldLabels(tester, oneBlank), ['Your answer']);
  });

  testWidgets('several blanks are numbered, and no label reads the sentence', (
    tester,
  ) async {
    final threeBlanks = shipped.firstWhere(
      (e) => e.data['sentence'] is String && blanksIn(e) == 3,
    );

    final labels = await fieldLabels(tester, threeBlanks);

    expect(labels, ['Your answer 1', 'Your answer 2', 'Your answer 3']);
    expect(labels.where((label) => label.contains('_')), isEmpty);
  });
}

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
