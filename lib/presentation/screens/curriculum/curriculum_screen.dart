import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../providers/curriculum_providers.dart';
import '../../widgets/common/soft_ui.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/unit.dart';
import '../../../domain/entities/lesson.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/common/motion_widgets.dart';
import '../../widgets/common/wash_background.dart';
import '../../models/curriculum_path_item.dart';
import '../../widgets/common/motion_async.dart';

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
  final _pathController = ScrollController();
  final _railController = ScrollController();

  /// One key per visible unit, so the rail can follow the scroll and scroll
  /// back to a unit when its chip is tapped.
  List<GlobalKey> _unitKeys = const [];
  final _listKey = GlobalKey();
  int _activeUnit = 0;
  bool _layoutChangedLive = false;
  bool _railHasMoved = false;
  Set<int>? _knownUnlockedIds;
  final Set<int> _liveUnlockedIds = {};

  @override
  void dispose() {
    _pathController.dispose();
    _railController.dispose();
    super.dispose();
  }

  void _syncUnitKeys(int count) {
    if (_unitKeys.length == count) return;
    _unitKeys = List.generate(count, (_) => GlobalKey());
  }

  /// Whichever unit has crossed the top of the list is the active one.
  /// Measured against the list's own box, not the screen, so the header and
  /// the rail always name the unit you are actually looking at. Only
  /// attached (built) units can be measured, which is exactly the set that
  /// could be on screen anyway.
  void _updateActiveUnit(int count) {
    final viewport = _listKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached) return;
    var active = 0;
    for (var i = 0; i < _unitKeys.length && i < count; i++) {
      final box = _unitKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final dy = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (dy <= 24) active = i;
    }
    if (active != _activeUnit) {
      setState(() {
        _activeUnit = active;
        _railHasMoved = true;
      });
      _centreChip(active);
    }
  }

  void _centreChip(int index) {
    if (!_railController.hasClients) return;
    // Chips are a fixed 30 wide with a 6 gap, after the two level chips.
    const chipExtent = 36.0;
    final target =
        (index * chipExtent) -
        _railController.position.viewportDimension / 2 +
        chipExtent;
    _railController.animateTo(
      target.clamp(0.0, _railController.position.maxScrollExtent),
      duration: context.motionDuration(AppMotion.content),
      curve: AppMotion.enter,
    );
  }

  Future<void> _jumpToUnit(int index) async {
    // The active unit is derived from the scroll position, not set here —
    // otherwise the header can claim a unit the scroll never reached.
    setState(() => _railHasMoved = true);
    _centreChip(index);
    final target = _unitKeys.length > index ? _unitKeys[index] : null;
    if (target == null) return;
    // A unit far down the list has not been built yet, so there is nothing to
    // scroll to. Land near it with an estimate first, then settle exactly.
    if (target.currentContext == null && _pathController.hasClients) {
      final position = _pathController.position;
      _pathController.jumpTo(
        (position.maxScrollExtent * index / _unitKeys.length).clamp(
          0.0,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    final settled = target.currentContext;
    // The key's own context is what we scroll to, and it is only non-null
    // while that unit is mounted — so it cannot be stale here.
    if (settled == null || !settled.mounted) return;
    await Scrollable.ensureVisible(
      settled,
      alignment: 0,
      duration: context.motionDuration(AppMotion.reveal),
      curve: AppMotion.enter,
    );
  }

  void _changeMapView(bool value) {
    setState(() => _layoutChangedLive = true);
    ref.read(settingsProvider.notifier).setCurriculumMapView(value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final pathAsync = ref.watch(curriculumPathItemsProvider);
    final unlockedIdsAsync = ref.watch(unlockedUnitIdsProvider);
    ref.listen(unlockedUnitIdsProvider, (_, next) {
      final ids = next.asData?.value;
      if (ids == null) return;
      final previous = _knownUnlockedIds;
      if (previous != null) {
        _liveUnlockedIds.addAll(ids.difference(previous));
      }
      _knownUnlockedIds = Set.of(ids);
    });
    final level = ref.watch(
      settingsProvider.select((settings) => settings.startingLevel),
    );
    final mapView = ref.watch(
      settingsProvider.select((settings) => settings.curriculumMapView),
    );

    return Scaffold(
      backgroundColor: t.bg,
      body: WashBackground(
        child: SafeArea(
          bottom: false,
          child: MotionAsync(
            value: pathAsync,
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
                        const Text(
                          "Couldn't load the curriculum. The app may need "
                          'an internet connection for the first download.',
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
            data: (items) {
              final a1Items =
                  items.where((item) => item.unit.phase == Phase.a1).toList();
              final a2Items =
                  items.where((item) => item.unit.phase == Phase.a2).toList();
              final unlockedIds = unlockedIdsAsync.maybeWhen(
                data: (ids) => ids,
                orElse: () => {a1Items.isNotEmpty ? a1Items.first.unit.id : -1},
              );
              // The rail is unit navigation, nothing else. It used to carry
              // A1/A2 chips in the same scrolling row as the unit numbers,
              // where two unrelated controls shared one shape and reading
              // "A1 A2 1 2 3" invited you to treat the levels as units. Level
              // now lives in Settings, which is also the only place it can be
              // changed for real — these chips only ever re-filtered the list
              // while the units underneath stayed locked.
              final phase = level == CEFRLevel.a2 ? Phase.a2 : Phase.a1;
              final shown = phase == Phase.a1 ? a1Items : a2Items;
              final currentIndex = shown.indexWhere(
                (item) => item.state.name == 'current',
              );
              final active =
                  shown.isEmpty
                      ? null
                      : shown[currentIndex < 0 ? 0 : currentIndex].unit;

              // The header names whichever unit the scroll is sitting in, in
              // that unit's own colour, so the rail below it and the cards
              // read as one thing.
              final activeIndex =
                  shown.isEmpty ? 0 : _activeUnit.clamp(0, shown.length - 1);
              final palette = _UnitPalette.of(t, activeIndex);
              _syncUnitKeys(shown.length);

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    decoration: BoxDecoration(
                      color: t.bg.withValues(alpha: .92),
                      border: Border(bottom: BorderSide(color: t.line)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  l10n.curriculumUnitOf(
                                    activeIndex + 1,
                                    shown.length,
                                    phase.name.toUpperCase(),
                                  ),
                                  style: TextStyle(
                                    color: palette.ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.9,
                                  ),
                                ),
                              ),
                            ),
                            _ViewToggle(
                              mapView: mapView,
                              onChanged: _changeMapView,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shown.isEmpty
                              ? (active?.title ?? l10n.curriculumPathTitle)
                              : shown[activeIndex].unit.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            color: t.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 11),
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            controller: _railController,
                            scrollDirection: Axis.horizontal,
                            itemCount: shown.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              return _UnitChip(
                                number: index + 1,
                                active: index == activeIndex,
                                unlocked: unlockedIds.contains(
                                  shown[index].unit.id,
                                ),
                                animateChange:
                                    _railHasMoved ||
                                    _liveUnlockedIds.contains(
                                      shown[index].unit.id,
                                    ),
                                onTap: () => _jumpToUnit(index),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    key: _listKey,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.axis == Axis.vertical) {
                          _updateActiveUnit(shown.length);
                        }
                        return false;
                      },
                      child: MotionEntrance(
                        key: ValueKey('curriculum-layout-$mapView'),
                        animateOnMount: _layoutChangedLive,
                        offset: Offset(mapView ? -.025 : .025, 0),
                        duration: AppMotion.content,
                        child: ListView(
                          controller: _pathController,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
                          children: [
                            if (shown.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                ),
                                child: Text(
                                  l10n.curriculumAddingLessons,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: t.muted,
                                  ),
                                ),
                              ),
                            // Numbered by position within the level, not by unit id. The
                            // A1 capstones carry ids 28 and 30 (16-27 are A2 units), so
                            // using the id printed "Unit 28" directly under "Unit 15" and
                            // read as a numbering bug.
                            if (mapView)
                              for (final (index, item) in shown.indexed) ...[
                                if (index == 0 ||
                                    shown[index - 1].section != item.section)
                                  _SectionHeader(item.section),
                                KeyedSubtree(
                                  key: _unitKeys[index],
                                  child: _PathUnit(
                                    unit: item.unit,
                                    number: index + 1,
                                    isUnlocked: unlockedIds.contains(
                                      item.unit.id,
                                    ),
                                    animateUnlock: _liveUnlockedIds.contains(
                                      item.unit.id,
                                    ),
                                    palette: _UnitPalette.of(t, index),
                                  ),
                                ),
                              ]
                            else
                              for (final (index, item) in shown.indexed) ...[
                                if (index == 0 ||
                                    shown[index - 1].section != item.section)
                                  _SectionHeader(item.section),
                                KeyedSubtree(
                                  key: _unitKeys[index],
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _UnitCard(
                                      unit: item.unit,
                                      number: index + 1,
                                      isUnlocked: unlockedIds.contains(
                                        item.unit.id,
                                      ),
                                      animateUnlock: _liveUnlockedIds.contains(
                                        item.unit.id,
                                      ),
                                      palette: _UnitPalette.of(t, index),
                                    ),
                                  ),
                                ),
                              ],
                            const SizedBox(height: 8),
                            // Finishing A1 used to end in a sentence saying A2
                            // opens, with nothing to open it. The level lives in
                            // Settings, and a learner who has just finished a
                            // level is not going to go looking there — so the
                            // moment they finish is the moment we offer it.
                            if (phase == Phase.a1 &&
                                shown.isNotEmpty &&
                                shown.every(
                                  (item) =>
                                      item.state ==
                                      CurriculumPathState.completed,
                                ))
                              _NextLevelPrompt(
                                onTap: () => context.push('/settings'),
                              )
                            else
                              Text(
                                phase == Phase.a1
                                    ? l10n.curriculumA1Complete
                                    : l10n.curriculumA2Complete,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: t.muted,
                                  fontSize: 14,
                                  height: 1.5,
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
          ),
        ),
      ),
    );
  }
}

/// The five-hue rotation the design runs down the path so consecutive units
/// stay distinguishable. Index is the unit's position in the level.
class _UnitPalette {
  const _UnitPalette(this.color, this.soft, this.ink);

  final Color color;
  final Color soft;
  final Color ink;

  static _UnitPalette of(AppTokens t, int index) => switch (index % 5) {
    0 => _UnitPalette(t.pri, t.priSoft, t.priInk),
    1 => _UnitPalette(t.violet, t.violetSoft, t.violetInk),
    2 => _UnitPalette(t.green, t.greenSoft, t.greenInk),
    3 => _UnitPalette(t.amber, t.amberSoft, t.amberInk),
    _ => _UnitPalette(t.red, t.redSoft, t.redInk),
  };
}

/// A numbered square in the unit rail. Drawn small on purpose; the tap target
/// is grown around it rather than the square.
class _UnitChip extends StatelessWidget {
  const _UnitChip({
    required this.number,
    required this.active,
    required this.unlocked,
    required this.animateChange,
    required this.onTap,
  });

  final int number;
  final bool active;
  final bool unlocked;
  final bool animateChange;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: active,
      label: AppLocalizations.of(context).curriculumUnit(number),
      child: SizedBox(
        width: 44,
        height: 44,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration:
                  animateChange
                      ? context.motionDuration(AppMotion.selection)
                      : Duration.zero,
              curve: AppMotion.enter,
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    active
                        ? t.pri
                        : unlocked
                        ? t.priSoft
                        : t.elev,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  color:
                      active
                          ? t.onFill
                          : unlocked
                          ? t.pri
                          : t.faint,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: context.tokens.muted,
      ),
    ),
  );
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.mapView, required this.onChanged});

  final bool mapView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: 'Curriculum layout',
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: t.elev,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ViewToggleButton(
              label: AppLocalizations.of(context).curriculumMap,
              selected: mapView,
              onTap: () => onChanged(true),
            ),
            _ViewToggleButton(
              label: AppLocalizations.of(context).curriculumList,
              selected: !mapView,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
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
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: context.motionDuration(AppMotion.selection),
          curve: AppMotion.enter,
          // Drawn small, as the comp does, with the 44pt target coming from
          // the opaque hit region around it rather than from the pill.
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? t.card : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? t.ink : t.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// A unit in the map view: a header card carrying the unit's identity, and
/// beneath it — outside the card — the lessons threaded on a rail.
class _PathUnit extends ConsumerWidget {
  const _PathUnit({
    required this.unit,
    required this.number,
    required this.isUnlocked,
    required this.animateUnlock,
    required this.palette,
  });

  final Unit unit;
  final int number;
  final bool isUnlocked;
  final bool animateUnlock;
  final _UnitPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final lessons = ref.watch(unitLessonsProvider(unit.id)).value ?? const [];
    final completedIds = ref
        .watch(completedLessonIdsProvider)
        .maybeWhen(data: (ids) => ids, orElse: () => const <int>{});
    final unlockedLessonIds = ref
        .watch(unlockedLessonIdsProvider)
        .maybeWhen(data: (ids) => ids, orElse: () => const <int>{});
    final doneCount = lessons.where((l) => completedIds.contains(l.id)).length;
    final allDone = lessons.isNotEmpty && doneCount == lessons.length;
    final inProgress = isUnlocked && !allDone;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration:
                animateUnlock
                    ? context.motionDuration(AppMotion.content)
                    : Duration.zero,
            curve: AppMotion.enter,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              // A unit you are in is a plain card; the ones ahead are washed
              // in their own hue so the path reads as a sequence.
              gradient:
                  isUnlocked
                      ? null
                      : LinearGradient(
                        begin: const Alignment(-0.7, -1),
                        end: const Alignment(0.7, 1),
                        colors: [
                          Color.lerp(palette.color, t.card, .74)!,
                          Color.lerp(palette.color, t.card, .90)!,
                        ],
                      ),
              color: isUnlocked ? t.card : null,
              border: Border.all(
                color: palette.color.withValues(alpha: isUnlocked ? .28 : .20),
                width: isUnlocked ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.color.withValues(
                    alpha: isUnlocked ? .52 : .60,
                  ),
                  blurRadius: isUnlocked ? 46 : 34,
                  spreadRadius: isUnlocked ? -26 : -28,
                  offset: Offset(0, isUnlocked ? 26 : 18),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 10,
                  top: -22,
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 108,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: palette.color.withValues(alpha: .18),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.curriculumUnit(number).toUpperCase(),
                            style: TextStyle(
                              color: palette.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.9,
                            ),
                          ),
                          if (inProgress) ...[
                            const SizedBox(width: 9),
                            Container(
                              padding: const EdgeInsets.fromLTRB(9, 3, 9, 3),
                              decoration: BoxDecoration(
                                color: t.pri,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                l10n.curriculumInProgress.toUpperCase(),
                                style: TextStyle(
                                  color: t.onFill,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                          ] else if (!isUnlocked && number > 1) ...[
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                '· ${l10n.curriculumUnlocksAfter(number - 1)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: t.faint,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        unit.title,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unit.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: t.muted,
                          height: 1.4,
                        ),
                      ),
                      if (inProgress && lessons.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: SoftProgressBar(
                                value: doneCount / lessons.length,
                                height: 6,
                                color: palette.color,
                                track: palette.color.withValues(alpha: .14),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Text(
                              l10n.curriculumLessonCount(
                                doneCount,
                                lessons.length,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: palette.ink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (lessons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 16, 0, 0),
              child: Stack(
                children: [
                  // The rail thread the lesson nodes hang on.
                  Positioned(
                    left: 27,
                    top: 18,
                    bottom: 18,
                    child: Container(width: 2, color: t.line),
                  ),
                  Column(
                    children: [
                      for (final lesson in lessons)
                        _PathLessonRow(
                          lesson: lesson,
                          color: palette.color,
                          isUnlocked: unlockedLessonIds.contains(lesson.id),
                          isCompleted: completedIds.contains(lesson.id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One lesson on the rail: a node, the label, and what it costs you.
class _PathLessonRow extends StatelessWidget {
  const _PathLessonRow({
    required this.lesson,
    required this.color,
    required this.isUnlocked,
    required this.isCompleted,
  });

  final Lesson lesson;
  final Color color;
  final bool isUnlocked;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final isCurrent = isUnlocked && !isCompleted;
    final typeLabel = switch (lesson.lessonType) {
      LessonType.introduction => l10n.lessonTypeLesson,
      LessonType.practice || LessonType.listening => l10n.lessonTypePractice,
      LessonType.application ||
      LessonType.production ||
      LessonType.mission => l10n.lessonTypeApply,
      LessonType.review => l10n.lessonTypeReview,
    };
    final state =
        isCompleted
            ? l10n.curriculumStateDone
            : isCurrent
            ? l10n.curriculumStateReady
            : l10n.curriculumStateLocked;

    return Semantics(
      button: true,
      enabled: isUnlocked,
      child: InkWell(
        onTap: isUnlocked ? () => context.push('/lesson/${lesson.id}') : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked ? color : t.card,
                  border: Border.all(color: isUnlocked ? color : t.line),
                  boxShadow:
                      isUnlocked
                          // A ring of page colour so the node reads as sitting
                          // on the rail rather than being crossed by it.
                          ? [BoxShadow(color: t.bg, spreadRadius: 3)]
                          : null,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_rounded
                      : isCurrent
                      ? Icons.play_arrow_rounded
                      : Icons.lock_outline_rounded,
                  size: isCompleted ? 22 : 20,
                  color: isUnlocked ? t.onFill : t.muted,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            lesson.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isUnlocked ? t.ink : t.muted,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.fromLTRB(9, 3, 9, 3),
                            decoration: BoxDecoration(
                              color: t.pri,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.curriculumNextUp.toUpperCase(),
                              style: TextStyle(
                                color: t.onFill,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$typeLabel · ${lesson.durationMinutes} min · $state',
                      style: TextStyle(
                        fontSize: 13,
                        color: t.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isUnlocked ? Icons.chevron_right : Icons.lock_outline_rounded,
                size: 18,
                color: t.faint,
              ),
            ],
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
    required this.animateUnlock,
    required this.palette,
  });
  final Unit unit;

  /// Position within the level being shown — not [Unit.id]. See the comment
  /// where this is built.
  final int number;
  final bool isUnlocked;
  final bool animateUnlock;
  final _UnitPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
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

    final statusIcon =
        !isUnlocked
            ? Icons.lock_outline
            : allDone
            ? Icons.check_circle
            : Icons.play_arrow_rounded;

    return AnimatedContainer(
      duration:
          animateUnlock
              ? context.motionDuration(AppMotion.content)
              : Duration.zero,
      curve: AppMotion.enter,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette.color.withValues(alpha: .5),
            blurRadius: 40,
            spreadRadius: -26,
            offset: const Offset(0, 22),
          ),
        ],
        border: Border.all(
          color: palette.color.withValues(alpha: inProgress ? .28 : .18),
          width: inProgress ? 1.5 : 1,
        ),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isUnlocked ? palette.color : t.card,
              shape: BoxShape.circle,
              border: Border.all(color: isUnlocked ? palette.color : t.line),
            ),
            child: Icon(
              statusIcon,
              size: 20,
              color: isUnlocked ? t.onFill : t.muted,
            ),
          ),
          title: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -4,
                top: -24,
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: palette.color.withValues(alpha: .18),
                    fontFamily: AppFonts.display,
                    fontSize: 78,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.curriculumUnit(number),
                          style: TextStyle(
                            color: palette.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.7,
                          ),
                        ),
                        if (inProgress) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: t.pri,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.curriculumInProgress,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      unit.title,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isUnlocked ? t.ink : t.muted,
                        height: 1.18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                          height: 6,
                          color: palette.color,
                          track: palette.color.withValues(alpha: .14),
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
      LessonType.practice ||
      LessonType.listening => (Icons.graphic_eq, t.amberSoft, t.amber),
      LessonType.application ||
      LessonType.production => (Icons.spa_outlined, t.greenSoft, t.green),
      LessonType.mission => (Icons.flag_outlined, t.violetSoft, t.violet),
      LessonType.review => (Icons.replay, t.violetSoft, t.violet),
    };
    final typeLabel = switch (lesson.lessonType) {
      LessonType.introduction => 'Lesson',
      LessonType.practice => 'Practice',
      LessonType.listening => 'Listening',
      LessonType.application => 'Apply',
      LessonType.production => 'Produce',
      LessonType.mission => 'Mission',
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

/// Offered at the end of A1 once every unit is complete.
///
/// Points at Settings rather than switching level itself, so there is one
/// place that changes level and one place to look for it afterwards. A second
/// control here would be the more obvious design and the worse one: a learner
/// who used it would have no idea where to undo it.
class _NextLevelPrompt extends StatelessWidget {
  const _NextLevelPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: BoxDecoration(
          color: t.priSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.pri.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'That is all of A1. Ready for A2?',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      color: t.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Change your level in Settings. Everything you have '
                    'finished stays open.',
                    style: TextStyle(
                      color: t.muted,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.pri),
          ],
        ),
      ),
    );
  }
}
