import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../widgets/lesson/exercises/exercise_shared.dart';
import '../../widgets/common/soft_ui.dart';
import '../../widgets/common/lesson_ui.dart';
import '../../../domain/engines/placement_engine.dart';
import '../../../domain/entities/learning_evidence.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/tts_providers.dart';

class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key, this.returnToOnboarding = false});

  final bool returnToOnboarding;

  @override
  ConsumerState<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends ConsumerState<PlacementScreen> {
  static const _engine = PlacementEngine();
  static const _tasks = <_PlacementTask>[
    _PlacementTask('r1', LearningSkill.reading, .2, '“Jsem doma.” means…', [
      'I am at home',
      'I have a house',
      'I go home',
    ], 0),
    _PlacementTask(
      'r2',
      LearningSkill.reading,
      .45,
      '“Lékárna je naproti poště.” Where is the pharmacy?',
      [
        'Behind the post office',
        'Opposite the post office',
        'Inside the post office',
      ],
      1,
    ),
    _PlacementTask(
      'r3',
      LearningSkill.reading,
      .7,
      '“Kvůli výluce tramvaj nejede.” Why is the tram not running?',
      ['A service interruption', 'Bad weather', 'A ticket inspection'],
      0,
    ),
    _PlacementTask(
      'l1',
      LearningSkill.listening,
      .2,
      'Listen, then choose the meaning.',
      ['Good morning', 'Good night', 'Good appetite'],
      0,
      spoken: 'Dobré ráno.',
    ),
    _PlacementTask(
      'l2',
      LearningSkill.listening,
      .45,
      'Listen: what does the speaker need?',
      ['A doctor', 'A ticket', 'A flat'],
      0,
      spoken: 'Potřebuji lékaře.',
    ),
    _PlacementTask(
      'l3',
      LearningSkill.listening,
      .7,
      'Listen: what must the person avoid?',
      ['Milk', 'Gluten', 'Medicine'],
      1,
      spoken: 'Nesmím jíst lepek.',
    ),
    _PlacementTask(
      'w1',
      LearningSkill.writing,
      .25,
      'Write in Czech: “Hello.”',
      [],
      0,
      accepted: ['ahoj', 'dobrý den'],
    ),
    _PlacementTask(
      'w2',
      LearningSkill.writing,
      .5,
      'Write in Czech: “I need help.”',
      [],
      0,
      accepted: ['potřebuji pomoc', 'potřebuju pomoc'],
    ),
    _PlacementTask(
      'w3',
      LearningSkill.writing,
      .7,
      'Write in Czech: “Could you repeat that, please?”',
      [],
      0,
      accepted: [
        'můžete to prosím zopakovat',
        'mohl byste to prosím zopakovat',
        'mohla byste to prosím zopakovat',
      ],
    ),
  ];

  final _observations = <DiagnosticObservation>[];
  final _answerController = TextEditingController();
  int? _selected;
  int _replays = 0;
  bool _saving = false;
  PlacementResult? _result;

  DiagnosticItem? get _next => _engine.nextItem(
    bank: _tasks.map((task) => task.item).toList(),
    observations: _observations,
  );
  _PlacementTask? get _task {
    final next = _next;
    if (next == null) return null;
    return _tasks.firstWhere((task) => task.id == next.id);
  }

  Future<void> _play(_PlacementTask task) async {
    setState(() => _replays++);
    await ref.read(ttsProvider).speak(task.spoken!);
  }

  Future<void> _submit() async {
    final task = _task;
    if (task == null) return;
    final correct = task.accepted.isNotEmpty
        ? task.accepted.contains(_normalize(_answerController.text))
        : _selected == task.correctIndex;
    _observations.add(
      DiagnosticObservation(
        item: task.item,
        correct: correct,
        independent: task.spoken == null || _replays <= 1,
      ),
    );
    _selected = null;
    _replays = 0;
    _answerController.clear();
    final next = _next;
    if (next == null) {
      final result = _engine.result(_observations);
      setState(() => _result = result);
      await _save(result);
    } else {
      setState(() {});
    }
  }

  Future<void> _save(PlacementResult result, {int? override}) async {
    setState(() => _saving = true);
    await ref
        .read(databaseProvider)
        .progressDao
        .savePlacement(result, learnerOverrideUnit: override);
    ref.invalidate(placementProfileProvider);
    ref.invalidate(curriculumAccessProvider);
    ref.invalidate(nextLessonProvider);
    if (mounted) {
      setState(() {
        _result = result;
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    final result = _result;
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, title: Text(l10n.placementTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (result != null) ...[
              Center(
                child: IconTile(
                  icon: Icons.route_outlined,
                  tint: t.violetSoft,
                  fg: t.violetInk,
                  size: 72,
                  radius: 24,
                  iconSize: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.placementSuggestedUnit(result.provisionalUnit),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: context.tokens.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.placementProvisional,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.45, color: t.muted),
              ),
              const SizedBox(height: 22),
              DropdownButtonFormField<int>(
                initialValue: result.provisionalUnit,
                decoration: InputDecoration(
                  labelText: l10n.placementChooseUnit,
                ),
                items: const [1, 6, 12, 18, 24]
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit,
                        child: Text('Unit $unit'),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (unit) {
                        if (unit == null) return;
                        _save(
                          _engine.result(
                            _observations,
                            learnerOverrideUnit: unit,
                          ),
                          override: unit,
                        );
                      },
              ),
              const SizedBox(height: 22),
              KeyCta(
                label: l10n.placementUseStart,
                onPressed: _saving
                    ? null
                    : () {
                        if (widget.returnToOnboarding) {
                          context.pop(result);
                        } else {
                          context.go('/');
                        }
                      },
              ),
            ] else if (task != null) ...[
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 17, color: t.pri),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.placementAdaptiveQuestion(_observations.length + 1),
                      style: TextStyle(
                        color: t.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              LessonKicker(task.skill.name, color: t.pri),
              const SizedBox(height: 8),
              QuestionPrompt(question: task.prompt),
              if (task.spoken != null) ...[
                const SizedBox(height: 18),
                ListenPanel(
                  onPlay: () => _play(task),
                  onSlow: () => _play(task),
                ),
              ],
              const SizedBox(height: 20),
              if (task.accepted.isNotEmpty)
                AnswerField(
                  controller: _answerController,
                  multiline: true,
                  semanticLabel: l10n.placementAnswerLabel,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => setState(() {}),
                )
              else
                // The same option tile every other pick-one question uses —
                // this was a bare radio list, which made the identical
                // interaction look like a different product.
                for (var index = 0; index < task.options.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: QuizOptionTile(
                      keyLabel: String.fromCharCode(65 + index),
                      text: task.options[index],
                      // A diagnostic never reveals the answer, so only idle
                      // and selected are in play.
                      state: _selected == index
                          ? OptionState.selected
                          : OptionState.idle,
                      onTap: () => setState(() => _selected = index),
                    ),
                  ),
              const SizedBox(height: 14),
              KeyCta(
                label: l10n.placementNext,
                onPressed:
                    (task.accepted.isNotEmpty
                            ? _answerController.text.trim().isNotEmpty
                            : _selected != null) &&
                        (task.spoken == null || _replays > 0)
                    ? _submit
                    : null,
              ),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(l10n.placementFinishLater),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlacementTask {
  final String id;
  final LearningSkill skill;
  final double difficulty;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? spoken;
  final List<String> accepted;

  const _PlacementTask(
    this.id,
    this.skill,
    this.difficulty,
    this.prompt,
    this.options,
    this.correctIndex, {
    this.spoken,
    this.accepted = const [],
  });

  DiagnosticItem get item => DiagnosticItem(
    id: id,
    skill: skill,
    difficulty: difficulty,
    unitCeiling: (difficulty * 30).round(),
  );
}

String _normalize(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[.!?]'), '')
    .replaceAll(RegExp(r'\s+'), ' ');
