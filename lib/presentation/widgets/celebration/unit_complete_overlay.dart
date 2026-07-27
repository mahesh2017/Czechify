import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/feedback/celebration.dart';
import '../../../core/theme/app_tokens.dart';
import 'confetti_layer.dart';

/// The ceremony for finishing a unit.
///
/// Most units are two lessons, so this lands roughly every other lesson and
/// cannot afford to be long. It differs from a lesson completion by
/// *character*: a lesson sprinkles, a unit lands — a seal stamps down with a
/// shockwave, and the screen stops to say what that just opened up.
class UnitCompleteOverlay extends StatefulWidget {
  const UnitCompleteOverlay({
    super.key,
    required this.celebration,
    required this.onDismiss,
  });

  final UnitCompleted celebration;
  final VoidCallback onDismiss;

  @override
  State<UnitCompleteOverlay> createState() => _UnitCompleteOverlayState();
}

class _UnitCompleteOverlayState extends State<UnitCompleteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// The frame the seal lands on. Everything else is timed off this, so the
  /// shockwave and the confetti read as caused by the impact.
  static const _impact = 0.32;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _slice(double start, double end, [Curve curve = Curves.easeOut]) {
    final t = ((_controller.value - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  void _share() {
    final unit = widget.celebration;
    SharePlus.instance.share(
      ShareParams(
        text:
            'I just finished Unit ${unit.unitNumber} — ${unit.unitTitle} — '
            'learning Czech! 🇨🇿',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final unit = widget.celebration;
    final instant = MediaQuery.disableAnimationsOf(context);
    final accent = unit.isMilestone ? tokens.amber : tokens.pri;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final entered = instant ? 1.0 : _slice(0, 0.12);
        return ColoredBox(
          color: Colors.black.withValues(alpha: 0.78 * entered),
          child: Stack(
            children: [
              if (!instant && _controller.value >= _impact)
                const Positioned.fill(child: ConfettiLayer(pieces: 120)),
              Positioned.fill(
                child: SafeArea(
                  // Centred when it fits, scrollable when it does not: a
                  // short screen or a large text-size setting must not clip
                  // the button that leads onward.
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _seal(accent, instant),
                          const SizedBox(height: 30),
                          Opacity(
                            opacity: instant ? 1 : _slice(_impact, 0.55),
                            child: Column(
                              children: [
                                if (unit.isMilestone) ...[
                                  Text(
                                    'MILNÍK · MILESTONE',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                const Text(
                                  'Hotovo! Unit complete',
                                  style: TextStyle(
                                    fontFamily: AppFonts.display,
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  unit.unitTitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          // The one moment the app has to say what comes next,
                          // which is why this ceremony has no dismiss timer.
                          if (unit.nextUnitTitle case final next?)
                            Opacity(
                              opacity: instant ? 1 : _slice(0.5, 0.75),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_open_rounded,
                                      size: 18,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        'Unit ${unit.unitNumber + 1} · $next '
                                        'is now open',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 34),
                          Opacity(
                            opacity: instant ? 1 : _slice(0.62, 0.88),
                            child: Column(
                              children: [
                                FilledButton(
                                  onPressed: widget.onDismiss,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(220, 48),
                                  ),
                                  child: const Text('Continue'),
                                ),
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  onPressed: _share,
                                  icon: const Icon(Icons.ios_share, size: 18),
                                  label: const Text('Share'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Falls from above and lands hard, with a ring thrown off the impact.
  Widget _seal(Color accent, bool instant) {
    final approach = instant ? 1.0 : _slice(0, _impact, Curves.easeInCubic);
    // A little past the landing the seal settles back — the overshoot is what
    // sells it as weight rather than as a fade-in.
    final settle = instant ? 0.0 : 1 - _slice(_impact, 0.46, Curves.easeOut);
    final scale = instant ? 1.0 : (2.6 - 1.6 * approach) + 0.12 * settle;
    final shock = instant ? 1.0 : _slice(_impact, 0.72);

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!instant && shock > 0 && shock < 1)
            CustomPaint(
              size: const Size(200, 200),
              painter: _ShockwavePainter(progress: shock, color: accent),
            ),
          Opacity(
            opacity: instant ? 1 : math.min(1, approach * 1.6),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.18),
                  border: Border.all(color: accent, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'UNIT',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                    Text(
                      '${widget.celebration.unitNumber}',
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShockwavePainter extends CustomPainter {
  const _ShockwavePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = 66 + 34 * progress;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - progress)
        ..color = color.withValues(alpha: (1 - progress) * 0.8),
    );
  }

  @override
  bool shouldRepaint(_ShockwavePainter old) => old.progress != progress;
}
