import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../domain/engines/placement_engine.dart';
import '../../../domain/entities/learning_evidence.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/tts_providers.dart';

class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});

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
    final correct =
        task.accepted.isNotEmpty
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
    if (mounted) setState(() => _saving = false);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Find my starting point')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (result != null) ...[
              const Icon(Icons.route, size: 56),
              const SizedBox(height: 16),
              Text(
                'Suggested starting unit: ${result.provisionalUnit}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'This is provisional—not a CEFR result. We will adjust it from '
                'your independent delayed practice.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                initialValue: result.provisionalUnit,
                decoration: const InputDecoration(
                  labelText: 'Choose a different starting unit',
                ),
                items:
                    const [1, 6, 12, 18, 24]
                        .map(
                          (unit) => DropdownMenuItem(
                            value: unit,
                            child: Text('Unit $unit'),
                          ),
                        )
                        .toList(),
                onChanged:
                    _saving
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
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : () => context.go('/'),
                child: const Text('Use this starting point'),
              ),
            ] else if (task != null) ...[
              LinearProgressIndicator(
                value: _observations.length / PlacementEngine.minItems,
              ),
              const SizedBox(height: 24),
              Text(
                task.skill.name.toUpperCase(),
                style: TextStyle(
                  color: context.tokens.pri,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(task.prompt, style: Theme.of(context).textTheme.titleLarge),
              if (task.spoken != null) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _play(task),
                  icon: const Icon(Icons.volume_up),
                  label: Text(_replays == 0 ? 'Play audio' : 'Play again'),
                ),
              ],
              const SizedBox(height: 20),
              if (task.accepted.isNotEmpty)
                TextField(
                  controller: _answerController,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Your Czech answer',
                  ),
                  onChanged: (_) => setState(() {}),
                )
              else
                RadioGroup<int>(
                  groupValue: _selected,
                  onChanged: (value) => setState(() => _selected = value),
                  child: Column(
                    children: [
                      for (var index = 0; index < task.options.length; index++)
                        RadioListTile<int>(
                          value: index,
                          title: Text(task.options[index]),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed:
                    (task.accepted.isNotEmpty
                                ? _answerController.text.trim().isNotEmpty
                                : _selected != null) &&
                            (task.spoken == null || _replays > 0)
                        ? _submit
                        : null,
                child: const Text('Next'),
              ),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Finish later'),
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
