import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/lesson_ids.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/lesson.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/tts_providers.dart';
import '../../widgets/common/lesson_ui.dart';
import '../../widgets/common/soft_ui.dart';
import '../../widgets/lesson/exercises/teaching_view.dart';
import 'unit_notebook_screen.dart';

export '../../../core/config/lesson_ids.dart';

/// The unit's own checklist: the items of its closing "Check your page" step.
final unitCheckItemsProvider =
    FutureProvider.family<List<({String cz, String en})>, int>((
      ref,
      unitId,
    ) async {
      final repo = ref.read(curriculumRepositoryProvider);
      for (final lesson in await repo.getLessons(unitId)) {
        for (final exercise in await repo.getExercises(lesson.id)) {
          final data = exercise.data;
          if (exercise.type == ExerciseType.teaching &&
              data['style'] == 'notebook' &&
              data['kind'] == 'unit_check') {
            return [
              for (final row in (data['items'] as List? ?? const []))
                if (row is Map) (cz: '${row['cz'] ?? ''}', en: '${row['en'] ?? ''}'),
            ];
          }
        }
      }
      return const [];
    });

/// Everything a unit teaches, in the order a learner looks for it: what the
/// unit is for, the grammar (the lesson's own lecture cards, by lesson), the
/// key phrases, and — last, collapsed — the model notebook page to compare a
/// paper page with.
class UnitGuideScreen extends ConsumerStatefulWidget {
  final int unitId;

  /// Opens with the notebook page expanded and in view, as the unit's
  /// "Check your page" step asks.
  final bool openNotebook;

  const UnitGuideScreen({
    super.key,
    required this.unitId,
    this.openNotebook = false,
  });

  @override
  ConsumerState<UnitGuideScreen> createState() => _UnitGuideScreenState();
}

class _UnitGuideScreenState extends ConsumerState<UnitGuideScreen> {
  final _pageKey = GlobalKey();
  final _notebookKey = GlobalKey();
  late bool _notebookOpen = widget.openNotebook;

  /// Every section starts closed, so the guide opens as one screen of
  /// headings (Mahesh, 25 Sep 2026); the closing check's link still opens the
  /// notebook page.
  bool _phrasesOpen = false;
  bool _scrolledToNotebook = false;
  bool _sharing = false;
  Set<int> _checked = {};

  String get _checkKey => 'unit_guide_checked_${widget.unitId}';

  @override
  void initState() {
    super.initState();
    _loadChecked();
  }

