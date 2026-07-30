import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/gamification_providers.dart';
import '../../providers/review_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/tts_providers.dart';
import '../../widgets/common/soft_ui.dart';
import '../../widgets/common/learning_tip_card.dart';
import '../lesson/delayed_transfer_screen.dart';

/// Home dashboard — greeting, daily goal hero, continue learning, quick
/// actions and shortcuts. Redesigned per the "Calm & premium" handoff.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final g = ref.watch(gamificationProvider);
    final settings = ref.watch(settingsProvider);
    final dueCount = ref.watch(dueCardCountProvider).value ?? 0;
    final dueTransfers = ref.watch(dueTransferProvider).value ?? const [];

    // Time-aware greeting + personalized name.
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12
            ? 'Dobré ráno'
            : hour < 18
            ? 'Dobré odpoledne'
            : 'Dobrý večer';
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            // Header: greeting + hearts/streak + settings.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting · today',
                        style: TextStyle(fontSize: 12.5, color: t.faint),
                      ),
                      const SizedBox(height: 3),
                      DisplayText(
                        settings.learnerName.isNotEmpty
                            ? settings.learnerName
                            : 'Czechify',
                        size: 26,
                        weight: FontWeight.w800,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: AppLocalizations.of(
                    context,
                  ).homeDayStreak(g.currentStreak),
                  child: PillChip(
                    label: '${g.currentStreak}',
                    bg: t.amberSoft,
                    fg: t.amber,
                    icon: Icons.local_fire_department,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => context.push('/settings'),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.chipBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      size: 22,
                      color: t.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // One-time hint when the device lacks a Czech voice — otherwise
            // every "listen" button silently does nothing.
            if (ref.watch(czechTtsAvailableProvider).value == false) ...[
              const _CzechVoiceHint(),
              const SizedBox(height: 14),
            ],

            _DailyGoalHero(
              dailyXp: g.dailyXp,
              dailyGoalXp: g.dailyGoalXp,
              totalXp: g.totalXp,
              streak: g.currentStreak,
            ),
            const SizedBox(height: 14),

            const _ContinueLearningCard(),
            const SizedBox(height: 14),
            if (dueTransfers.isNotEmpty) ...[
              _ShortcutRow(
                icon: Icons.update,
                tint: t.amberSoft,
                fg: t.amber,
                title: 'Check what stayed',
                subtitle:
                    '${dueTransfers.length} delayed transfer '
                    '${dueTransfers.length == 1 ? 'task' : 'tasks'} due',
                onTap:
                    () => context.push(
                      '/transfer/${Uri.encodeComponent(dueTransfers.first.assignmentId)}',
                    ),
              ),
              const SizedBox(height: 14),
            ],

            // Daily learning tip — evidence-based strategies.
            const LearningTipCard(),
            const SizedBox(height: 14),

            _ShortcutRow(
              icon: Icons.mic_none,
              tint: t.redSoft,
              fg: t.redInk,
              title: 'Say it out loud',
              subtitle:
                  dueCount > 0
                      ? 'Warm up, then review $dueCount due cards'
                      : 'Two minutes of focused Czech pronunciation',
              onTap: () => context.push('/pronunciation/practice'),
            ),
            const SizedBox(height: 14),

            _ShortcutRow(
              icon: Icons.route_outlined,
              tint: t.violetSoft,
              fg: t.violet,
              title: 'Find my starting point',
              subtitle: 'Short multiskill diagnostic · learner adjustable',
              onTap: () => context.push('/placement'),
            ),
            const SizedBox(height: 10),
            _ShortcutRow(
              icon: Icons.assignment_outlined,
              tint: t.redSoft,
              fg: t.red,
              title: AppLocalizations.of(context).homeMockExam,
              subtitle: 'Timed informal practice · A1 track',
              onTap: () => _showExamLevelPicker(context),
            ),
            const SizedBox(height: 10),
            _ShortcutRow(
              icon: Icons.menu_book_outlined,
              tint: t.greenSoft,
              fg: t.green,
              title: AppLocalizations.of(context).homeGrammarReference,
              subtitle: 'All rules & examples',
              onTap: () => context.push('/grammar'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to choose the mock-exam level (A1 or A2).
void _showExamLevelPicker(BuildContext context) {
  final t = context.tokens;
  showModalBottomSheet<void>(
    context: context,
    builder:
        (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: DisplayText('Choose exam level', size: 20),
              ),
              for (final level in const [
                ('A1', 'A1-style informal practice', 'a1'),
                ('A2', 'A2-style informal practice', 'a2'),
              ])
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.priSoft,
                    child: Text(
                      level.$1,
                      style: TextStyle(
                        color: t.priInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(level.$2),
                  subtitle: const Text('Reading, listening, writing, speaking'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/exam/${level.$3}');
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
  );
}

/// Quiet daily-goal card. Progress supports the next lesson instead of
/// competing with it as the page's primary action.
class _DailyGoalHero extends StatelessWidget {
  const _DailyGoalHero({
    required this.dailyXp,
    required this.dailyGoalXp,
    required this.totalXp,
    required this.streak,
  });

  final int dailyXp;
  final int dailyGoalXp;
  final int totalXp;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progress =
        dailyGoalXp > 0 ? (dailyXp / dailyGoalXp).clamp(0.0, 1.0) : 0.0;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 76,
                child: CustomPaint(
                  painter: _GoalRingPainter(
                    progress: progress,
                    track: t.elev,
                    fill: t.pri,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$dailyXp',
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: t.ink,
                          ),
                        ),
                        Text(
                          '/ $dailyGoalXp XP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily goal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress >= 1
                          ? 'Done for today. Anything else is a bonus.'
                          : dailyXp == 0
                          ? 'One short lesson gets today moving.'
                          : '${dailyGoalXp - dailyXp} XP to your daily rhythm.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: t.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: t.line),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.local_fire_department, size: 17, color: t.amberInk),
              const SizedBox(width: 6),
              Text(
                '$streak day streak',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
              const Spacer(),
              Text(
                '$totalXp total XP',
                style: TextStyle(fontSize: 13, color: t.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalRingPainter extends CustomPainter {
  const _GoalRingPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708,
        6.2832 * progress,
        false,
        paint..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoalRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.fill != fill;
}

/// Continue-learning card — next uncompleted lesson.
class _ContinueLearningCard extends ConsumerWidget {
  const _ContinueLearningCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final nextAsync = ref.watch(nextLessonProvider);

    return nextAsync.when(
      loading:
          () => SoftCard(
            child: Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 14),
                Text('Loading…', style: TextStyle(color: t.muted)),
              ],
            ),
          ),
      error:
          (_, __) => _ShortcutRow(
            icon: Icons.school_outlined,
            tint: t.priSoft,
            fg: t.pri,
            title: AppLocalizations.of(context).homeBrowseCurriculum,
            subtitle: AppLocalizations.of(context).homeStartFirstLesson,
            onTap: () => context.go('/curriculum'),
          ),
      data: (next) {
        if (next == null) {
          return _ShortcutRow(
            icon: Icons.check_circle_outline,
            tint: t.greenSoft,
            fg: t.green,
            title: AppLocalizations.of(context).homeAllCaughtUp,
            subtitle: 'Every unlocked lesson is complete.',
            onTap: () => context.go('/curriculum'),
          );
        }
        return SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          onTap: () => context.push('/lesson/${next.lesson.id}'),
          child: Row(
            children: [
              IconTile(
                icon: Icons.play_arrow_rounded,
                tint: t.priSoft,
                fg: t.pri,
                size: 46,
                radius: 16,
                iconSize: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue learning',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // The lesson title identifies where you left off, so it
                    // leads; the unit and the reason share the faint line,
                    // where a truncated tail costs nothing.
                    Text(
                      next.lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: t.muted,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${next.unitTitle} · ${next.reason}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: t.faint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 18, color: t.faint),
            ],
          ),
        );
      },
    );
  }
}

/// Full-width shortcut row with tinted icon, title, subtitle, chevron.
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.icon,
    required this.tint,
    required this.fg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color fg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      onTap: onTap,
      child: Row(
        children: [
          IconTile(
            icon: icon,
            tint: tint,
            fg: fg,
            size: 40,
            radius: 14,
            iconSize: 17,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(subtitle, style: TextStyle(fontSize: 14, color: t.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: t.faint),
        ],
      ),
    );
  }
}

/// Shown when the device has no Czech TTS voice: pronunciation of arbitrary
/// text will be silent until one is installed (bundled neural audio still
/// covers curriculum content).
class _CzechVoiceHint extends StatelessWidget {
  const _CzechVoiceHint();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.amberSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.record_voice_over, size: 20, color: t.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No Czech voice is installed on this device, so some "listen" '
              'buttons may stay silent. Add a Czech voice in your system '
              'settings (Accessibility → Spoken Content on iOS, '
              'Text-to-speech on Android).',
              style: TextStyle(fontSize: 13, color: t.ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
