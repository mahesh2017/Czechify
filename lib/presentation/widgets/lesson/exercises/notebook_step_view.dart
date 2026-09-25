import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/unit_guide_pilot.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../data/services/notebook_store.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/notebook_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../common/lesson_ui.dart';
import '../../common/soft_ui.dart';
import 'exercise_shared.dart';

/// A notebook step: the learner writes part of their unit page from memory,
/// then compares it with the model and marks how it went.
///
/// The order is the point. Writing first and checking after is retrieval;
/// reading the model first would make it copying, which does far less. So the
/// model stays hidden until the learner asks for it.
///
/// Never blocks the lesson (plan v1.2, decision 2): on paper, "No pen right
/// now" puts the step on the notebook to-do and moves on. With notes set to
/// "in the app", the same task is typed into a box instead — for a learner
/// with no paper to hand or who cannot write by hand.
///
/// Content: a `teaching` exercise with `data.style == "notebook"`, a `kind`
/// (`setup`, `capture`, `recall`, `my_sentences`, `unit_check`), a `heading`,
/// an `instruction` and the model as `items` (`cz`/`en` rows). An app that
/// predates this view shows the same card as an ordinary teaching list.
class NotebookStepView extends ConsumerStatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const NotebookStepView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  ConsumerState<NotebookStepView> createState() => _NotebookStepViewState();
}

class _NotebookStepViewState extends ConsumerState<NotebookStepView> {
  /// Set once the learner has seen what the notebook is for. A learner who
  /// starts partway through the course meets it on whichever notebook step
  /// comes first, not only in Unit 1.
  static const introSeenKey = 'notebook_intro_seen';

  final _notes = TextEditingController();
  bool _revealed = false;
  bool _closing = false;
  bool _showIntro = false;

  @override
  void initState() {
    super.initState();
    _checkIntro();
  }

