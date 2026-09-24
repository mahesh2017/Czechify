import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/exercise.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/database_providers.dart';
import '../../widgets/common/lesson_ui.dart';
import '../../widgets/common/soft_ui.dart';

/// Each unit's model notebook page, keyed by unit id, from the bundled
/// cheat sheets (`notebook_page`). Units without one are absent.
final modelNotebookPagesProvider = FutureProvider<Map<int, Map<String, dynamic>>>(
  (ref) async {
    final raw = await rootBundle.loadString('assets/curriculum/cheat_sheets.json');
    final sheets =
        (jsonDecode(raw) as Map<String, dynamic>)['cheat_sheets'] as List? ??
        const [];
    return {
      for (final sheet in sheets)
        if (sheet is Map<String, dynamic> &&
            sheet['unit_id'] is int &&
            sheet['notebook_page'] is Map<String, dynamic>)
          sheet['unit_id'] as int:
              sheet['notebook_page'] as Map<String, dynamic>,
    };
  },
);

/// The unit's lecture steps in lesson order, read from the lessons themselves
/// so this screen can never show a different lecture from the one taught.
final unitLectureStepsProvider = FutureProvider.family<List<Exercise>, int>((
  ref,
  unitId,
) async {
  final repo = ref.read(curriculumRepositoryProvider);
  final lessons = await repo.getLessons(unitId);
  return [
    for (final lesson in lessons)
      for (final exercise in await repo.getExercises(lesson.id))
        if (exercise.type == ExerciseType.teaching &&
            exercise.data['style'] == 'lecture')
          exercise,
  ];
});

/// "Lecture & notebook" for one unit: the model page to check a paper
/// notebook against, and the unit's lecture steps to revise from.
///
/// Also how a learner who finished a unit before v1.2 gets its lecture and
/// page without replaying lessons they already completed.
class UnitNotebookScreen extends ConsumerStatefulWidget {
  final int unitId;

  const UnitNotebookScreen({super.key, required this.unitId});

  @override
  ConsumerState<UnitNotebookScreen> createState() => _UnitNotebookScreenState();
}

class _UnitNotebookScreenState extends ConsumerState<UnitNotebookScreen> {
  final _pageKey = GlobalKey();
  bool _sharing = false;

  /// Renders the model page to a PNG and hands it to the share sheet, where
  /// the learner can save it to their photos or print it.
  Future<void> _sharePage() async {
    final boundary =
        _pageKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _sharing) return;
    setState(() => _sharing = true);
    File? file;
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final directory = await getTemporaryDirectory();
      file = File('${directory.path}/czechify_unit_${widget.unitId}_page.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'image/png')]),
      );
    } catch (_) {
      // Sharing is optional; the page stays on screen either way.
    } finally {
      if (file != null && await file.exists()) await file.delete();
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final unlocked = ref.watch(unlockedUnitIdsProvider).asData?.value;
    final pages = ref.watch(modelNotebookPagesProvider).asData?.value;
    final lectures =
        ref.watch(unitLectureStepsProvider(widget.unitId)).asData?.value;
    // Same rule as the Grammar reference: a unit's material opens with the
    // unit, so a paid unit's page is not readable before it is unlocked.
    final locked = unlocked != null && !unlocked.contains(widget.unitId);
    final page = pages?[widget.unitId];

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        title: Text(l10n.unitNotebookTitle(widget.unitId)),
      ),
      body:
          locked
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.lessonLockedBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: t.muted),
                  ),
                ),
              )
              : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  LessonKicker(l10n.unitNotebookModelPage),
                  const SizedBox(height: 8),
                  if (page == null)
                    Text(
                      l10n.unitNotebookEmpty,
                      style: TextStyle(fontSize: 15, color: t.muted),
                    )
                  else ...[
                    RepaintBoundary(
                      key: _pageKey,
                      child: ModelNotebookPage(unitId: widget.unitId, page: page),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _sharing ? null : _sharePage,
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: Text(l10n.unitNotebookShare),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                  if (lectures != null && lectures.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    LessonKicker(l10n.unitNotebookLectures),
                    const SizedBox(height: 8),
                    for (final step in lectures)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LectureSummary(step: step),
                      ),
                  ],
                ],
              ),
    );
  }
}

