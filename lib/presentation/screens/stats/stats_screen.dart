import 'package:flutter/material.dart' hide Badge;
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../providers/gamification_providers.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/database_providers.dart';
import '../../widgets/common/soft_ui.dart';
import '../../../domain/engines/curriculum_tracker.dart';
import '../../../domain/entities/exam_result.dart';
import '../../../domain/entities/gamification_state.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/unit.dart';
import '../../../domain/entities/practice_evidence.dart';
import '../../../domain/entities/concept_error_evidence.dart';
import '../../widgets/common/wash_background.dart';

/// Stats screen — dated course-practice evidence, badges, and engagement.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final gamification = ref.watch(gamificationProvider);
    final dataAsync = ref.watch(_statsDataProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: WashBackground(
        child: SafeArea(
          bottom: false,
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (_, __) => Center(
                  child: Text(AppLocalizations.of(context).errorFailedToLoad),
                ),
            data: (data) {
              final snapshot = data.snapshot;
              final tracker = CurriculumProgressTracker();

              final a1UnitIds =
                  data.units
                      .where((u) => u.phase == Phase.a1)
                      .map((u) => u.id)
                      .toSet();
              final a2UnitIds =
                  data.units
                      .where((u) => u.phase == Phase.a2)
                      .map((u) => u.id)
                      .toSet();

              final a1Completion = tracker.phaseLessonCoverage(
                completedLessonsByUnit: snapshot.completedLessonsByUnit,
                totalLessonsByUnit: snapshot.totalLessonsByUnit,
                phaseUnitIds: a1UnitIds,
              );
              final a2Completion = tracker.phaseLessonCoverage(
                completedLessonsByUnit: snapshot.completedLessonsByUnit,
                totalLessonsByUnit: snapshot.totalLessonsByUnit,
                phaseUnitIds: a2UnitIds,
              );

              final startedA1 =
                  a1UnitIds
                      .where(
                        (id) => (snapshot.completedLessonsByUnit[id] ?? 0) > 0,
                      )
                      .toList()
                    ..sort();
              final startedA2 =
                  a2UnitIds
                      .where(
                        (id) => (snapshot.completedLessonsByUnit[id] ?? 0) > 0,
                      )
                      .toList()
                    ..sort();
              final difficultConcepts =
                  snapshot.conceptErrors.values.toList()..sort(
                    (a, b) => b.initialErrors.compareTo(a.initialErrors),
                  );
              final nextConcept =
                  difficultConcepts.isEmpty ? null : difficultConcepts.first;

              return ListView(
                // The shell deliberately extends content behind its 92pt
                // translucent tab bar. Keep the final badge controls fully
                // scrollable above it, including the iPhone home indicator.
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                children: [
                  DisplayText(
                    AppLocalizations.of(context).statsTitle,
                    size: 29,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    AppLocalizations.of(context).statsSubtitle,
                    style: TextStyle(fontSize: 14, color: t.muted, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  _StatsGrid(gamification: gamification),
                  const SizedBox(height: 14),
                  _CompletionCard(
                    a1Completion: a1Completion,
                    a2Completion: a2Completion,
                  ),
                  const SizedBox(height: 14),
                  _NextPracticeCard(concept: nextConcept),
                  const SizedBox(height: 14),
                  const _ExamHistoryCard(),
                  const SizedBox(height: 14),
                  _UnitMasteryCard(
                    unitScores: snapshot.unitScores,
                    a1Units: startedA1,
                    a2Units: startedA2,
                  ),
                  const SizedBox(height: 14),
                  _SkillEvidenceCard(evidence: snapshot.componentEvidence),
                  const SizedBox(height: 14),
                  _ConceptErrorsCard(evidence: snapshot.conceptErrors),
                  const SizedBox(height: 14),
                  _BadgesCard(earnedBadges: gamification.earnedBadges),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A learner-facing recommendation before the detailed evidence tables.
class _NextPracticeCard extends StatelessWidget {
  const _NextPracticeCard({required this.concept});

  final ConceptErrorEvidence? concept;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: Icons.auto_awesome_outlined,
                tint: t.violetSoft,
                fg: t.violetInk,
                size: 40,
                radius: 13,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: SectionLabel(l10n.statsPracticeNext)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            concept == null
                ? l10n.statsPracticeNextDefault
                : l10n.statsPracticeNextConcept(concept!.label),
            style: TextStyle(fontSize: 15, height: 1.45, color: t.muted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/curriculum'),
              icon: const Icon(Icons.school_outlined),
              label: Text(l10n.statsContinueLearning),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConceptErrorsCard extends StatelessWidget {
  final Map<String, ConceptErrorEvidence> evidence;

  const _ConceptErrorsCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final concepts =
        evidence.values.toList()..sort((a, b) {
          final byCount = b.initialErrors.compareTo(a.initialErrors);
          return byCount != 0 ? byCount : a.label.compareTo(b.label);
        });

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(AppLocalizations.of(context).statsConceptsToRevisit),
          const SizedBox(height: 5),
          Text(
            AppLocalizations.of(context).statsConceptsExplanation,
            style: TextStyle(fontSize: 13, color: t.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (concepts.isEmpty)
            Text(
              AppLocalizations.of(context).statsNoConceptErrors,
              style: TextStyle(color: t.muted),
            )
          else
            for (final concept in concepts) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      concept.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context).statsErrorsRepaired(
                      concept.initialErrors,
                      concept.repairedErrors,
                    ),
                    style: TextStyle(fontSize: 12.5, color: t.muted),
                  ),
                ],
              ),
              if (concept != concepts.last) const Divider(height: 18),
            ],
        ],
      ),
    );
  }
}

class _SkillEvidenceCard extends StatelessWidget {
  final Map<String, PracticeEvidence> evidence;

  const _SkillEvidenceCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final skills =
        evidence.entries
            .where((entry) => entry.key.startsWith('skill:'))
            .map((entry) => entry.value)
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(AppLocalizations.of(context).statsSkillPractice),
          const SizedBox(height: 5),
          Text(
            AppLocalizations.of(context).statsSkillExplanation,
            style: TextStyle(fontSize: 13, color: t.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (skills.isEmpty)
            Text(
              AppLocalizations.of(context).statsNoSkillEvidence,
              style: TextStyle(color: t.muted),
            )
          else
            for (final item in skills) ...[
              _SkillEvidenceRow(evidence: item),
              if (item != skills.last) const Divider(height: 18),
            ],
        ],
      ),
    );
  }
}

class _SkillEvidenceRow extends StatelessWidget {
  final PracticeEvidence evidence;

  const _SkillEvidenceRow({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final firstPass = evidence.firstPassAccuracy;
    final repair = evidence.repairAccuracy;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                evidence.label,
                style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
              ),
              const SizedBox(height: 3),
              Text(
                AppLocalizations.of(context).statsAttemptEvidence(
                  evidence.evidenceDepth.label,
                  evidence.initialAttempts,
                  repair == null ? '—' : '${(repair * 100).round()}%',
                ),
                style: TextStyle(fontSize: 12.5, color: t.muted),
              ),
            ],
          ),
        ),
        Text(
          firstPass == null ? '—' : '${(firstPass * 100).round()}%',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: firstPass == null ? t.muted : t.pri,
          ),
        ),
      ],
    );
  }
}

