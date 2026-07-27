import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/database.dart' as db;
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/learning_evidence.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/database_providers.dart';
import '../../widgets/lesson/exercises/exercise_shared.dart';
import '../../widgets/lesson/lesson_exercise_viewport.dart';

final dueTransferProvider = FutureProvider<List<db.DelayedTransferAssignment>>(
  (ref) =>
      ref.read(databaseProvider).progressDao.getDueTransfers(DateTime.now()),
);

class DelayedTransferScreen extends ConsumerStatefulWidget {
  final String assignmentId;

  const DelayedTransferScreen({super.key, required this.assignmentId});

  @override
  ConsumerState<DelayedTransferScreen> createState() =>
      _DelayedTransferScreenState();
}

class _DelayedTransferScreenState extends ConsumerState<DelayedTransferScreen> {
  static const _uuid = Uuid();
  db.DelayedTransferAssignment? _assignment;
  Exercise? _exercise;
  DateTime? _startedAt;
  bool _loading = true;
  bool _saving = false;
  bool? _correct;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final database = ref.read(databaseProvider);
      final assignment =
          await (database.select(database.delayedTransferAssignments)..where(
            (row) => row.assignmentId.equals(widget.assignmentId),
          )).getSingleOrNull();
      if (assignment == null || assignment.status != 'pending') {
        throw StateError('This transfer task is no longer available.');
      }
      final exercises = await ref
          .read(curriculumRepositoryProvider)
          .getExercises(assignment.lessonId);
      final variants =
          exercises
              .where((item) => item.id != assignment.sourceExerciseId)
              .toList();
      if (variants.isEmpty) {
        throw StateError('No independent transfer variant is available.');
      }
      if (!mounted) return;
      setState(() {
        _assignment = assignment;
        _exercise = variants.first;
        _startedAt = DateTime.now();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _complete(ExerciseResult result) async {
    if (_saving) return;
    final assignment = _assignment;
    final exercise = _exercise;
    if (assignment == null || exercise == null) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    try {
      await ref
          .read(databaseProvider)
          .progressDao
          .completeTransfer(
            assignmentId: assignment.assignmentId,
            evidence: LearningEvidence(
              evidenceId: _uuid.v4(),
              lessonId: assignment.lessonId,
              exerciseId: exercise.id,
              skill: _skillFor(exercise.type),
              phase: LearningPhase.delayedTransfer,
              correct: result.isCorrect,
              novelTask: true,
              supports: result.supports,
              conceptKeys: {
                if (exercise.grammarRuleId case final key?) key,
                ...?((exercise.data['concept_tags'] as List?)
                    ?.whereType<String>()),
              },
              responseLatency: now.difference(_startedAt ?? now),
              observedAt: now,
            ),
          );
      ref.invalidate(dueTransferProvider);
      ref.invalidate(learningEvidenceProvider);
      ref.invalidate(nextLessonProvider);
      if (mounted) {
        setState(() {
          _correct = result.isCorrect;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Couldn’t save this transfer attempt. Please try again.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Try it in a new way')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
              : _correct != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _correct! ? Icons.check_circle : Icons.refresh,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _correct!
                            ? 'Retained independently'
                            : 'This still needs practice',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This delayed result—not same-session repair—updates '
                        'your learning route.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => context.go('/'),
                        child: Text(AppLocalizations.of(context).continueLabel),
                      ),
                    ],
                  ),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'No hints or answer from the original task are carried '
                      'over. Take your best independent attempt.',
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: LessonExerciseViewport(
                        exercise: _exercise!,
                        onAnswered: _complete,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

LearningSkill _skillFor(ExerciseType type) => switch (type) {
  ExerciseType.readingComprehension => LearningSkill.reading,
  ExerciseType.listening ||
  ExerciseType.listeningComprehension ||
  ExerciseType.dictation => LearningSkill.listening,
  ExerciseType.writingTask || ExerciseType.translation => LearningSkill.writing,
  ExerciseType.speakingTask ||
  ExerciseType.pronunciation ||
  ExerciseType.dialogue => LearningSkill.speaking,
  ExerciseType.matching => LearningSkill.vocabulary,
  _ => LearningSkill.grammar,
};