/// A lecture step in brief: title, explanation and table.
class _LectureSummary extends StatelessWidget {
  final Exercise step;

  const _LectureSummary({required this.step});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final data = step.data;
    final say = (data['say'] as String?) ?? (data['body'] as String?) ?? '';
    return SoftCard(
      shadow: false,
      border: Border.all(color: t.line),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['heading'] as String? ?? step.prompt,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          if (say.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(say, style: TextStyle(fontSize: 15, height: 1.4, color: t.ink)),
          ],
          for (final row in (data['table'] as List? ?? const []))
            if (row is List && row.length >= 2)
              Text(
                '${row[0]}  →  ${row[1]}',
                style: TextStyle(fontSize: 15, height: 1.5, color: t.muted),
              ),
        ],
      ),
    );
  }
}

/// The model page, drawn like the learner's paper page so the two can be
/// compared side by side: header, words, pattern, my sentences, check.
class ModelNotebookPage extends StatelessWidget {
  final int unitId;
  final Map<String, dynamic> page;

  const ModelNotebookPage({super.key, required this.unitId, required this.page});

  static List<({String cz, String en})> _rows(Object? raw) => [
    for (final row in (raw as List? ?? const []))
      if (row is Map) (cz: '${row['cz'] ?? ''}', en: '${row['en'] ?? ''}'),
  ];

  static List<(String, String)> _pairs(Object? raw) => [
    for (final row in (raw as List? ?? const []))
      if (row is List && row.length >= 2) ('${row[0]}', '${row[1]}'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final canDo = page['can_do'];
    final pattern = page['pattern'] as Map<String, dynamic>? ?? const {};
    final aspect = pattern['aspect_pairs'] as Map<String, dynamic>?;
    final mistakes = [
      for (final key in ['common_mistake', 'second_mistake'])
        if (pattern[key] is Map) pattern[key] as Map,
    ];

    Widget box(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
              color: t.pri,
            ),
          ),
          Divider(color: t.line, height: 10),
          ...children,
        ],
      ),
    );
    Widget line(String text, {bool strong = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
          color: color ?? t.ink,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$unitId · ${page['title_cz'] ?? ''}',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          if (page['title_en'] != null)
            Text('${page['title_en']}', style: TextStyle(color: t.muted)),
          if (canDo is Map) ...[
            const SizedBox(height: 8),
            line('${l10n.modelPageCanDo}: ${canDo['cz'] ?? ''}', strong: true),
            if (canDo['en'] != null) line('${canDo['en']}', color: t.muted),
          ],
          box(l10n.modelPageWords, [
            for (final row in _rows(page['words']))
              line(row.en.isEmpty ? row.cz : '${row.cz} — ${row.en}'),
          ]),
          box(l10n.modelPagePattern, [
            if (pattern['rule_plain'] != null) line('${pattern['rule_plain']}'),
            const SizedBox(height: 4),
            for (final (a, b) in _pairs(pattern['table']))
              line('$a  →  $b', strong: true),
            for (final (a, b) in _pairs(pattern['irregular']))
              line('$a  →  $b'),
            if (aspect != null) ...[
              const SizedBox(height: 6),
              if (aspect['rule_plain'] != null) line('${aspect['rule_plain']}'),
              for (final (a, b) in _pairs(aspect['pairs']))
                line('$a / $b', strong: true),
              for (final row in _rows(aspect['examples']))
                line('${row.cz} — ${row.en}', color: t.muted),
            ],
            for (final row in _rows(pattern['examples']))
              line('${row.cz} — ${row.en}', color: t.muted),
            for (final mistake in mistakes) ...[
              line(
                '${l10n.lectureWrongLabel}: ${mistake['wrong']}',
                color: t.redInk,
              ),
              line(
                '${l10n.lectureRightLabel}: ${mistake['right']}',
                color: t.greenInk,
              ),
            ],
            if (pattern['preview'] != null)
              line('${pattern['preview']}', color: t.muted),
          ]),
          box(l10n.modelPageMySentences, [
            for (final row in _rows(page['my_sentences_models']))
              line('${row.cz} — ${row.en}', color: t.muted),
          ]),
          box(l10n.modelPageCheck, const []),
        ],
      ),
    );
  }
}