/// Past mock-exam attempts across both levels, newest first.
final _examHistoryProvider = FutureProvider.autoDispose<List<ExamResult>>((
  ref,
) async {
  final repo = ref.read(examRepositoryProvider);
  final a1 = await repo.getResults(ExamLevel.a1);
  final a2 = await repo.getResults(ExamLevel.a2);
  return [...a1, ...a2]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
});

class _StatsData {
  final ProgressSnapshot snapshot;
  final List<Unit> units;
  const _StatsData({required this.snapshot, required this.units});
}

/// Progress snapshot + unit catalogue for the stats screen.
final _statsDataProvider = FutureProvider.autoDispose<_StatsData>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  final snapshot = await repo.getSnapshot();
  final units = await ref.watch(allUnitsProvider.future);
  return _StatsData(snapshot: snapshot, units: units);
});

/// A1/A2 completion progress bars.
class _CompletionCard extends StatelessWidget {
  final double a1Completion;
  final double a2Completion;

  const _CompletionCard({
    required this.a1Completion,
    required this.a2Completion,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(AppLocalizations.of(context).statsCourseProgress),
          const SizedBox(height: 5),
          Text(
            AppLocalizations.of(context).statsCourseProgressBody,
            style: TextStyle(
              fontSize: 13,
              color: context.tokens.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _ProgressRow(label: 'A1 — Beginner', progress: a1Completion),
          const SizedBox(height: 14),
          _ProgressRow(label: 'A2 — Elementary', progress: a2Completion),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double progress;

  const _ProgressRow({required this.label, required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final percent = (progress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: t.ink,
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: percent == 0 ? t.muted : t.pri,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SoftProgressBar(value: progress, height: 7),
      ],
    );
  }
}

/// Stats grid — streak, XP, longest streak, hearts.
class _StatsGrid extends StatelessWidget {
  final GamificationState gamification;

  const _StatsGrid({required this.gamification});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      // 2.5 left the tile ~7pt shorter than its own content, so every tile
      // overflowed and clipped its label.
      childAspectRatio: 2.2,
      children: [
        _StatTile(
          icon: Icons.local_fire_department_outlined,
          tint: context.tokens.amberSoft,
          foreground: context.tokens.amberInk,
          value: '${gamification.currentStreak}',
          label: AppLocalizations.of(context).statsDayStreak,
        ),
        _StatTile(
          icon: Icons.bolt_outlined,
          tint: context.tokens.amberSoft,
          foreground: context.tokens.amberInk,
          value: '${gamification.totalXp}',
          label: AppLocalizations.of(context).statsTotalXp,
        ),
        _StatTile(
          icon: Icons.calendar_month_outlined,
          tint: context.tokens.priSoft,
          foreground: context.tokens.priInk,
          value: '${gamification.longestStreak}',
          label: AppLocalizations.of(context).statsLongestStreak,
        ),
        _StatTile(
          icon: Icons.favorite_border,
          tint: context.tokens.redSoft,
          foreground: context.tokens.redInk,
          value: '${gamification.hearts}/${gamification.maxHearts}',
          label: AppLocalizations.of(context).statsHearts,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final Color foreground;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.tint,
    required this.foreground,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          IconTile(
            icon: icon,
            tint: tint,
            fg: foreground,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: t.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamHistoryCard extends ConsumerWidget {
  const _ExamHistoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final results =
        ref.watch(_examHistoryProvider).value ?? const <ExamResult>[];
    if (results.isEmpty) {
      return SoftCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Exam history'),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.assignment_outlined, size: 20, color: t.faint),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No mock exams yet. Try a practice exam from the '
                    'curriculum to see your results here.',
                    style: TextStyle(fontSize: 14, color: t.muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Exam history'),
          const SizedBox(height: 10),
          ...results.take(10).map((r) {
            final date =
                '${r.takenAt.year}-${r.takenAt.month.toString().padLeft(2, '0')}-${r.takenAt.day.toString().padLeft(2, '0')}';
            final color = r.passed ? t.green : t.red;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    r.passed ? Icons.check_circle : Icons.cancel,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.product.displayName} '
                          '${r.level.name.toUpperCase()}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(fontSize: 13, color: t.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${r.totalScore}%',
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Coverage-adjusted unit practice evidence.
class _UnitMasteryCard extends StatelessWidget {
  final Map<int, double> unitScores;
  final List<int> a1Units;
  final List<int> a2Units;

  const _UnitMasteryCard({
    required this.unitScores,
    required this.a1Units,
    required this.a2Units,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (a1Units.isEmpty && a2Units.isEmpty) {
      return SoftCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          AppLocalizations.of(context).statsNoLessonsYet,
          style: TextStyle(color: t.muted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(AppLocalizations.of(context).statsUnitProgress),
          const SizedBox(height: 5),
          Text(
            AppLocalizations.of(context).statsUnitProgressBody,
            style: TextStyle(fontSize: 13, color: t.muted),
          ),
          const SizedBox(height: 12),
          if (a1Units.isNotEmpty) ...[
            Text(
              AppLocalizations.of(context).statsA1Units,
              style: TextStyle(
                fontSize: 14,
                color: t.pri,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...a1Units.map(
              (id) => _UnitScoreRow(unitId: id, score: unitScores[id] ?? 0),
            ),
          ],
          if (a2Units.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).statsA2Units,
              style: TextStyle(
                fontSize: 14,
                color: t.green,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...a2Units.map(
              (id) => _UnitScoreRow(unitId: id, score: unitScores[id] ?? 0),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnitScoreRow extends StatelessWidget {
  final int unitId;
  final double score;

  const _UnitScoreRow({required this.unitId, required this.score});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final percent = (score * 100).round();
    final color =
        score >= 0.8
            ? t.green
            : score >= 0.6
            ? t.amber
            : t.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              'Unit $unitId',
              style: TextStyle(fontSize: 15, color: t.ink),
            ),
          ),
          Expanded(child: SoftProgressBar(value: score, color: color)),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              '$percent%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badges display.
class _BadgesCard extends StatelessWidget {
  final Set<String> earnedBadges;

  const _BadgesCard({required this.earnedBadges});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final earned =
        Badge.all.where((badge) => earnedBadges.contains(badge.id)).toList();
    final next =
        Badge.all
            .where((badge) => !earnedBadges.contains(badge.id))
            .take(3)
            .toList();
    final visible = [...earned, ...next];
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SectionLabel(AppLocalizations.of(context).statsAchievements),
              Text(
                '${earnedBadges.length} of ${Badge.all.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.pri,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (earned.isEmpty) ...[
            Text(
              AppLocalizations.of(context).statsAchievementsEmpty,
              style: TextStyle(fontSize: 14, color: t.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
          ],
          // Tiles fill the row rather than sitting at a fixed 64pt, so longer
          // names ("A1 Practice Milestone") wrap instead of ellipsing. The
          // column count falls to three on narrow phones, where four tiles
          // would each be thinner than the badge circle they contain.
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 14.0;
              const minTile = 62.0;
              final columns = ((constraints.maxWidth + spacing) /
                      (minTile + spacing))
                  .floor()
                  .clamp(3, 5);
              final tileWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 14,
                children:
                    visible.map((badge) {
                      return _BadgeTile(
                        badge: badge,
                        isEarned: earnedBadges.contains(badge.id),
                        width: tileWidth,
                      );
                    }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Badge badge;
  final bool isEarned;
  final double width;

  const _BadgeTile({
    required this.badge,
    required this.isEarned,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: '${badge.name}: ${badge.description}',
      child: Opacity(
        opacity: isEarned ? 1.0 : 0.35,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEarned ? t.amberSoft : t.chipBg,
                ),
                child: Icon(
                  _badgeIcon(badge),
                  size: 23,
                  color: isEarned ? t.amberInk : t.faint,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                badge.name,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: isEarned ? t.ink : t.muted,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _badgeIcon(Badge badge) {
    final criteria = badge.criteria;
    if (criteria.minStreak != null) return Icons.local_fire_department_outlined;
    if (criteria.examPassed != null) return Icons.workspace_premium_outlined;
    if (criteria.customKey != null) return Icons.auto_awesome_outlined;
    if (criteria.unitId != null) return Icons.flag_outlined;
    return Icons.military_tech_outlined;
  }
}
