import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../domain/engines/daily_arrival_engine.dart';
import '../../providers/daily_arrival_providers.dart';

/// A focused, once-daily hand-off from opening Czechify to useful practice.
class DailyArrivalScreen extends ConsumerStatefulWidget {
  const DailyArrivalScreen({super.key});

  @override
  ConsumerState<DailyArrivalScreen> createState() => _DailyArrivalScreenState();
}

class _DailyArrivalScreenState extends ConsumerState<DailyArrivalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _motionConfigured = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );
    // Count an impression when the route is actually mounted, not merely when
    // startup checks it. Failure is harmless: the welcome may appear again.
    unawaited(markDailyArrivalShown(ref));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionConfigured) return;
    _motionConfigured = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(dailyArrivalStateProvider);
    return Scaffold(
      body: SafeArea(
        child: asyncState.when(
          loading: () => _ArrivalLoading(animation: _entrance),
          error: (_, __) => _ArrivalFallback(onContinue: () => context.go('/')),
          data:
              (state) => _ArrivalContent(
                state: state,
                animation: _entrance,
                onPrimary: () => _openPrimary(context, state),
                onHome: () => context.go('/'),
              ),
        ),
      ),
    );
  }

  void _openPrimary(BuildContext context, DailyArrivalState state) {
    if (state.kind == DailyArrivalKind.reviewsReady) {
      context.go('/review');
    } else if (state.lessonId case final lessonId?) {
      context.go('/lesson/$lessonId');
    } else if (state.kind == DailyArrivalKind.courseComplete) {
      context.go('/curriculum');
    } else {
      context.go('/');
    }
  }
}

class _ArrivalContent extends StatelessWidget {
  const _ArrivalContent({
    required this.state,
    required this.animation,
    required this.onPrimary,
    required this.onHome,
  });

