import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/core/updates/app_update_service.dart';
import 'package:czechify/data/database/database.dart';
import 'package:czechify/presentation/providers/app_update_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/routes/app_shell_keys.dart';
import 'package:czechify/presentation/screens/settings/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

/// Settings reads as a list of short labels (Mahesh, 28 Sep 2026: "short and
/// concise text first … longer explanatory text when they want to"). Rows
/// carried whole sentences under every title — up to 97 characters under a
/// switch — and several only repeated their title. Explanations now sit
/// behind an ⓘ; this keeps them there.
void main() {
  late AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() async => database.close());

  Future<void> open(
    WidgetTester tester, {
    String locale = 'en',
    double width = 420,
    double textScale = 1,
    bool dark = false,
  }) async {
    // Tall: Settings is a lazy list, and the rows at the bottom must build.
    tester.view.physicalSize = Size(width, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          appUpdateServiceProvider.overrideWithValue(_NoUpdates()),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          theme: dark ? darkTheme() : lightTheme(),
          locale: Locale(locale),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
          home: const SettingsScreen(),
        ),
      ),
    );
    // Fixed frames: a status row animates, so settling never completes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final (locale, limit) in [('en', 50), ('cs', 60)]) {
    testWidgets('no line on Settings runs past $limit characters ($locale)', (
      tester,
    ) async {
      await open(tester, locale: locale);
      final long = [
        for (final e in find.byType(Text).evaluate())
          if (((e.widget as Text).data ?? '').length > limit)
            (e.widget as Text).data!,
      ];
      expect(
        long,
        isEmpty,
        reason: 'Put the explanation behind the row\'s ⓘ (info:) instead',
      );
    });
  }

  testWidgets('rows that only repeated their title have no second line', (
    tester,
  ) async {
    await open(tester);
    for (final gone in [
      'Answers and celebrations',
      'A tap you can feel',
      'Remove cached audio files',
      'Play a sample Czech phrase',
      'Read in full, in the app',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
  });

  testWidgets('the ⓘ opens the longer explanation', (tester) async {
    await open(tester);
    expect(find.textContaining('costs a heart'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-info-Hearts in lessons')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('costs a heart'), findsOneWidget);
  });

  testWidgets('what cloud pronunciation does stays in view', (tester) async {
    // It sends a recording off the phone: that is not an ⓘ-only fact.
    await open(tester);
    expect(
      find.text('On: your recording is sent to be transcribed'),
      findsOneWidget,
    );
  });

  testWidgets('the ⓘ buttons are full-size tap targets', (tester) async {
    await open(tester, width: 360);
    final semantics = tester.ensureSemantics();
    await tester.pump();
    for (final info in find
        .byWidgetPredicate(
          (w) => w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('settings-info-'),
        )
        .evaluate()) {
      final size = tester.getSize(find.byWidget(info.widget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    semantics.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets(
      'fits a small phone at 200% text (${dark ? 'dark' : 'light'})',
      (tester) async {
        await open(tester, width: 360, textScale: 2, dark: dark);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('fits a small phone at 200% text in Czech', (tester) async {
    await open(tester, width: 360, textScale: 2, locale: 'cs');
    expect(tester.takeException(), isNull);
  });
}

class _NoUpdates implements AppUpdateService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
