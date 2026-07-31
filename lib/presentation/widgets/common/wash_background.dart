import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// The design's `--wash` canvas.
///
/// Every "surface" screen in the handoff — Home, the path, Review, Chat,
/// Stats, the copybook, the lesson-complete screen — sits on this rather than
/// on flat `--bg`: three very soft radial blobs (indigo top-left, amber
/// top-right, violet bottom-centre) over the page background. It is the thing
/// that stops a screenful of white cards reading as a spreadsheet, so it
/// belongs behind the content, not on it.
///
/// The blobs are anchored to the viewport, not the scroll extent — the paint
/// sits behind [child] and does not move when the child scrolls, matching a
/// CSS background on the phone frame.
class WashBackground extends StatelessWidget {
  const WashBackground({super.key, required this.child});

  final Widget child;

  /// `radial-gradient(115% 66% at 6% -8%, rgba(51,85,232,.11), transparent 58%)`
  /// and friends, in paint order.
  static const _light = <_Blob>[
    _Blob(Color(0x1C3355E8), 0.06, -0.08, 1.15, 0.66, 0.58),
    _Blob(Color(0x24E9992A), 1.08, 0.02, 0.92, 0.56, 0.55),
    _Blob(Color(0x147355DC), 0.46, 1.06, 1.20, 0.66, 0.62),
  ];

  static const _dark = <_Blob>[
    _Blob(Color(0x2B8098FF), 0.06, -0.08, 1.15, 0.66, 0.58),
    _Blob(Color(0x1CF3BE6B), 1.08, 0.02, 0.92, 0.56, 0.55),
    _Blob(Color(0x21A897F5), 0.46, 1.06, 1.20, 0.66, 0.62),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _WashPainter(base: t.bg, blobs: dark ? _dark : _light),
      // The painter fills whatever box the child takes, and the child is the
      // full screen body on every caller.
      child: child,
    );
  }
}

class _Blob {
  const _Blob(this.color, this.cx, this.cy, this.rx, this.ry, this.stop);

  final Color color;

  /// Centre, as a fraction of the painted box.
  final double cx;
  final double cy;

  /// Radii, as a fraction of the box width and height respectively — the
  /// blobs are ellipses, so they cannot be expressed as a plain
  /// [RadialGradient].
  final double rx;
  final double ry;

  /// Where the colour has faded out completely, as a fraction of the radius.
  final double stop;
}

class _WashPainter extends CustomPainter {
  const _WashPainter({required this.base, required this.blobs});

  final Color base;
  final List<_Blob> blobs;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);
    // CSS paints the first-listed background layer on top, so go backwards.
    for (final blob in blobs.reversed) {
      final rx = size.width * blob.rx;
      final ry = size.height * blob.ry;
      if (rx <= 0 || ry <= 0) continue;
      // Column-major: a unit circle at the origin, scaled to the ellipse and
      // moved to the blob's centre. Written out rather than built with
      // Matrix4's mutators so it does not depend on vector_math's API.
      final matrix = Float64List.fromList(<double>[
        rx, 0, 0, 0, //
        0, ry, 0, 0, //
        0, 0, 1, 0, //
        size.width * blob.cx, size.height * blob.cy, 0, 1,
      ]);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            1,
            <Color>[blob.color, blob.color.withValues(alpha: 0)],
            <double>[0, blob.stop],
            TileMode.clamp,
            matrix,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WashPainter oldDelegate) =>
      oldDelegate.base != base || oldDelegate.blobs != blobs;
}
