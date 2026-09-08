import 'package:czechify/presentation/screens/review/srs_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// A failed load used to leave the review screen on its spinner: `isLoading`
/// stayed true, `_loaded` was never set, and there was no retry and no way
/// back. This is what the learner gets instead.
void main() {
  testWidgets('says what happened and offers a way out', (tester) async {
    var retries = 0;
    var exits = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: ReviewLoadErrorScreen(
          onRetry: () => retries++,
          onExit: () => exits++,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Couldn’t load your review'), findsOneWidget);
    // Reassurance matters here: a failed load says nothing about their work.
    expect(find.textContaining('progress is safe'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retries, 1);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(exits, 1, reason: 'the learner must be able to leave');
  });
}
