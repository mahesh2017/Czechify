import 'package:ceskina_pro/core/theme/app_theme.dart';
import 'package:ceskina_pro/domain/entities/flashcard.dart';
import 'package:ceskina_pro/domain/entities/srs_card.dart';
import 'package:ceskina_pro/domain/repositories/vocabulary_repository.dart';
import 'package:ceskina_pro/presentation/providers/review_providers.dart';
import 'package:ceskina_pro/presentation/screens/review/srs_review_screen.dart';
import 'package:ceskina_pro/presentation/widgets/common/lesson_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

void main() {
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

    expect(find.text('kočka'), findsOneWidget);
    expect(find.text('HOW WELL DID YOU REMEMBER IT?'), findsNothing);
    expect(tester.takeException(), isNull);
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
