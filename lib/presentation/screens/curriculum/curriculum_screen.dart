import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../providers/curriculum_providers.dart';
import '../../widgets/common/soft_ui.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/unit.dart';
import '../../../domain/entities/lesson.dart';

/// Curriculum — units for A1/A2 with progress and inline lessons.
///
/// The A1/A2 chips are real tabs. They used to be decorative — hardcoded
/// selected/unselected with no state behind them — so every unit rendered
/// under A1 and the A2 units were unreachable even though they exist.
class CurriculumScreen extends ConsumerStatefulWidget {
  const CurriculumScreen({super.key});

  @override
  ConsumerState<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends ConsumerState<CurriculumScreen> {
  Phase _phase = Phase.a1;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unitsAsync = ref.watch(allUnitsProvider);
    final unlockedIdsAsync = ref.watch(unlockedUnitIdsProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: unitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: t.red),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load curriculum: $err',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(allUnitsProvider),
                        child: Text(AppLocalizations.of(context).retry),
                      ),
                    ],
                  ),
                ),
              ),
          data: (units) {
            final a1Units = units.where((u) => u.phase == Phase.a1).toList();
            final a2Units = units.where((u) => u.phase == Phase.a2).toList();
            final unlockedIds = unlockedIdsAsync.maybeWhen(
              data: (ids) => ids,
              orElse: () => {a1Units.isNotEmpty ? a1Units.first.id : -1},
            );
            final shown = _phase == Phase.a1 ? a1Units : a2Units;
            final unlockedShown =
                shown.where((u) => unlockedIds.contains(u.id)).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const DisplayText('Curriculum', size: 26),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _LevelChip(
                      label: 'A1 · Beginner',
                      selected: _phase == Phase.a1,
                      onTap: () => setState(() => _phase = Phase.a1),
                    ),
                    const SizedBox(width: 8),
                    _LevelChip(
                      label: 'A2 · Elementary',
                      selected: _phase == Phase.a2,
                      onTap: () => setState(() => _phase = Phase.a2),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SoftProgressBar(
                        value: shown.isEmpty ? 0 : unlockedShown / shown.length,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$unlockedShown of ${shown.length} units',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Quick reference links
                Row(
                  children: [
                    _ReferenceChip(
                      icon: Icons.menu_book,
                      label: 'Grammar',
                      onTap: () => context.push('/grammar'),
                    ),
                    const SizedBox(width: 8),
                    _ReferenceChip(
                      icon: Icons.table_chart,
                      label: 'Declensions',
                      onTap: () => context.push('/reference/declension_tables'),
                    ),
                    const SizedBox(width: 8),
                    _ReferenceChip(
                      icon: Icons.format_list_bulleted,
                      label: 'Cheat Sheets',
                      onTap: () => context.push('/reference/cheat_sheets'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Lessons for this level are being added.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: t.muted),
                    ),
                  ),
                // Numbered by position within the level, not by unit id. The
                // A1 capstones carry ids 28 and 30 (16-27 are A2 units), so
                // using the id printed "Unit 28" directly under "Unit 15" and
                // read as a numbering bug.
                for (final (index, u) in shown.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UnitCard(
                      unit: u,
                      number: index + 1,
                      isUnlocked: unlockedIds.contains(u.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? t.priFill : t.chipBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? t.onFill : t.muted,
          ),
        ),
      ),
    );
  }
}

class _UnitCard extends ConsumerWidget {
  const _UnitCard({
    required this.unit,
    required this.number,
    required this.isUnlocked,
  });
  final Unit unit;

  /// Position within the level being shown — not [Unit.id]. See the comment
  /// where this is built.
  final int number;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final lessonsAsync = ref.watch(unitLessonsProvider(unit.id));
    final completedIds = ref
        .watch(completedLessonIdsProvider)
        .maybeWhen(data: (ids) => ids, orElse: () => const <int>{});
    final unlockedLessonIds = ref
        .watch(unlockedLessonIdsProvider)
        .maybeWhen(data: (ids) => ids, orElse: () => const <int>{});
    final lessons = lessonsAsync.value ?? const [];
    final doneCount = lessons.where((l) => completedIds.contains(l.id)).length;
    final allDone = lessons.isNotEmpty && doneCount == lessons.length;
    final inProgress = isUnlocked && !allDone;

    final statusColor =
        !isUnlocked
            ? t.faint
            : allDone
            ? t.green
            : t.pri;
    final statusIcon =
        !isUnlocked
            ? Icons.lock_outline
            : allDone
            ? Icons.check_circle
            : Icons.play_arrow_rounded;

    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: t.shadow,
        border: inProgress ? Border.all(color: t.pri, width: 1.5) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          listTileTheme: Theme.of(context).listTileTheme.copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          ),
        ),
        child: ExpansionTile(
          initiallyExpanded: inProgress,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isUnlocked ? t.priSoft : t.chipBg,
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, size: 18, color: statusColor),
          ),
          title: Text(
            'Unit $number · ${unit.title}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isUnlocked ? t.ink : t.muted,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: t.muted, height: 1.4),
                ),
                if (isUnlocked && lessons.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SoftProgressBar(
                          value: doneCount / lessons.length,
                          height: 5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$doneCount/${lessons.length}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          children: lessonsAsync.when(
            loading:
                () => const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
            error:
                (_, __) => [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No lessons available yet',
                      style: TextStyle(color: t.muted),
                    ),
                  ),
                ],
            data: (ls) {
              if (ls.isEmpty) {
                return [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No lessons available yet',
                      style: TextStyle(color: t.muted),
                    ),
                  ),
                ];
              }
              return <Widget>[
                ...ls.map(
                  (lesson) => _LessonTile(
                    lesson: lesson,
                    isUnlocked: unlockedLessonIds.contains(lesson.id),
                    isCompleted: completedIds.contains(lesson.id),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/grammar?unit=${unit.id}'),
                    icon: const Icon(Icons.menu_book, size: 16),
                    label: const Text('Grammar Rules'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ),
              ];
            },
          ),
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.isUnlocked,
    this.isCompleted = false,
  });

  final Lesson lesson;
  final bool isUnlocked;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (icon, tint, fg) = switch (lesson.lessonType) {
      LessonType.introduction => (Icons.info_outline, t.priSoft, t.pri),
      LessonType.practice => (Icons.graphic_eq, t.amberSoft, t.amber),
      LessonType.application => (Icons.spa_outlined, t.greenSoft, t.green),
      LessonType.review => (Icons.replay, t.violetSoft, t.violet),
    };
    final typeLabel = switch (lesson.lessonType) {
      LessonType.introduction => 'Lesson',
      LessonType.practice => 'Practice',
      LessonType.application => 'Apply',
      LessonType.review => 'Review',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: isUnlocked ? () => context.push('/lesson/${lesson.id}') : null,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            IconTile(
              icon: isCompleted ? Icons.check : icon,
              tint: isCompleted ? t.greenSoft : (isUnlocked ? tint : t.chipBg),
              fg: isCompleted ? t.green : (isUnlocked ? fg : t.faint),
              size: 32,
              radius: 11,
              iconSize: 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: isUnlocked ? t.ink : t.muted,
                    ),
                  ),
                  Text(
                    '$typeLabel · ${lesson.durationMinutes} min',
                    style: TextStyle(fontSize: 14, color: t.muted),
                  ),
                ],
              ),
            ),
            Icon(
              isUnlocked ? Icons.chevron_right : Icons.lock_outline,
              size: 15,
              color: t.faint,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ReferenceChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: t.chipBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: t.pri),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
