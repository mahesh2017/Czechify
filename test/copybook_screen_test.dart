import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ceskina_pro/presentation/screens/practice/copybook_screen.dart';
import 'package:ceskina_pro/presentation/providers/copybook_providers.dart';
import 'support/localized_app.dart';

void main() {
  testWidgets('persists a completed daily copybook item', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyCopybookProvider.overrideWith(
            (ref) async => const [
              CopybookItem(
                id: 42,
                czech: 'dobrý',
                english: 'good',
                example: 'Dobrý den.',
              ),
              CopybookItem(
                id: 43,
                czech: 'děkuji',
                english: 'thank you',
                example: 'Děkuji za pomoc.',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: CopybookScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Write Czech by hand'), findsOneWidget);
    expect(find.text('děkuji'), findsOneWidget);

    await tester.tap(find.text('dobrý'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final day = DateUtils.dateOnly(DateTime.now()).toIso8601String();
    expect(prefs.getStringList('copybook_done_$day'), contains('42'));
  });
}
