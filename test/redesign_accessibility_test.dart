import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:czechify/presentation/widgets/home/streak_state_sheet.dart';
import 'support/localized_app.dart';

void main() {
  testWidgets('protected streak remains readable at 200 percent text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed:
                          () => showStreakStateSheet(
                            context,
                            streak: 8,
                            freezeAvailable: false,
                          ),
                      child: const Text('Open streak'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open streak'));
    await tester.pumpAndSettle();

    expect(find.text('Streak protected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('streak action meets the 44 point target minimum', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Builder(
          builder:
              (context) => Scaffold(
                body: FilledButton(
                  onPressed:
                      () => showStreakStateSheet(
                        context,
                        streak: 0,
                        freezeAvailable: true,
                      ),
                  child: const Text('Open streak'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Open streak'));
    await tester.pumpAndSettle();

    final size = tester.getSize(
      find.widgetWithText(FilledButton, 'Begin again'),
    );
    expect(size.height, greaterThanOrEqualTo(44));
  });

  test('nothing fills a surface with an accent token under onFill text', () {
    // The accents (`pri`, `violet`, `red`, `green`, `amber`) go lighter in
    // dark mode because they are meant for text and icons *on* the page. Used
    // as a fill under white they drop to about 2.5:1, and ten badges, buttons
    // and play controls had done exactly that — readable in light mode, washed
    // out in dark. `app_tokens_test` proves the `*Fill` tokens are safe; this
    // proves they are the ones actually being used.
    const accents = ['pri', 'violet', 'red', 'green', 'amber'];
    // Trailing comma required: `t.pri.withValues(alpha: .35)` on a BoxShadow
    // is a glow behind the surface, not the surface any text sits on.
    final fill = RegExp('color:\\s*t\\.(${accents.join('|')})\\s*,');
    final offenders = <String>[];

    for (final file in Directory('lib/presentation')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        final match = fill.firstMatch(code);
        if (match == null) continue;
        // The foreground follows the decoration closely; stop at the next
        // fill so a neighbouring widget's white cannot be blamed on this one.
        final window = <String>[];
        for (var j = i + 1; j < lines.length && j < i + 14; j++) {
          if (fill.hasMatch(lines[j].split('//').first)) break;
          window.add(lines[j]);
        }
        final text = window.join('\n');
        if (text.contains('t.onFill') || text.contains('Colors.white')) {
          offenders.add('${file.path}:${i + 1} (t.${match.group(1)})');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These fill a surface with an accent token and put onFill on it, '
          'which is unreadable in dark mode: ${offenders.join(', ')}. Use the '
          'matching priFill / violetFill / redFill, or add one to AppTokens.',
    );
  });
}
