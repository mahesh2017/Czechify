import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/presentation/widgets/celebration/confetti_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Confetti is painted rather than imported, so the layer has to keep its own
/// pieces and playback in step when a celebration retunes it mid-flight.
void main() {
  Widget layer({
    int pieces = 20,
    Duration duration = const Duration(milliseconds: 800),
    Duration delay = Duration.zero,
    int seed = 7,
    bool reduceMotion = false,
  }) {
    return MaterialApp(
      theme: lightTheme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: ConfettiLayer(
            pieces: pieces,
            duration: duration,
            delay: delay,
            seed: seed,
          ),
        ),
      ),
    );
  }

  testWidgets('retuning the burst mid-flight keeps it running', (tester) async {
    await tester.pumpWidget(layer());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    // A celebration can change how long, how much, and how soon between
    // frames. Each has to be picked up without restarting or stalling.
    await tester.pumpWidget(layer(duration: const Duration(seconds: 2)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(
      layer(pieces: 40, duration: const Duration(seconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(
      layer(
        pieces: 40,
        duration: const Duration(seconds: 2),
        delay: const Duration(milliseconds: 50),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('a new seed restocks the burst without an exception', (
    tester,
  ) async {
    await tester.pumpWidget(layer());
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(layer(seed: 11));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('reduce motion schedules no confetti frames', (tester) async {
    await tester.pumpWidget(layer(reduceMotion: true));
    await tester.pumpAndSettle();

    expect(tester.binding.transientCallbackCount, 0);
  });
}