  Future<void> _loadChecked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_checkKey) ?? const [];
      if (mounted) setState(() => _checked = {...saved.map(int.parse)});
    } catch (_) {
      // Ticks are a convenience; the list works unticked.
    }
  }

  Future<void> _toggle(int index) async {
    setState(() {
      _checked.contains(index) ? _checked.remove(index) : _checked.add(index);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_checkKey, [
        for (final i in _checked) '$i',
      ]);
    } catch (_) {}
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    await shareModelPage(_pageKey, widget.unitId);
    if (mounted) setState(() => _sharing = false);
  }

  void _scrollToNotebookOnce() {
    if (!widget.openNotebook || _scrolledToNotebook) return;
    _scrolledToNotebook = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _notebookKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final unlocked = ref.watch(unlockedUnitIdsProvider).asData?.value;
    final pages = ref.watch(modelNotebookPagesProvider).asData?.value;
    final page = pages == null ? null : pages[widget.unitId];
    final lessons = ref.watch(unitLessonsProvider(widget.unitId)).asData?.value;
    final lectures =
        ref.watch(unitLectureStepsProvider(widget.unitId)).asData?.value;
    final checklist =
        ref.watch(unitCheckItemsProvider(widget.unitId)).asData?.value ??
        const [];
    final completed =
        ref.watch(completedLessonIdsProvider).asData?.value ?? const <int>{};
    final locked = unlocked != null && !unlocked.contains(widget.unitId);

    Widget body;
    if (locked) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.lessonLockedBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: t.ink),
          ),
        ),
      );
    } else if (lessons == null || lectures == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      _scrollToNotebookOnce();
      final ordered = [...lessons]
        ..sort((a, b) => a.orderInUnit.compareTo(b.orderInUnit));
      // The lesson the learner is on: the first one not yet completed.
      final current = ordered.firstWhere(
        (l) => !completed.contains(l.id),
        orElse: () => ordered.last,
      );
      bool reached(Lesson l) =>
          completed.contains(l.id) || l.orderInUnit <= current.orderInUnit;
      final byLesson = {for (final l in ordered) l.id: l};
      final taughtIn = <Lesson, List<Exercise>>{};
      for (final lecture in lectures) {
        final lesson = byLesson[lecture.lessonId];
        if (lesson != null) (taughtIn[lesson] ??= []).add(lecture);
      }
      final canDo = page?['can_do'];
      final goal =
          canDo is Map && canDo['en'] is String ? canDo['en'] as String : null;
      final phrases = [
        for (final row in (page?['words'] as List? ?? const []))
          if (row is Map) (cz: '${row['cz'] ?? ''}', en: '${row['en'] ?? ''}'),
      ];

      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (goal != null) ...[
            SoftCard(
              shadow: false,
              color: t.priSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LessonKicker(l10n.unitGuideGoal, color: t.pri),
                  const SizedBox(height: 6),
                  Text(
                    goal,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
          if (taughtIn.isNotEmpty) ...[
            LessonKicker(l10n.unitGuideGrammar),
            const SizedBox(height: 8),
            for (final entry in taughtIn.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.unitGuideLesson(
                        lessonLetter(entry.key.orderInUnit),
                        entry.key.title,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    // Said once for the lesson, not on every rule in it. The
                    // rules still open: the label guards against overwhelm,
                    // not against curiosity.
                    if (!reached(entry.key))
                      Text(
                        l10n.unitGuideNotReached,
                        style: TextStyle(fontSize: 13, color: t.ink),
                      ),
                  ],
                ),
              ),
              for (final lecture in entry.value)
                _LectureTile(lecture: lecture, initiallyOpen: false),
            ],
            const SizedBox(height: 18),
          ],
          if (phrases.isNotEmpty) ...[
            _GuideSection(
              open: _phrasesOpen,
              onToggle: () => setState(() => _phrasesOpen = !_phrasesOpen),
              icon: Icons.record_voice_over_outlined,
              title: l10n.unitGuidePhrases,
              hint: l10n.unitGuidePhrasesCount(phrases.length),
              child: SoftCard(
                shadow: false,
                border: Border.all(color: t.line),
                child: Column(
                  children: [
                    for (final p in phrases)
                      _PhraseLine(cz: p.cz, en: p.en),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (page != null)
            _GuideSection(
              key: _notebookKey,
              open: _notebookOpen,
              onToggle: () => setState(() => _notebookOpen = !_notebookOpen),
              icon: Icons.edit_note,
              title: l10n.unitGuideNotebook,
              hint: l10n.unitGuideNotebookHint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RepaintBoundary(
                    key: _pageKey,
                    child: ModelNotebookPage(
                      unitId: widget.unitId,
                      page: page,
                      guideLabels: true,
                    ),
                  ),
                  if (checklist.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    LessonKicker(l10n.unitGuideChecklist),
                    const SizedBox(height: 4),
                    for (var i = 0; i < checklist.length; i++)
                      CheckboxListTile(
                        value: _checked.contains(i),
                        onChanged: (_) => _toggle(i),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          checklist[i].cz,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: t.ink,
                          ),
                        ),
                        subtitle:
                            checklist[i].en.isEmpty
                                ? null
                                : Text(
                                  checklist[i].en,
                                  style: TextStyle(fontSize: 14, color: t.ink),
                                ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _sharing ? null : _share,
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(l10n.unitGuideSave),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        title: Text(l10n.unitGuideTitle(ref.watch(unitNumberInLevelProvider(widget.unitId)))),
      ),
      body: body,
    );
  }
}

/// One rule, shown as its heading until opened; opened, it is the lesson's
/// own lecture card under that heading.
class _LectureTile extends StatefulWidget {
  final Exercise lecture;
  final bool initiallyOpen;

  const _LectureTile({required this.lecture, required this.initiallyOpen});

  @override
  State<_LectureTile> createState() => _LectureTileState();
}

class _LectureTileState extends State<_LectureTile> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final heading =
        widget.lecture.data['heading'] as String? ?? widget.lecture.prompt;
    final header = InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                heading,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _open ? t.priInk : t.ink,
                ),
              ),
            ),
            Icon(
              _open ? Icons.expand_less : Icons.expand_more,
              color: t.pri,
            ),
          ],
        ),
      ),
    );
    // Closed, the rule is a card to tap. Open, it is not a card around the
    // lecture's own cards — explanation, table, examples — which sat 2 pt
    // inside its outline as boxes in a box. The heading becomes a plain
    // header and the lecture's cards sit on the page at full width.
    if (!_open) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(
          shadow: false,
          border: Border.all(color: t.line),
          padding: EdgeInsets.zero,
          child: header,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SoftCard(
            shadow: false,
            color: t.priSoft,
            border: Border.all(color: t.pri.withValues(alpha: .4)),
            padding: EdgeInsets.zero,
            child: header,
          ),
          const SizedBox(height: 12),
          LectureContent(exercise: widget.lecture, showHeading: false),
        ],
      ),
    );
  }
}

class _PhraseLine extends ConsumerWidget {
  final String cz;
  final String en;

  const _PhraseLine({required this.cz, required this.en});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cz,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                if (en.isNotEmpty)
                  Text(en, style: TextStyle(fontSize: 14, color: t.ink)),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context).listen,
          icon: Icon(Icons.volume_up_outlined, color: t.pri),
          onPressed: () async {
            try {
              await ref.read(czechTtsProvider).speak(cz);
            } catch (_) {}
          },
        ),
      ],
    );
  }
}

/// The notebook page, collapsed by default: what it is for in one line, then
/// the model page, the checklist and "save as image" once opened.
/// A section of the guide that opens on tap: the notebook page and the key
/// phrases. Closed, the guide is one screen of headings to choose from.
class _GuideSection extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final IconData icon;
  final String title;
  final String hint;
  final Widget child;

  const _GuideSection({
    super.key,
    required this.open,
    required this.onToggle,
    required this.icon,
    required this.title,
    required this.hint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(
          shadow: false,
          border: Border.all(color: t.line),
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Icon(icon, color: t.pri),
                  const SizedBox(width: 10),
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
                        const SizedBox(height: 2),
                        Text(
                          hint,
                          style: TextStyle(fontSize: 14, color: t.ink),
                        ),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: t.pri),
                ],
              ),
            ),
          ),
        ),
        if (open) ...[const SizedBox(height: 12), child],
      ],
    );
  }
}
