import 'package:czechify/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's button themes use `Size.fromHeight(54)` to get the full-width
/// look the design calls for. That constant is `Size(double.infinity, 54)`,
/// which is only valid where the button receives a bounded width.
///
/// A Row hands its non-flex children unbounded width, so a themed button
/// dropped straight into a Row asks for an infinite minimum under an
/// unbounded constraint — layout throws and the entire surrounding subtree
/// renders blank. That is exactly what made the mock exam show an empty body
/// with an assertion on every timer tick, and it was latent in seven other
/// places whose state simply wasn't on screen at the time.
///
/// Note that `textButtonTheme` does *not* set a minimum size, so plain
/// TextButtons in a Row are unaffected — only filled, elevated, and outlined
/// buttons need [kRowButtonMinSize].
///
/// These tests pin both halves: the trap is real, and [kRowButtonMinSize] is
/// the way out of it.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: lightTheme(),
    home: Scaffold(body: Row(children: [child])),
  );

  // Guards the premise. If this ever stops holding — because the theme drops
  // Size.fromHeight, say — the workaround is obsolete and the
  // kRowButtonMinSize call sites can go back to plain themed buttons.
  test('button themes still ask for an unbounded minimum width', () {
    final theme = lightTheme();
    for (final entry
        in {
          'filled': theme.filledButtonTheme.style,
          'elevated': theme.elevatedButtonTheme.style,
          'outlined': theme.outlinedButtonTheme.style,
        }.entries) {
      final size = entry.value?.minimumSize?.resolve(<WidgetState>{});
      expect(
        size?.width,
        double.infinity,
        reason:
            '${entry.key} button theme is expected to use Size.fromHeight, '
            'which is what makes kRowButtonMinSize necessary in Rows',
      );
    }
  });

  testWidgets('kRowButtonMinSize makes the same button lay out', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(minimumSize: kRowButtonMinSize),
          child: const Text('Next'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.getSize(find.byType(FilledButton)).width.isFinite, isTrue);
  });

  test('kRowButtonMinSize is bounded on both axes', () {
    expect(kRowButtonMinSize.width.isFinite, isTrue);
    expect(kRowButtonMinSize.height.isFinite, isTrue);
  });
}
