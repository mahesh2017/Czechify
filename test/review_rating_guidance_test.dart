import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/flashcard.dart';
import 'package:czechify/domain/entities/srs_card.dart';
import 'package:czechify/domain/repositories/vocabulary_repository.dart';
import 'package:czechify/presentation/providers/review_providers.dart';
import 'package:czechify/presentation/screens/review/srs_review_screen.dart';
import 'package:czechify/presentation/widgets/common/lesson_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/localized_app.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'forgotten recall can retry saving and resets for repeated card at ${scale}x',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final container = ProviderContainer(
            overrides: [
              reviewSessionProvider.overrideWith(_ForgottenReviewNotifier.new),
            ],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: lightTheme(),
                localizationsDelegates: testLocalizationsDelegates,
                supportedLocales: testSupportedLocales,
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                home: const SrsReviewScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.enterText(find.byType(TextField), 'p');
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('I don’t remember'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('I don’t remember'));
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          expect(find.text('pes'), findsOneWidget);
          expect(find.bySemanticsLabel(RegExp('pes')), findsWidgets);
          expect(find.text('Good'), findsNothing);
          expect(container.read(reviewSessionProvider).currentIndex, 0);
          await tester.ensureVisible(find.text('Practise again'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Practise again'));
          await tester.pumpAndSettle();
          expect(find.text('Could not save'), findsOneWidget);
          expect(container.read(reviewSessionProvider).currentIndex, 0);
          await tester.tap(find.text('Practise again'));
          await tester.pumpAndSettle();
          expect(container.read(reviewSessionProvider).currentIndex, 1);
          expect(find.text('I don’t remember'), findsOneWidget);
          expect(tester.widget<KeyCta>(find.byType(KeyCta)).onPressed, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('system Back keeps a review draft on Stay and exits on End', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/review',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(path: '/review', builder: (_, _) => const SrsReviewScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewSessionProvider.overrideWith(_ProductionReviewNotifier.new),
        ],
        child: MaterialApp.router(
          theme: lightTheme(),
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pe');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('End review?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('pe'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('review explains that a rating schedules and advances', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewSessionProvider.overrideWith(_GuidedReviewNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          theme: lightTheme(),
          home: const SrsReviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HOW WELL DID YOU REMEMBER IT?'), findsOneWidget);
    expect(
      find.text('Choose one to schedule this card and continue to the next.'),
      findsOneWidget,
    );
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Good'));
    await tester.pump();
    await tester.pump();

    expect(find.text('kočka'), findsOneWidget);
    expect(find.text('HOW WELL DID YOU REMEMBER IT?'), findsNothing);
    final incomingCard = find.byKey(const ValueKey('1:2'));
    final translation = tester.widget<FractionalTranslation>(
      find
          .descendant(
            of: incomingCard,
            matching: find.byType(FractionalTranslation),
          )
          .first,
    );
    expect(translation.translation.dx, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('review card advancement snaps with reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewSessionProvider.overrideWith(_GuidedReviewNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          theme: lightTheme(),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
          home: const SrsReviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Good'));
    await tester.pump();
    await tester.pump();

    final incomingCard = find.byKey(const ValueKey('1:2'));
    final translations = find.descendant(
      of: incomingCard,
      matching: find.byType(FractionalTranslation),
    );
    expect(
      tester.widgetList<FractionalTranslation>(translations),
      everyElement(
        isA<FractionalTranslation>().having(
          (widget) => widget.translation,
          'translation',
          Offset.zero,
        ),
      ),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('production review explains why reveal is unavailable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewSessionProvider.overrideWith(_ProductionReviewNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          theme: lightTheme(),
          home: const SrsReviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Type your answer first'), findsWidgets);
    expect(tester.widget<KeyCta>(find.byType(KeyCta)).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'pes');
    await tester.pump();

    expect(find.text('Tap to reveal'), findsOneWidget);
    expect(find.text('Show Answer'), findsOneWidget);
    expect(tester.widget<KeyCta>(find.byType(KeyCta)).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

class _GuidedReviewNotifier extends ReviewSessionNotifier {
  @override
  ReviewSessionState build() => ReviewSessionState(
    isLoading: false,
    isFlipped: true,
    dueCards: [_card(1, 'pes', 'dog'), _card(2, 'kočka', 'cat')],
  );

  @override
  Future<void> loadDueCards() async {}

  @override
  Future<void> rateCard(Rating rating) async {
    state = state.copyWith(currentIndex: 1, isFlipped: false);
  }

  static SessionCard _card(int id, String wordCz, String wordEn) {
    return SessionCard(
      ReviewCard(
        flashcard: Flashcard(id: id, wordCz: wordCz, wordEn: wordEn),
        srs: SrsCard(
          id: '$id',
          cardType: CardType.vocabulary,
          due: DateTime.utc(2026, 8, 25),
          state: CardState.review,
          reps: 3,
          stability: 6,
          difficulty: 2.5,
        ),
      ),
      CardDirection.czToEn,
    );
  }
}

class _ProductionReviewNotifier extends ReviewSessionNotifier {
  @override
  ReviewSessionState build() {
    final base = _GuidedReviewNotifier._card(1, 'pes', 'dog');
    return ReviewSessionState(
      isLoading: false,
      dueCards: [SessionCard(base.review, CardDirection.enToCz)],
    );
  }

  @override
  Future<void> loadDueCards() async {}
}

class _ForgottenReviewNotifier extends _ProductionReviewNotifier {
  bool failNext = true;
  @override
  Future<void> rateCard(Rating rating) async {
    expect(rating, Rating.again);
    if (failNext) {
      failNext = false;
      state = state.copyWith(commitError: 'Could not save');
      return;
    }
    state = state.copyWith(
      dueCards: [...state.dueCards, state.currentCard!],
      currentIndex: state.currentIndex + 1,
      isFlipped: false,
      clearCommitError: true,
    );
  }
}
