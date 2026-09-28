import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/flashcard.dart';
import 'package:czechify/domain/entities/srs_card.dart';
import 'package:czechify/domain/repositories/vocabulary_repository.dart';
import 'package:czechify/presentation/providers/review_providers.dart';
import 'package:czechify/presentation/screens/review/srs_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';
import 'support/course_units.dart';

/// Every review card of a unit on the no-scroll lessons fits a small phone
/// without scrolling, on each face a learner sees: the Czech front, the
/// English front (type the Czech), the listening front and the answer.
///
/// The review screen sits under the app's floating tab bar; the page keeps
/// room for it at the bottom, so the whole phone screen is the measure.
void main() {
  setUpAll(() async {
    for (final font in {
      'Bricolage Grotesque': 'BricolageGrotesque',
      'Schibsted Grotesk': 'SchibstedGrotesk',
    }.entries) {
      await (FontLoader(font.key)
        ..addFont(rootBundle.load('assets/fonts/${font.value}.ttf'))).load();
    }
  });

  testWidgets('every review card of a switched-on unit fits a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final cards = [
      for (final level in ['a1', 'a2'])
        for (final w in jsonDecode(
          File('assets/vocabulary/${level}_vocabulary.json').readAsStringSync(),
        ) as List<dynamic>)
          Flashcard.fromJson(w as Map<String, dynamic>),
    ].where((c) => courseUnits.contains(c.unitId)).toList();
    expect(cards, isNotEmpty);

    final problems = <String>[];
    final faces = [
      ('Czech front', CardDirection.czToEn, false),
      ('English front', CardDirection.enToCz, false),
      ('listening front', CardDirection.audio, false),
      ('answer', CardDirection.czToEn, true),
    ];
    for (final card in cards) {
      for (final (face, direction, flipped) in faces) {
        _card = card;
        _direction = direction;
        _flipped = flipped;
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('${card.id}$face'),
            overrides: [reviewSessionProvider.overrideWith(_Session.new)],
            child: MaterialApp(
              theme: lightTheme(),
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: child!,
                  ),
              home: const SrsReviewScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        var worst = 0.0;
        for (final s in tester.stateList<ScrollableState>(
          find.byType(Scrollable),
        )) {
          final p = s.position;
          if (p.axis == Axis.vertical && p.hasContentDimensions) {
            worst = math.max(worst, p.maxScrollExtent);
          }
        }
        if (worst > 1) {
          problems.add(
            '${card.id} "${card.wordCz}" $face: ${worst.round()} pt',
          );
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    expect(problems, isEmpty, reason: '${cards.length} cards measured');
  }, timeout: const Timeout(Duration(minutes: 20)));
}

Flashcard _card = const Flashcard(id: 0, wordCz: '', wordEn: '');
CardDirection _direction = CardDirection.czToEn;
bool _flipped = false;

class _Session extends ReviewSessionNotifier {
  @override
  ReviewSessionState build() => ReviewSessionState(
    isLoading: false,
    isFlipped: _flipped,
    dueCards: [
      SessionCard(
        ReviewCard(
          flashcard: _card,
          srs: SrsCard(
            id: '${_card.id}',
            cardType: CardType.vocabulary,
            due: DateTime.utc(2026, 9, 27),
            state: CardState.review,
            reps: 3,
            stability: 6,
            difficulty: 2.5,
          ),
        ),
        _direction,
      ),
    ],
  );

  @override
  Future<void> loadDueCards() async {}
}
