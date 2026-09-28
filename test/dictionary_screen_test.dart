import 'dart:convert';
import 'dart:io';

import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/dictionary/dictionary_entry.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/dictionary_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/screens/dictionary/dictionary_entry_screen.dart';
import 'package:czechify/presentation/screens/dictionary/dictionary_screen.dart';
import 'package:czechify/presentation/widgets/common/dictionary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/localized_app.dart';

final _a1 = DictionaryData.fromJson(
  jsonDecode(File('assets/dictionary/a1_dictionary.json').readAsStringSync())
      as Map<String, dynamic>,
);

class _Tts implements CzechTts {
  final spoken = <String>[];

  @override
  final usingFallbackVoice = ValueNotifier(false);
  @override
  Future<void> speak(String text, {double? rate}) async => spoken.add(text);
  @override
  Future<void> speakSlow(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Tts tts;

  setUp(() => tts = _Tts());

  /// The app's dictionary routes, entered from a page with the button on it.
  Future<void> pump(
    WidgetTester tester, {
    String start = '/',
    Set<int> unlocked = const {1, 2, 3},
    Size size = const Size(375, 667),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(
          path: '/',
          builder:
              (context, state) => const Scaffold(
                body: SafeArea(child: Center(child: DictionaryButton())),
              ),
        ),
        GoRoute(
          path: '/dictionary',
          builder: (context, state) => const DictionaryScreen(),
          routes: [
            GoRoute(
              path: ':level/:id',
              builder:
                  (context, state) => DictionaryEntryScreen(
                    level: state.pathParameters['level']!,
                    entryId: state.pathParameters['id']!,
                  ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryProvider('a1').overrideWith((ref) async => _a1),
          unlockedUnitIdsProvider.overrideWith((ref) async => unlocked),
          czechTtsProvider.overrideWithValue(tts),
        ],
        child: MaterialApp.router(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          routerConfig: router,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the button opens the dictionary on every word, A to Z', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('open-dictionary')));
    await tester.pumpAndSettle();

    expect(find.byType(DictionaryScreen), findsOneWidget);
    expect(find.text('${_a1.entries.length} words · A1'), findsOneWidget);
    expect(find.text(_a1.entries.first.cz), findsOneWidget);
  });

  testWidgets('searching by a form finds the word and opens its page', (
    tester,
  ) async {
    await pump(tester, start: '/dictionary');
    await tester.enterText(
      find.byKey(const ValueKey('dictionary-search')),
      'kavu',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('form: kávu', findRichText: true), findsWidgets);
    await tester.tap(find.text('coffee').first);
    await tester.pumpAndSettle();

    expect(find.byType(DictionaryEntryScreen), findsOneWidget);
    expect(find.text('káva'), findsOneWidget);
    expect(find.text('noun · feminine'), findsOneWidget);
    expect(find.text('kávy'), findsOneWidget, reason: 'the plural key form');
    // Examples come from the course.
    expect(find.text('Piju kávu.'), findsOneWidget);
  });

  testWidgets('a search that finds nothing says what to try', (tester) async {
    await pump(tester, start: '/dictionary');
    await tester.enterText(
      find.byKey(const ValueKey('dictionary-search')),
      'qqxzv',
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing found for “qqxzv”.'), findsOneWidget);
  });

  testWidgets('all forms stay folded until asked for', (tester) async {
    await pump(tester, start: '/dictionary/a1/kava');
    expect(find.text('kávami'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('dictionary-all-forms')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('kávami'), 200);

    expect(find.text('kávami'), findsOneWidget);
    expect(find.text('Hide all forms'), findsOneWidget);
  });

  testWidgets('the listen button says the word', (tester) async {
    await pump(tester, start: '/dictionary/a1/kava');
    await tester.tap(find.byKey(const ValueKey('dictionary-listen')));
    await tester.pump();

    expect(tts.spoken, ['káva']);
  });

  testWidgets('a word from a unit not reached yet says so, and still opens', (
    tester,
  ) async {
    final dovolena = _a1.byCzech('dovolená')!;
    expect(dovolena.unit, greaterThan(3));

    await pump(tester, start: '/dictionary/a1/${dovolena.id}');

    expect(
      find.text(
        "You meet it in Unit ${dovolena.unit}, which you haven't reached yet.",
      ),
      findsOneWidget,
    );
    expect(find.text('holiday; vacation; leave'), findsOneWidget);
  });

  // The widest tables in the level: four columns of possessive forms, with
  // two alternatives in a cell, on a small phone at double text size.
  for (final id in ['muj', 'velky', 'jeden', 'zubni-kartacek', 'jit']) {
    testWidgets('all forms of "$id" fit a small phone at 200% text', (
      tester,
    ) async {
      await pump(
        tester,
        start: '/dictionary/a1/$id',
        size: const Size(360, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      final showAll = find.byKey(const ValueKey('dictionary-all-forms'));
      await tester.scrollUntilVisible(showAll, 200);
      await tester.ensureVisible(showAll);
      await tester.pumpAndSettle();
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      // The list builds lazily: step through it so every table is laid out.
      var tables = 0;
      for (var i = 0; i < 40; i++) {
        tables += find.byType(Table).evaluate().length;
        expect(tester.takeException(), isNull);
        // A table wider than its card does not throw; it runs off the
        // screen. So measure: every form must end inside the screen.
        final cells = find.descendant(
          of: find.byType(Table),
          matching: find.byType(Text),
        );
        for (final cell in cells.evaluate()) {
          final right = tester.getRect(find.byWidget(cell.widget)).right;
          expect(
            right,
            lessThanOrEqualTo(360),
            reason: '"${(cell.widget as Text).data}" runs off the screen',
          );
        }
        await tester.drag(
          find.byKey(const ValueKey('dictionary-entry')),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
      }
      expect(tables, greaterThan(0));
    });
  }
}