  Future<void> _checkIntro() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(introSeenKey) ?? false) return;
      if (mounted) setState(() => _showIntro = true);
      await prefs.setBool(introSeenKey, true);
    } catch (_) {
      // Only an introduction; the step works without it.
    }
  }

  Map<String, dynamic> get _data => widget.exercise.data;
  String get _kind => _data['kind'] as String? ?? 'capture';
  String get _heading =>
      _data['heading'] as String? ?? widget.exercise.prompt;
  String get _instruction =>
      (_data['instruction'] as String?) ?? (_data['body'] as String?) ?? '';

  List<({String cz, String en})> get _model => [
    for (final row in (_data['items'] as List? ?? const []))
      if (row is Map && '${row['cz'] ?? ''}'.trim().isNotEmpty)
        (cz: '${row['cz']}', en: '${row['en'] ?? ''}'),
  ];

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _close(NotebookOutcome? outcome) async {
    if (_closing) return;
    setState(() => _closing = true);
    final store = ref.read(notebookStoreProvider);
    try {
      if (outcome == NotebookOutcome.deferred) {
        await store.defer(
          NotebookTodo(
            exerciseId: widget.exercise.id,
            lessonId: widget.exercise.lessonId,
            heading: _heading,
            instruction: _instruction,
            model: _model,
            deferredAt: DateTime.now(),
          ),
        );
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).notebookDeferred),
            ),
          );
        }
      } else if (outcome != null) {
        await store.record(widget.exercise.id, outcome);
      }
      ref.invalidate(notebookTodoProvider);
    } catch (_) {
      // The record is a convenience; failing to save it must not trap the
      // learner on this card.
    }
    widget.onAnswered(const ExerciseResult.skipped());
  }

  /// Pilot: whether this step runs as screens — the one-time intro on its
  /// own, then the task, then the comparison in the task's place — so the
  /// model and its buttons never land under the task on a small phone.
  bool get _screens => unitGuideEnabled(unitOfLesson(widget.exercise.lessonId));

  /// Pilot: the learner has read the one-time intro screen.
  bool _introDone = false;

  Widget _introScreen(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeachingHeroCard(
            accent: t.violet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_rounded, size: 28, color: t.violet),
                const SizedBox(height: 10),
                DisplayText(
                  l10n.notebookIntroTitle,
                  size: 24,
                  weight: FontWeight.w800,
                  height: 1.15,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.notebookIntroBody,
                  style: TextStyle(fontSize: 17, height: 1.45, color: t.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          KeyCta(
            label: l10n.continueLabel,
            onPressed: () => setState(() => _introDone = true),
          ),
        ],
      ),
    );
  }

  /// Pilot: after "Check against the model", the comparison replaces the task:
  /// what the task was (one line), what the learner typed if they typed it,
  /// the model, and how it went.
  Widget _compareScreen(BuildContext context, {required bool onPaper}) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final unitId =
        _kind == 'unit_check' ? unitOfLesson(widget.exercise.lessonId) : null;
    final typed = _notes.text.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 20, color: t.violet),
              const SizedBox(width: 6),
              Flexible(child: LessonKicker(_heading, color: t.violet)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DisplayText(
                  l10n.notebookCompareTitle,
                  size: 24,
                  weight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              // The whole model page, from the unit's closing check: an icon
              // beside the title rather than a line of its own.
              if (unitGuideEnabled(unitId))
                IconButton(
                  key: const ValueKey('notebook-model-page'),
                  tooltip: l10n.notebookSeeModelPage,
                  onPressed:
                      () =>
                          context.push('/unit-guide/$unitId?section=notebook'),
                  icon: Icon(Icons.menu_book_rounded, color: t.pri),
                ),
            ],
          ),
          if (!onPaper && typed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.elev,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LessonKicker(l10n.notebookYouWrote),
                  const SizedBox(height: 4),
                  Text(
                    typed,
                    style: TextStyle(fontSize: 16, height: 1.4, color: t.ink),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          LessonKicker(l10n.notebookModelTitle),
          const SizedBox(height: 8),
          _ModelCard(rows: _model),
          const SizedBox(height: 12),
          // Side by side: stacked, the two answers took the room the
          // learner's own notes need beside the model.
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _closing
                          ? null
                          : () => _close(NotebookOutcome.corrected),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    l10n.notebookCorrected,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KeyCta(
                  label: l10n.notebookAllCorrect,
                  onPressed:
                      _closing
                          ? null
                          : () => _close(NotebookOutcome.allCorrect),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final onPaper = ref.watch(settingsProvider).notesOnPaper;
    if (_screens) {
      if (_showIntro && !_introDone) return _introScreen(context);
      if (_revealed) return _compareScreen(context, onPaper: onPaper);
    }
    // Only the unit's closing check links to the unit guide.
    final unitId =
        _kind == 'unit_check' ? unitOfLesson(widget.exercise.lessonId) : null;
    final setup = _kind == 'setup';
    final model = _model;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showIntro && !_screens) ...[
            SoftCard(
              shadow: false,
              color: t.violetSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.notebookIntroTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.notebookIntroBody,
                    style: TextStyle(fontSize: 15, height: 1.4, color: t.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          TeachingHeroCard(
            accent: t.violet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded, size: 20, color: t.violet),
                    const SizedBox(width: 6),
                    LessonKicker(l10n.notebookKicker, color: t.violet),
                  ],
                ),
                const SizedBox(height: 12),
                DisplayText(
                  _heading,
                  size: 24,
                  weight: FontWeight.w800,
                  height: 1.15,
                ),
                if (_instruction.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _instruction,
                    style: TextStyle(fontSize: 17, height: 1.45, color: t.ink),
                  ),
                ],
                if (!setup) ...[
                  const SizedBox(height: 12),
                  Text(
                    onPaper
                        ? l10n.notebookPaperInstruction
                        : l10n.notebookTypedInstruction,
                    style: TextStyle(fontSize: 14, color: t.muted),
                  ),
                ],
              ],
            ),
          ),
          if (setup) ...[
            // The setup card shows the page layout, not a model to check.
            if (model.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ModelCard(rows: model),
            ],
            const SizedBox(height: 22),
            KeyCta(
              label: l10n.continueLabel,
              onPressed: _closing ? null : () => _close(null),
            ),
          ] else ...[
            if (!onPaper) ...[
              const SizedBox(height: 16),
              AnswerField(
                controller: _notes,
                multiline: true,
                enabled: !_revealed,
                hint: l10n.notebookTypedLabel,
                semanticLabel: l10n.notebookTypedLabel,
              ),
            ],
            if (_revealed) ...[
              const SizedBox(height: 16),
              LessonKicker(l10n.notebookModelTitle),
              const SizedBox(height: 8),
              _ModelCard(rows: model),
              if (unitGuideEnabled(unitId))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        () => context.push(
                          '/unit-guide/$unitId?section=notebook',
                        ),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: Text(l10n.notebookSeeModelPage),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              KeyCta(
                label: l10n.notebookAllCorrect,
                onPressed:
                    _closing
                        ? null
                        : () => _close(NotebookOutcome.allCorrect),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed:
                    _closing ? null : () => _close(NotebookOutcome.corrected),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(l10n.notebookCorrected),
              ),
            ] else ...[
              const SizedBox(height: 22),
              KeyCta(
                label: l10n.notebookShowModel,
                onPressed:
                    model.isEmpty
                        // Nothing to compare with: treat as written.
                        ? () => _close(NotebookOutcome.allCorrect)
                        : () => setState(() => _revealed = true),
              ),
              if (onPaper) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed:
                      _closing ? null : () => _close(NotebookOutcome.deferred),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(l10n.notebookNoPen),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

/// The model rows: Czech first, English under it, tap the speaker to hear it.
class _ModelCard extends StatelessWidget {
  final List<({String cz, String en})> rows;

  const _ModelCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SoftCard(
      shadow: false,
      border: Border.all(color: t.line),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.cz,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                        if (row.en.isNotEmpty)
                          Text(
                            row.en,
                            style: TextStyle(fontSize: 14, color: t.muted),
                          ),
                      ],
                    ),
                  ),
                  // "káva → kávu" should be heard as two words, not the arrow.
                  TtsButton(
                    text: row.cz.replaceAll(RegExp(r'\s*→\s*'), ', '),
                    size: 20,
                    color: t.pri,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
