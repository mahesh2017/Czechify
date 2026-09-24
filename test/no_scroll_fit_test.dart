import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/widgets/common/slide_deck.dart';
import 'package:czechify/presentation/widgets/lesson/lesson_exercise_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';
import 'support/shipped_exercises.dart';

/// A learner never has to scroll to read or answer a lesson step: what does
/// not fit a small phone is split into slides ([SlideDeck]).
///
/// Every shipped exercise is rendered in the lesson's exercise area on a small
/// phone, in the app's own fonts, and every slide of a deck is turned to and
/// measured. An exercise "scrolls" when any vertical scrollable in it has
/// somewhere to go.
///
/// A slide with a text field is measured again with the keyboard up (an
/// iPhone SE's, with its suggestion bar: 260 pt), because that is when a
/// learner is actually using it; those results are listed as `<id>+keyboard`.
/// A slide that fills the page instead of scrolling (`FillSlide`) counts the
/// pixels its content overflows by.
///
/// Most exercises still scroll today, so the ones that do are listed in
/// [_budgetPath] with how far. The list may only shrink:
///  - an exercise that is not listed and scrolls fails the test;
///  - a listed one that now fits, or no longer exists, fails too, so the list
///    is kept honest;
///  - a listed one that scrolls noticeably further than recorded fails.
///
/// After an intended change, re-pin with
///   UPDATE_NO_SCROLL_BUDGET=1 flutter test test/no_scroll_fit_test.dart
/// and read the diff of the budget file: a new id there is a new screen that
/// makes someone scroll.
void main() {
  // iPhone SE (375×667 pt) less the status bar (20), the slim lesson bar (52)
  // and a task row (38).
  const area = Size(375, 557);

  // Layout is deterministic, so this only absorbs sub-pixel rounding.
  const fits = 1.0;

  // How much further a listed exercise may scroll than recorded before it
  // counts as a regression: about two lines of text.
  const growth = 40;

  setUpAll(() async {
    for (final font in {
      'Bricolage Grotesque': 'BricolageGrotesque',
      'Schibsted Grotesk': 'SchibstedGrotesk',
    }.entries) {
      await (FontLoader(font.key)
        ..addFont(rootBundle.load('assets/fonts/${font.value}.ttf'))).load();
    }
  });

  testWidgets('no lesson step scrolls on a small phone beyond the budget', (
    tester,
  ) async {
    tester.view.physicalSize = area;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final exercises = loadShippedExercises();
    final measured = <String, int>{};
    var slidesTurned = 0;
    var keyboardSlides = 0;
    for (final exercise in exercises) {
      final (overflow, turned, typing) = await _measure(tester, exercise);
      slidesTurned += turned;
      if (overflow > fits) measured['${exercise.id}'] = overflow.ceil();
      if (typing != null) {
        keyboardSlides++;
        if (typing > fits) measured['${exercise.id}$_keyboard'] = typing.ceil();
      }
    }
    await tester.pumpWidget(const SizedBox());

    // A measurement that never reaches a second slide would pass every deck
    // on its first slide alone.
    expect(
      slidesTurned,
      greaterThan(0),
      reason: 'no slide deck was turned past its first slide',
    );
    // Likewise for the keyboard: a check that never raised it passes all.
    expect(
      keyboardSlides,
      greaterThan(0),
      reason: 'no slide with a text field was measured with the keyboard up',
    );

    final file = File(_budgetPath);
    if (Platform.environment['UPDATE_NO_SCROLL_BUDGET'] == '1') {
      final sorted = Map.fromEntries(
        measured.entries.toList()
          ..sort((a, b) {
            final byId = _idOf(a.key).compareTo(_idOf(b.key));
            return byId != 0 ? byId : a.key.compareTo(b.key);
          }),
      );
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
          'area': [area.width, area.height],
          'scrolls': sorted,
        })}\n',
      );
      return;
    }

    final budget = Map<String, int>.from(
      (jsonDecode(file.readAsStringSync()) as Map)['scrolls'] as Map,
    );
    final byId = {for (final e in exercises) '${e.id}': e};
    String describe(String key) {
      final e = byId['${_idOf(key)}'];
      if (e == null) return '$key (no longer shipped)';
      final style = e.data['style'] ?? e.data['kind'] ?? e.mode.name;
      return '$key (lesson ${e.lessonId}, ${e.type.name}/$style)';
    }

    final added = [
      for (final id in measured.keys)
        if (!budget.containsKey(id)) '${describe(id)}: ${measured[id]} px',
    ];
    final grew = [
      for (final id in measured.keys)
        if (budget.containsKey(id) && measured[id]! > budget[id]! + growth)
          '${describe(id)}: ${budget[id]} → ${measured[id]} px',
    ];
    final fixed = [
      for (final id in budget.keys)
        if (!measured.containsKey(id)) describe(id),
    ];

    expect(
      added,
      isEmpty,
      reason:
          'These lesson steps now need scrolling on a small phone. Split them '
          'into slides (SlideDeck) or tighten them.',
    );
    expect(
      grew,
      isEmpty,
      reason: 'These lesson steps scroll further than before.',
    );
    expect(
      fixed,
      isEmpty,
      reason:
          'These fit now (or are gone): take them off the list by re-pinning '
          'with UPDATE_NO_SCROLL_BUDGET=1.',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}

