import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/presentation/widgets/common/motion_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The switch from a spinner to a whole screen of content used to happen in a
/// single frame. These tests pin the crossfade that replaced it — and, just as
/// importantly, that reduced motion puts the single frame back rather than
/// leaving a tween running invisibly.
void main() {
  Future<void> mount(
    WidgetTester tester,
    AsyncValue<String> value, {
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: MotionAsync<String>(
              value: value,
              loading: () => const Text('spinner'),
              error: (_, _) => const Text('failed'),
              data: (v) => Text(v),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('both states are on screen while the fade runs', (tester) async {
    await mount(tester, const AsyncValue<String>.loading());
    expect(find.text('spinner'), findsOneWidget);

    await mount(tester, const AsyncValue<String>.data('loaded'));
    await tester.pump(const Duration(milliseconds: 60));

    // Mid-transition the outgoing spinner is still mounted — that is what
    // makes it a crossfade rather than a cut.
    expect(find.text('spinner'), findsOneWidget);
    expect(find.text('loaded'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('spinner'), findsNothing);
    expect(find.text('loaded'), findsOneWidget);
  });

  testWidgets('reduce motion restores the single-frame swap', (tester) async {
    await mount(
      tester,
      const AsyncValue<String>.loading(),
      disableAnimations: true,
    );
    await mount(
      tester,
      const AsyncValue<String>.data('loaded'),
      disableAnimations: true,
    );
    await tester.pump();

    // The visible guarantee: one frame, fully swapped, no tween in between.
    expect(find.text('loaded'), findsOneWidget);
    expect(find.text('spinner'), findsNothing);

    // A single callback survives this frame — AnimatedSwitcher schedules the
    // removal of its outgoing entry rather than doing it inline, so the
    // teardown costs one more frame even at zero duration. That is inherited
    // from MotionSwap and predates this widget; what matters is that nothing
    // is still running once it settles.
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('an error crossfades in like any other state', (tester) async {
    await mount(tester, const AsyncValue<String>.loading());
    await mount(
      tester,
      AsyncValue<String>.error(Exception('nope'), StackTrace.empty),
    );
    await tester.pumpAndSettle();
    expect(find.text('failed'), findsOneWidget);
    expect(find.text('spinner'), findsNothing);
  });
}
