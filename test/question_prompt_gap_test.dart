import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// A question's Czech with a gap has nothing correct to play: the speaker
/// dropped the gap and read "Bydlím v ___." as "Bydlím v.", which sounds like
/// a whole sentence and is wrong Czech.
void main() {
  Future<void> pump(WidgetTester tester, String czech) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(
          body: QuestionPrompt(question: 'Choose the word', czech: czech),
        ),
      ),
    ),
  );

  testWidgets('a sentence with a gap has no speaker', (tester) async {
    await pump(tester, 'Bydlím v ___. (Praha)');

    expect(find.text('Bydlím v ___. (Praha)'), findsOneWidget);
    expect(find.byType(TtsButton), findsNothing);
  });

  testWidgets('a whole sentence keeps its speaker', (tester) async {
    await pump(tester, 'Bydlím v Praze.');

    expect(find.byType(TtsButton), findsOneWidget);
  });
}
