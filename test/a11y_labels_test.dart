import 'dart:io';

import 'package:ceskina_pro/l10n/app_localizations.dart';
import 'package:ceskina_pro/data/database/database.dart';
import 'package:ceskina_pro/presentation/providers/database_providers.dart';
import 'package:ceskina_pro/presentation/widgets/common/hearts_display.dart';
import 'package:ceskina_pro/presentation/widgets/common/streak_indicator.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hearts and the streak render as an icon plus a bare number. A screen
/// reader announcing "5" tells the learner nothing, so both carry a label
/// covering the pair.
void main() {
  Widget host(Widget child, AppDatabase database) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(database)],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('hearts announce what the number means', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const HeartsDisplay(), database));
    await tester.pump();

    expect(find.bySemanticsLabel(RegExp(r'heart')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('streak announces what the number means', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const StreakIndicator(), database));
    await tester.pump();

    expect(find.bySemanticsLabel(RegExp(r'day streak')), findsOneWidget);
    handle.dispose();
  });

  test('every IconButton in the presentation layer has a tooltip', () {
    // Tooltips are what a screen reader falls back to on an icon-only
    // control, so a missing one is a silent button.
    final constructor = RegExp(
      r'(?<![\w.])IconButton(\.filled|\.filledTonal|\.outlined)?\(',
    );
    final offenders = <String>[];

    for (final entity in Directory(
      'lib/presentation',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!constructor.hasMatch(lines[i])) continue;
        final window = lines
            .sublist(i, i + 20 > lines.length ? lines.length : i + 20)
            .join('\n');
        if (!window.contains('tooltip:')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(offenders, isEmpty, reason: 'Icon-only buttons with no tooltip');
  });
}
