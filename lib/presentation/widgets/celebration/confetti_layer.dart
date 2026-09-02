import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Falling confetti, painted rather than imported.
///
/// A package would pull in a dependency for ~120 lines of physics, and would
/// not know the app's palette. Painting it means the colours come from the
/// theme tokens, so a celebration in dark mode is not a fistful of bright
/// primaries thrown at a dark screen.
class ConfettiLayer extends StatefulWidget {
  const ConfettiLayer({
    super.key,
    this.pieces = 70,
    this.duration = const Duration(milliseconds: 2600),
    this.seed = 7,
  });

  final int pieces;
  final Duration duration;

  /// Fixed by default so a celebration looks the same each time it is shown —
  /// worth more for a screenshot test than randomness is worth for delight.
  final int seed;

  @override
  State<ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<_Piece> _pieces = const [];
  List<Color>? _palette;
  bool? _motionDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tokens = context.tokens;
    final palette = [tokens.pri, tokens.amber, tokens.violet, tokens.green];
    if (_palette == null || !_samePalette(_palette!, palette)) {
      _palette = palette;
      _pieces = _build(widget.pieces, widget.seed, palette);
    }

    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_motionDisabled == disabled) return;
    _motionDisabled = disabled;
    if (disabled || widget.pieces <= 0) {
      _controller
        ..stop()
        ..value = 0;
    } else if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ConfettiLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.pieces != widget.pieces || oldWidget.seed != widget.seed) {
      _pieces = _build(widget.pieces, widget.seed, _palette ?? const []);
    }
    if (widget.pieces <= 0) {
      _controller
        ..stop()
        ..value = 0;
    } else if (_motionDisabled == false &&
        _controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_motionDisabled != false || widget.pieces <= 0) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder:
              (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(
                  progress: _controller.value,
                  pieces: _pieces,
                  seconds: widget.duration.inMilliseconds / 1000,
                ),
              ),
        ),
      ),
    );
  }
}

bool _samePalette(List<Color> a, List<Color> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _Piece {
  const _Piece({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.swayAmplitude,
    required this.swayRate,
    required this.phase,
    required this.size,
    required this.spin,
    required this.color,
    required this.round,
  });

  /// Start position, as a fraction of the layer.
  final double x;
  final double y;

  /// Velocity, in fractions of the layer per second.
  final double vx;
  final double vy;

  final double swayAmplitude;
  final double swayRate;
  final double phase;
  final double size;
  final double spin;
  final Color color;
  final bool round;
}

List<_Piece> _build(int count, int seed, List<Color> palette) {
  if (count <= 0 || palette.isEmpty) return const [];
  final random = math.Random(seed);
  double between(double a, double b) => a + random.nextDouble() * (b - a);
  return [
    for (var i = 0; i < count; i++)
      _Piece(
        x: random.nextDouble(),
        // Above the top edge, so pieces fall into frame instead of appearing.
        y: between(-0.35, -0.02),
        vx: between(-0.08, 0.08),
        vy: between(0.10, 0.36),
        swayAmplitude: between(0.006, 0.035),
        swayRate: between(2.0, 5.5),
        phase: between(0, math.pi * 2),
        size: between(5, 11),
        spin: between(-7, 7),
        color: palette[random.nextInt(palette.length)],
        round: random.nextDouble() < 0.3,
      ),
  ];
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.progress,
    required this.pieces,
    required this.seconds,
  });

  final double progress;
  final List<_Piece> pieces;
  final double seconds;

  static const _gravity = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * seconds;
    // Fade the last stretch so pieces still on screen at the end dissolve
    // rather than vanishing between one frame and the next.
    final fade = progress < 0.78 ? 1.0 : 1 - (progress - 0.78) / 0.22;
    final paint = Paint();

    for (final piece in pieces) {
      final dx =
          piece.x +
          piece.vx * t +
          piece.swayAmplitude * math.sin(t * piece.swayRate + piece.phase);
      final dy = piece.y + piece.vy * t + 0.5 * _gravity * t * t;
      final py = dy * size.height;
      if (py < -40 || py > size.height + 40) continue;

      paint.color = piece.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas
        ..save()
        ..translate(dx * size.width, py)
        ..rotate(piece.spin * t + piece.phase);
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 0.55,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
