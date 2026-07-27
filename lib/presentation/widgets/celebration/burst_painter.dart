import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Particles thrown outward from a point, plus the ring of the impact.
///
/// This is the "loud" part of a correct answer. The earlier version tinted the
/// screen at 15% and faded a translucent tick, which was so restrained that
/// the reward barely registered — and a reward nobody notices is not doing
/// any work at all.
class RadialBurstPainter extends CustomPainter {
  RadialBurstPainter({
    required this.progress,
    required this.colors,
    this.count = 16,
    this.maxRadius = 190,
    this.seed = 3,
  });

  /// 0 to 1 across the life of the burst.
  final double progress;
  final List<Color> colors;
  final int count;
  final double maxRadius;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final random = math.Random(seed);
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress * progress).clamp(0.0, 1.0);
    final paint = Paint();

    // The shockwave ring: fast, thinning, gone before the particles are.
    final ringT = (progress / 0.55).clamp(0.0, 1.0);
    if (ringT < 1) {
      canvas.drawCircle(
        center,
        20 + (maxRadius * 0.75) * Curves.easeOutCubic.transform(ringT),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * (1 - ringT)
          ..color = colors.first.withValues(alpha: (1 - ringT) * 0.55),
      );
    }

    for (var i = 0; i < count; i++) {
      // Evenly spread, then jittered — a perfect ring reads as a loading
      // spinner rather than as something bursting.
      final angle =
          (i / count) * math.pi * 2 + (random.nextDouble() - 0.5) * 0.5;
      final reach = maxRadius * (0.55 + random.nextDouble() * 0.45);
      final distance = reach * eased;
      final offset = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      final radius = (4 + random.nextDouble() * 5) * (1 - eased * 0.55);
      paint.color = colors[i % colors.length].withValues(alpha: fade);
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RadialBurstPainter old) => old.progress != progress;
}

/// Light rays fanning out from behind a trophy, turning slowly.
///
/// The single cheapest way to make a completion screen feel like an occasion
/// rather than a receipt.
class RaysPainter extends CustomPainter {
  RaysPainter({
    required this.rotation,
    required this.color,
    required this.scale,
    this.rays = 12,
  });

  /// Radians. Slow and constant — fast rotation reads as loading.
  final double rotation;
  final Color color;

  /// 0 to 1, so the fan can grow into place with the trophy.
  final double scale;

  final int rays;

  @override
  void paint(Canvas canvas, Size size) {
    if (scale <= 0) return;
    final center = size.center(Offset.zero);
    final length = size.longestSide * 0.85 * scale;
    final paint = Paint()..color = color.withValues(alpha: 0.16 * scale);
    const spread = math.pi / 26;

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rotation);
    for (var i = 0; i < rays; i++) {
      final angle = (i / rays) * math.pi * 2;
      final path =
          Path()
            ..moveTo(0, 0)
            ..lineTo(
              math.cos(angle - spread) * length,
              math.sin(angle - spread) * length,
            )
            ..lineTo(
              math.cos(angle + spread) * length,
              math.sin(angle + spread) * length,
            )
            ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RaysPainter old) =>
      old.rotation != rotation || old.scale != scale;
}