  final DailyArrivalState state;
  final Animation<double> animation;
  final VoidCallback onPrimary;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final copy = _ArrivalCopy.forState(state);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final mascotT = Curves.elasticOut.transform(
          (animation.value / .72).clamp(0, 1),
        );
        final contentT = Curves.easeOutCubic.transform(
          ((animation.value - .18) / .82).clamp(0, 1),
        );
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ArrivalBackdropPainter(
                  progress: animation.value,
                  color: copy.accent(t),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: Offset(0, 18 * (1 - mascotT)),
                        child: Transform.scale(
                          scale: .62 + (.38 * mascotT),
                          child: Opacity(
                            opacity: animation.value.clamp(0, 1),
                            child: _HacekGuide(color: copy.accent(t)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: contentT,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - contentT)),
                          child: Column(
                            children: [
                              Text(
                                copy.eyebrow,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: copy.accent(t),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                copy.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: t.ink,
                                  fontFamily: AppFonts.display,
                                  fontSize: 32,
                                  height: 1.08,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                copy.body,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: t.muted,
                                  fontSize: 16,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _ProgressCard(
                                state: state,
                                accent: copy.accent(t),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: onPrimary,
                                  icon: Icon(copy.primaryIcon),
                                  label: Text(copy.primaryLabel),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: onHome,
                                child: const Text('Go to Home'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state, required this.accent});

  final DailyArrivalState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: .18)),
        boxShadow: t.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Metric(
                icon: Icons.local_fire_department_rounded,
                color: t.amber,
                value: '${state.streak}',
                label: 'day streak',
              ),
              Container(width: 1, height: 38, color: t.line),
              _Metric(
                icon: Icons.bolt_rounded,
                color: accent,
                value: '${state.dailyXp}/${state.dailyGoalXp}',
                label: 'today’s XP',
              ),
              if (state.dueReviews > 0) ...[
                Container(width: 1, height: 38, color: t.line),
                _Metric(
                  icon: Icons.style_rounded,
                  color: t.violet,
                  value: '${state.dueReviews}',
                  label: 'to review',
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: state.goalProgress,
              backgroundColor: t.elev,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          if (state.lessonTitle case final lessonTitle?) ...[
            const SizedBox(height: 14),
            Text(
              state.unitTitle ?? 'Up next',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.faint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              lessonTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(color: context.tokens.faint, fontSize: 11),
        ),
      ],
    ),
  );
}

class _HacekGuide extends StatelessWidget {
  const _HacekGuide({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Czechify language guide',
    child: SizedBox(
      width: 148,
      height: 148,
      child: CustomPaint(
        painter: _HacekGuidePainter(color, context.tokens.card),
      ),
    ),
  );
}

class _HacekGuidePainter extends CustomPainter {
  const _HacekGuidePainter(this.color, this.faceColor);

  final Color color;
  final Color faceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shadow =
        Paint()
          ..color = Colors.black.withValues(alpha: .13)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center + const Offset(0, 8), 54, shadow);

    final body = Paint()..color = color;
    canvas.drawCircle(center, 54, body);
    final highlight = Paint()..color = Colors.white.withValues(alpha: .14);
    canvas.drawCircle(center + const Offset(-17, -18), 19, highlight);

    final face =
        Paint()
          ..color = faceColor
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5;
    canvas.drawLine(
      center + const Offset(-18, -4),
      center + const Offset(-18, 4),
      face,
    );
    canvas.drawLine(
      center + const Offset(18, -4),
      center + const Offset(18, 4),
      face,
    );
    final smile =
        Path()
          ..moveTo(center.dx - 18, center.dy + 19)
          ..quadraticBezierTo(
            center.dx,
            center.dy + 34,
            center.dx + 20,
            center.dy + 17,
          );
    canvas.drawPath(smile, face);

    // The guide's defining feature: a Czech háček hovering like eyebrows.
    final mark =
        Paint()
          ..color = color
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
    final hacek =
        Path()
          ..moveTo(center.dx - 24, 9)
          ..lineTo(center.dx, 29)
          ..lineTo(center.dx + 24, 9);
    canvas.drawPath(hacek, mark);
  }

  @override
  bool shouldRepaint(covariant _HacekGuidePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.faceColor != faceColor;
}

class _ArrivalBackdropPainter extends CustomPainter {
  const _ArrivalBackdropPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: .08);
    canvas.drawCircle(Offset(size.width * .12, size.height * .14), 88, paint);
    canvas.drawCircle(Offset(size.width * .94, size.height * .72), 132, paint);
    final dot = Paint()..color = color.withValues(alpha: .28);
    for (var i = 0; i < 9; i++) {
      final angle = (i / 9) * math.pi * 2;
      final radius = 74 + (18 * Curves.easeOut.transform(progress));
      canvas.drawCircle(
        Offset(
          size.width / 2 + math.cos(angle) * radius,
          98 + math.sin(angle) * radius,
        ),
        i.isEven ? 4 : 2.5,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArrivalBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _ArrivalCopy {
  const _ArrivalCopy({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.accent,
  });

  final String eyebrow;
  final String title;
  final String body;
  final String primaryLabel;
  final IconData primaryIcon;
  final Color Function(AppTokens) accent;

  factory _ArrivalCopy.forState(DailyArrivalState state) {
    final name = state.learnerName.isEmpty ? '' : ', ${state.learnerName}';
    return switch (state.kind) {
      DailyArrivalKind.firstStep => _ArrivalCopy(
        eyebrow: 'DOBRÝ DEN',
        title: 'Ready for your Czech win$name?',
        body: 'A few focused minutes are enough to move forward today.',
        primaryLabel: 'Start today’s lesson',
        primaryIcon: Icons.play_arrow_rounded,
        accent: (t) => t.pri,
      ),
      DailyArrivalKind.keepStreak => _ArrivalCopy(
        eyebrow: '${state.streak}-DAY STREAK',
        title: 'Keep the fire alive$name',
        body: 'One short lesson protects the rhythm you’ve built.',
        primaryLabel: 'Continue learning',
        primaryIcon: Icons.local_fire_department_rounded,
        accent: (t) => t.amber,
      ),
      DailyArrivalKind.reviewsReady => _ArrivalCopy(
        eyebrow: 'MEMORY BOOST',
        title:
            state.dueReviews == 1
                ? '1 word is ready for you$name'
                : '${state.dueReviews} words are ready for you$name',
        body: 'A quick review now will make them easier to recall later.',
        primaryLabel: 'Review now',
        primaryIcon: Icons.style_rounded,
        accent: (t) => t.violet,
      ),
      DailyArrivalKind.welcomeBack => _ArrivalCopy(
        eyebrow: 'VÍTEJTE ZPĚT',
        title: 'Your Czech is still here$name',
        body: 'Restart gently. One small step is all today needs.',
        primaryLabel: 'Make a fresh start',
        primaryIcon: Icons.wb_sunny_rounded,
        accent: (t) => t.green,
      ),
      DailyArrivalKind.goalComplete => _ArrivalCopy(
        eyebrow: 'DAILY GOAL COMPLETE',
        title: 'You did it$name!',
        body: 'Your Czech moved forward today. Anything else is a bonus.',
        primaryLabel:
            state.hasLesson ? 'Take a bonus lesson' : 'See my progress',
        primaryIcon: Icons.auto_awesome_rounded,
        accent: (t) => t.green,
      ),
      DailyArrivalKind.courseComplete => _ArrivalCopy(
        eyebrow: 'SKVĚLÁ PRÁCE',
        title: 'Look how far you’ve come$name',
        body: 'Explore the course or revisit a lesson to keep Czech fresh.',
        primaryLabel: 'Explore the course',
        primaryIcon: Icons.map_rounded,
        accent: (t) => t.pri,
      ),
    };
  }
}

class _ArrivalLoading extends StatelessWidget {
  const _ArrivalLoading({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedBuilder(
      animation: animation,
      builder:
          (context, _) => Transform.scale(
            scale: .8 + (.2 * Curves.easeOutBack.transform(animation.value)),
            child: _HacekGuide(color: context.tokens.pri),
          ),
    ),
  );
}

class _ArrivalFallback extends StatelessWidget {
  const _ArrivalFallback({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HacekGuide(color: context.tokens.pri),
            const SizedBox(height: 24),
            Text(
              'Dobrý den!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onContinue,
                child: const Text('Continue to Home'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