const _budgetPath = 'test/fixtures/no_scroll_budget.json';
const _keyboard = '+keyboard';

/// iPhone SE keyboard with its suggestion bar, in points.
const _keyboardHeight = 260.0;

int _idOf(String key) => int.parse(key.split('+').first);

/// How far the exercise scrolls at its worst, over every slide it has; how
/// many slides past the first it turned to; and, if a slide takes typing, how
/// far the worst of those goes with the keyboard up.
Future<(double, int, double?)> _measure(
  WidgetTester tester,
  Exercise exercise,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: lightTheme(),
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        // No motion, so a slide turn lands in one frame and nothing loops.
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: true),
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
  var worst = _verticalOverflow(tester);
  var turned = 0;
  double? typing;
  final deck = find.byType(SlideDeck);
  if (deck.evaluate().isNotEmpty) {
    final state = tester.state<SlideDeckState>(deck.first);
    for (var page = 0; page < state.length; page++) {
      if (page > 0) {
        state.goTo(page);
        await tester.pump();
        if (state.index != page) break;
        turned++;
        worst = math.max(worst, _verticalOverflow(tester));
      }
      if (find.byType(EditableText).evaluate().isEmpty) continue;
      final withKeyboard = await _withKeyboard(tester);
      typing = math.max(typing ?? 0, withKeyboard);
    }
  }
  return (worst, turned, typing);
}

/// The current slide's overflow with the keyboard up: what a scrollable would
/// have to scroll, or what a slide that fills the page overflows by.
Future<double> _withKeyboard(WidgetTester tester) async {
  final overflows = <double>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final match = RegExp(
      r'overflowed by ([0-9.]+) pixels',
    ).firstMatch(details.exceptionAsString());
    if (match == null) return previous?.call(details);
    overflows.add(double.parse(match.group(1)!));
  };
  try {
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
    await tester.pump();
    return [_verticalOverflow(tester), ...overflows].reduce(math.max);
  } finally {
    tester.view.resetViewInsets();
    await tester.pump();
    FlutterError.onError = previous;
  }
}

double _verticalOverflow(WidgetTester tester) {
  var worst = 0.0;
  for (final state in tester.stateList<ScrollableState>(
    find.byType(Scrollable),
  )) {
    final position = state.position;
    if (position.axis != Axis.vertical || !position.hasContentDimensions) {
      continue;
    }
    worst = math.max(worst, position.maxScrollExtent);
  }
  return worst;
}
