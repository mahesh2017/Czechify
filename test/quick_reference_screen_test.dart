import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ceskina_pro/core/theme/app_theme.dart';
import 'package:ceskina_pro/presentation/providers/curriculum_providers.dart';
import 'package:ceskina_pro/presentation/screens/grammar/quick_reference_screen.dart';

/// Renders the reference screens against the real bundled assets so schema
/// drift between the JSON files and the renderer fails loudly (previously the
/// renderer expected a `rows` key that no asset had, producing headings with
/// empty bodies).
void main() {
  Future<void> pumpReference(
    WidgetTester tester,
    String type, {
    Set<int>? unlocked,
  }) async {
    // Cheat sheets are gated on reached units, so the screen needs a scope.
    // Default: everything unlocked, keeping these tests about schema drift —
    // gating is asserted separately below.
    final reached = unlocked ?? {for (var id = 1; id <= 31; id++) id};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unlockedUnitIdsProvider.overrideWith((ref) async => reached),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          home: QuickReferenceScreen(type: type),
        ),
      ),
    );
    // Assets >50KB are utf8-decoded off the main isolate, which never
    // completes under fake async — give the load real wall-clock time. The
    // unlock future resolves on its own schedule, so waiting only on the
    // asset spinner left the screen in its show-everything fallback.
    final highest = reached.reduce((a, b) => a > b ? a : b);
    for (var i = 0; i < 25; i++) {
      final loading = tester.any(find.byType(CircularProgressIndicator));
      // Newest first, so the highest reached unit heads the list once the
      // unlock future has resolved.
      final gateReady =
          type != 'cheat_sheets' ||
          tester.any(find.textContaining('Unit $highest:'));
      if (!loading && gateReady) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
  }

  testWidgets('declension tables expand to real case forms', (tester) async {
    await pumpReference(tester, 'declension_tables');

    expect(find.text('Masculine Animate — Hard Stem'), findsOneWidget);

    await tester.tap(find.text('Masculine Animate — Hard Stem'));
    await tester.pumpAndSettle();

    // Case rows and declined forms from the asset (pattern word "pan").
    expect(find.text('Singular'), findsOneWidget);
    expect(find.text('Plural'), findsOneWidget);
    expect(find.text('pana (-a)'), findsWidgets);
  });

  testWidgets('conjugation tables expand to real verb forms', (tester) async {
    await pumpReference(tester, 'conjugation_tables');

    expect(find.text('být — present'), findsOneWidget);

    await tester.tap(find.text('být — present'));
    await tester.pumpAndSettle();

    expect(find.text('jsem'), findsOneWidget);
    expect(find.text('jsou'), findsOneWidget);
  });

  testWidgets('cheat sheets render unit entries, newest first', (tester) async {
    await pumpReference(tester, 'cheat_sheets');
    // Sorted by unit descending so the sheet for the unit being studied needs
    // no scrolling. Unit 1 is now last and is not built by the lazy list, so
    // asserting on it would pass only by accident of ordering.
    expect(find.textContaining('Unit 31'), findsWidgets);
    expect(find.textContaining('A2 Review & Consolidation'), findsWidgets);
  });

  // Gating itself (which sheets are shown, and in what order) is asserted as
  // pure logic in cheat_sheet_visibility_test.dart — driving it through the
  // widget meant racing an unresolved provider future against a lazily built
  // list, which is a flaky test rather than a meaningful one.
}
