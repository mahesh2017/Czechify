import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_tokens.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/gamification_providers.dart';
import '../../providers/review_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/tts_providers.dart';
import '../../screens/lesson/delayed_transfer_screen.dart'
    show dueTransferProvider;
import '../../widgets/common/soft_ui.dart';
import '../../widgets/common/wash_background.dart';
import '../../widgets/home/streak_state_sheet.dart';

/// The freeze chip's ice blue. Not tokenised, because a freeze is none of the
/// six semantic hues — it is its own idea, and it needs to stay recognisable
/// as ice. The comp only states the light values; the dark pair keeps the
/// same hue at dark-surface weight rather than punching a white pill through
/// the card.
const Color _freezeTintLight = Color(0xFFE7F2FB);
const Color _freezeInkLight = Color(0xFF2F72AE);
const Color _freezeTintDark = Color(0xFF16283D);
const Color _freezeInkDark = Color(0xFF9FD6F1);

/// Home dashboard matching the Czechify v2 prototype.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final g = ref.watch(gamificationProvider);
    final settings = ref.watch(settingsProvider);
    final dueCount = ref.watch(dueCardCountProvider).value ?? 0;
    final hour = DateTime.now().hour;
    // Deliberately not localised. This is the language being taught, not app
    // chrome — the learner meets "Dobré ráno" here before any lesson teaches
    // it, in whichever locale they run the app. Flagged in review as an
    // inconsistency next to the localised weekday below; recorded here as a
    // choice so it is not "fixed" into English by the next reader.
    final greeting =
        hour < 12
            ? 'Dobré ráno'
            : hour < 18
            ? 'Dobré odpoledne'
            : 'Dobrý večer';
    final name =
        settings.learnerName.isNotEmpty ? settings.learnerName : 'Czechify';
    final weekday = DateFormat.EEEE(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(DateTime.now());

    return Scaffold(
      backgroundColor: t.bg,
      body: WashBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // Opaque, so the header reads as its own warm surface
                  // rather than letting the wash's cool corner through it.
                  colors: [Color.lerp(t.amberSoft, t.bg, .46)!, t.bg],
                  stops: const [0, .86],
                ),
              ),
              child: Stack(
                children: [
                  // Two soft blooms behind the greeting, bleeding off the top
                  // corners the way the header does in the comp.
                  Positioned(
                    left: -80,
                    top: -130,
                    child: _Bloom(
                      size: 300,
                      color: t.card.withValues(alpha: .38),
                    ),
                  ),
                  Positioned(
                    right: -100,
                    top: -90,
                    child: _Bloom(
                      size: 260,
                      color: t.priSoft.withValues(alpha: .66),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 60, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [t.card, t.elev],
                                ),
                                border: Border.all(color: t.line),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                name.characters.first.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: AppFonts.display,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: t.muted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$greeting · $weekday',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: t.faint,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  DisplayText(
                                    name,
                                    size: 26,
                                    weight: FontWeight.w800,
                                  ),
                                ],
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: AppLocalizations.of(
                                context,
                              ).homeDayStreak(g.currentStreak),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap:
                                    () => showStreakStateSheet(
                                      context,
                                      streak: g.currentStreak,
                                      freezeAvailable: g.streakFreezeAvailable,
                                    ),
                                child: PillChip(
                                  label: '${g.currentStreak}',
                                  bg: t.card,
                                  fg: t.ink,
                                  // Amber is the streak's colour; the count
                                  // beside it is ordinary ink.
                                  icon: Icons.local_fire_department,
                                  iconColor: t.amber,
                                  border: t.line,
                                  fontSize: 13,
                                  shadow: [
                                    BoxShadow(
                                      color: t.ink.withValues(alpha: .44),
                                      blurRadius: 16,
                                      spreadRadius: -14,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Semantics(
                              button: true,
                              label: AppLocalizations.of(context).a11ySettings,
                              child: InkWell(
                                onTap: () => context.push('/settings'),
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: t.line),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                    color: t.muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Text(
                          g.dailyXp == 0
                              ? l10n.homeSmallWin
                              : l10n.homeProgressToday,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: t.muted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _ContinueLearningCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 132),
              child: Column(
                children: [
                  if (ref.watch(czechTtsAvailableProvider).value == false) ...[
                    const _CzechVoiceHint(),
                    const SizedBox(height: 12),
                  ],
                  _DailyGoalHero(
                    dailyXp: g.dailyXp,
                    dailyGoalXp: g.dailyGoalXp,
                    totalXp: g.totalXp,
                    streak: g.currentStreak,
                    freezeAvailable: g.streakFreezeAvailable,
                  ),
                  const SizedBox(height: 12),
                  _ShortcutRow(
                    icon: Icons.mic_none,
                    tint: t.redSoft,
                    fg: t.redInk,
                    title: l10n.homeSpeakTitle,
                    subtitle:
                        dueCount > 0
                            ? l10n.homeSpeakReviews(dueCount)
                            : l10n.homeSpeakSound,
                    onTap: () => context.push('/pronunciation/practice'),
                  ),
                  const SizedBox(height: 12),
                  _DueTransfers(),
                  const SizedBox(height: 22),
                  _TodayQuests(dailyXp: g.dailyXp, dueCount: dueCount),
                  const SizedBox(height: 22),
                  const _MethodOfDay(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft circular bloom — the `radial-gradient(closest-side, …)` decorations
/// that bleed off the corners of the hero areas in the comp.
class _Bloom extends StatelessWidget {
  const _Bloom({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Quiet daily-goal card. Progress supports the next lesson instead of
/// competing with it as the page's primary action.
class _DailyGoalHero extends StatelessWidget {
  const _DailyGoalHero({
    required this.dailyXp,
    required this.dailyGoalXp,
    required this.totalXp,
    required this.streak,
    required this.freezeAvailable,
  });

  final int dailyXp;
  final int dailyGoalXp;
  final int totalXp;
  final int streak;
  final bool freezeAvailable;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final freezeTint = dark ? _freezeTintDark : _freezeTintLight;
    final freezeInk = dark ? _freezeInkDark : _freezeInkLight;
    final progress =
        dailyGoalXp > 0 ? (dailyXp / dailyGoalXp).clamp(0.0, 1.0) : 0.0;
    // The rule between the goal and the streak runs edge to edge, so the
    // card carries no padding of its own and each block pads itself.
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
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
                        l10n.homeDailyGoal,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progress >= 1
                            ? l10n.homeGoalDone
                            : dailyXp == 0
                            ? l10n.homeGoalStart
                            : l10n.homeXpRemaining(dailyGoalXp - dailyXp),
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
          ),
          // Edge-to-edge rule between the goal and the streak.
          Container(height: 1, color: t.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.streakDays(streak),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.fromLTRB(9, 5, 10, 5),
                      decoration: BoxDecoration(
                        color: freezeTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.ac_unit_rounded,
                            size: 12,
                            color: freezeInk,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            freezeAvailable
                                ? l10n.homeFreezeLeft
                                : l10n.homeTotalXp(totalXp),
                            style: TextStyle(
                              color: freezeInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _WeekStrip(streak: streak),
              ],
            ),
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
    // A conic donut in the comp, not a stroked arc: 8pt between the 76pt
    // outer and 60pt inner circles, with flat ends.
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.butt;
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

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = DateTime.now();
    final today = now.weekday - 1;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monday = now.subtract(Duration(days: today));
    final labels = List.generate(
      7,
      (index) => DateFormat.E(locale).format(monday.add(Duration(days: index))),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final done = index < today && streak > today - index;
        final current = index == today;
        // Earned days carry an amber tint, today is a card-white tile ringed
        // in the accent, and days still to come are drawn as an empty
        // outline — never filled, so the week reads as progress.
        return Column(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    done
                        ? Color.lerp(t.amber, t.card, .84)
                        : current
                        ? t.card
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  width: 1.5,
                  color:
                      current
                          ? t.pri
                          : done
                          ? t.amber.withValues(alpha: .26)
                          : t.line,
                ),
              ),
              child:
                  done
                      ? Icon(Icons.check_rounded, size: 18, color: t.amber)
                      : current
                      ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: t.pri,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: t.pri.withValues(alpha: .12),
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      )
                      : Text(
                        '${monday.add(Duration(days: index)).day}',
                        style: TextStyle(
                          color: t.faint,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
            ),
            const SizedBox(height: 7),
            Text(
              labels[index],
              style: TextStyle(
                color: t.faint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      }),
    );
  }
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
                Text(
                  AppLocalizations.of(context).homeLoading,
                  style: TextStyle(color: t.muted),
                ),
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
            subtitle: AppLocalizations.of(context).homeUnlockedComplete,
            onTap: () => context.go('/curriculum'),
          );
        }
        // The one hero surface on Home: a card that tips towards the accent
        // rather than sitting flat white, on the large shadow.
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.pri.withValues(alpha: .13)),
            boxShadow: t.shadowLg,
            gradient: LinearGradient(
              begin: const Alignment(-0.62, -1),
              end: const Alignment(0.62, 1),
              colors: [t.card, Color.lerp(t.priSoft, t.card, .44)!],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              button: true,
              label: AppLocalizations.of(context).homeContinueLearning,
              child: InkWell(
                onTap: () => context.push('/lesson/${next.lesson.id}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 19, 20, 19),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: -12,
                        bottom: -72,
                        child: Text(
                          'ř',
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 152,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            color: t.pri.withValues(alpha: .07),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).homeContinueLearning,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.8,
                                    color: t.faint,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  next.lesson.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.display,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: t.ink,
                                    height: 1.14,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${next.unitTitle} · ${next.reason}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: t.faint,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: .35,
                                          minHeight: 5,
                                          backgroundColor: t.pri.withValues(
                                            alpha: .12,
                                          ),
                                          valueColor: AlwaysStoppedAnimation(
                                            t.pri,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '35%',
                                      style: TextStyle(
                                        color: t.pri,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: t.pri,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: t.pri.withValues(alpha: .35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 31,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TodayQuests extends StatelessWidget {
  const _TodayQuests({required this.dailyXp, required this.dueCount});

  final int dailyXp;
  final int dueCount;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final quests = [
      (
        l10n.homeCompleteLesson,
        dailyXp > 0 ? 1.0 : 0.0,
        '10 XP',
        Icons.school_outlined,
        t.pri,
        t.priSoft,
      ),
      (
        l10n.homeReviewFive,
        (dueCount == 0 ? 1.0 : 0.2),
        '5 XP',
        Icons.refresh_rounded,
        t.green,
        t.greenSoft,
      ),
      (l10n.homeSpeakTwoMinutes, 0.0, '5 XP', Icons.mic_none, t.red, t.redSoft),
    ];
    final done = quests.where((q) => q.$2 >= 1).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Text(
                l10n.homeSmallSteps,
                style: TextStyle(
                  color: t.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$done of 3',
                style: TextStyle(
                  color: t.faint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < quests.length; i++) ...[
          if (i > 0) Divider(height: 1, color: t.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
            child: Row(
              children: [
                IconTile(
                  icon: quests[i].$4,
                  tint: quests[i].$6,
                  fg: quests[i].$5,
                  size: 42,
                  radius: 16,
                  iconSize: 21,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              quests[i].$1,
                              style: TextStyle(
                                color: t.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            quests[i].$2 >= 1 ? '1 / 1' : '0 / 1',
                            style: TextStyle(
                              color: t.faint,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: quests[i].$2,
                          backgroundColor: t.elev,
                          valueColor: AlwaysStoppedAnimation(quests[i].$5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // The reward pill only earns colour once it is claimed —
                // until then it is neutral, so the row's one hue is the
                // quest's own progress bar.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: quests[i].$2 >= 1 ? t.greenSoft : t.elev,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    quests[i].$2 >= 1 ? l10n.homeDone : quests[i].$3,
                    style: TextStyle(
                      color: quests[i].$2 >= 1 ? t.green : t.faint,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MethodOfDay extends StatelessWidget {
  const _MethodOfDay();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 0),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: Icons.draw_outlined,
                tint: t.amberSoft,
                fg: t.amber,
                size: 40,
                radius: 12,
                iconSize: 20,
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeMethodOfDay,
                    style: TextStyle(
                      color: t.amberInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.7,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.homeWriteBeforeType,
                    style: TextStyle(
                      color: t.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            l10n.homeMethodBody,
            style: TextStyle(color: t.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => context.push('/copybook'),
            icon: const Icon(Icons.description_outlined, size: 16),
            label: Text(l10n.homeCopybookCta),
          ),
        ],
      ),
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
    return Semantics(
      button: true,
      label: title,
      child: SoftCard(
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
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: t.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: t.faint),
          ],
        ),
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

/// Shows due delayed-transfer assignments so the learner can revisit concepts
/// they struggled with, tested in a new context after a delay.
class _DueTransfers extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(dueTransferProvider);
    final t = context.tokens;

    return transfers.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            color: t.violetSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.violet.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    Icon(Icons.psychology, size: 20, color: t.violet),
                    const SizedBox(width: 10),
                    Text(
                      'Recall practice',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.violetInk,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: t.violet,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'These concepts need a fresh attempt in a new way. '
                  'Your progress is measured independently — not by whether '
                  'you still remember the hint.',
                  style: TextStyle(fontSize: 13, color: t.muted, height: 1.35),
                ),
              ),
              for (final item in items.take(3))
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Material(
                    color: Colors.transparent,
                    child: Semantics(
                      button: true,
                      label: 'Lesson ${item.lessonId} · try it again',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap:
                            () =>
                                context.push('/transfer/${item.assignmentId}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 18,
                                color: t.violet,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Lesson ${item.lessonId} · '
                                  'try it again',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: t.ink,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: t.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
