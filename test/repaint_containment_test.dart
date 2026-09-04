import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/presentation/widgets/common/lesson_ui.dart';
import 'package:czechify/presentation/widgets/common/record_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// Endlessly-repeating animations must not drag the rest of the screen onto
/// the per-frame repaint path.
///
/// Flutter propagates a repaint up to the nearest enclosing [RepaintBoundary].
/// A route supplies one, so without a closer boundary a looping animation
/// re-records everything on the screen — on these screens that includes
/// `WashBackground`'s three full-screen radial gradients — sixty times a
/// second, for as long as the loop runs. Nothing about that is visible: the
/// pixels are identical, only the cost differs, so no ordinary widget test
/// catches it.
///
/// These tests count paints of a *neighbour* of the animating widget. The
/// negative control at the end is not optional — it proves the counter can
/// still observe a repaint, so a passing assertion means containment rather
/// than a probe that stopped working.
void main() {
  testWidgets('a listening panel keeps its pulse off the screen behind it', (
    tester,
  ) async {
    expect(
      await _neighbourPaints(tester, ListenPanel(onPlay: () {}, onSlow: () {})),
      0,
    );
  });

  testWidgets('a recording button keeps its ring off the screen behind it', (
    tester,
  ) async {
    expect(
      await _neighbourPaints(
        tester,
        const RecordButton(onPressed: null, isRecording: true),
      ),
      0,
    );
  });

  testWidgets('an idle recording button runs no animation at all', (
    tester,
  ) async {
    expect(
      await _neighbourPaints(tester, const RecordButton(onPressed: null)),
      0,
    );
  });

  testWidgets('control: the probe still detects an uncontained repaint', (
    tester,
  ) async {
    // Deliberately unboundaried. If this ever reports 0 the probe has gone
    // blind and the assertions above are worthless.
    expect(await _neighbourPaints(tester, const _UncontainedPulse()), 20);
  });
}

/// Mounts [subject] beside a paint-counting neighbour and returns how many
/// times that neighbour repainted over twenty frames.
Future<int> _neighbourPaints(WidgetTester tester, Widget subject) async {
  var paints = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme(),
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            _PaintCounter(
              onPaint: () => paints++,
              child: const SizedBox(width: 200, height: 200),
            ),
            subject,
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  paints = 0;
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return paints;
}

class _PaintCounter extends SingleChildRenderObjectWidget {
  const _PaintCounter({required this.onPaint, super.child});

  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaintCounter(onPaint);

  @override
  void updateRenderObject(BuildContext context, _RenderPaintCounter renderer) =>
      renderer.onPaint = onPaint;
}

class _RenderPaintCounter extends RenderProxyBox {
  _RenderPaintCounter(this.onPaint);

  VoidCallback onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint();
    super.paint(context, offset);
  }
}

class _UncontainedPulse extends StatefulWidget {
  const _UncontainedPulse();

  @override
  State<_UncontainedPulse> createState() => _UncontainedPulseState();
}

class _UncontainedPulseState extends State<_UncontainedPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder:
        (context, _) => Transform.scale(
          scale: 1 + 0.1 * _controller.value,
          child: const SizedBox(width: 20, height: 20),
        ),
  );
}
