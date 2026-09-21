import '../../domain/entities/pending_referral_receipt.dart';
import 'dart:convert';
import '../../domain/entities/gamification_state.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/entities/exercise_attempt_evidence.dart';
import '../../domain/entities/practice_evidence.dart';
import '../../domain/entities/concept_error_evidence.dart';
import '../../domain/engines/concept_classifier.dart';
import '../database/database.dart' as db;

/// Concrete implementation of [ProgressRepository] using Drift.
class DriftProgressRepository implements ProgressRepository {
  final db.AppDatabase _db;

  DriftProgressRepository(this._db);

  @override
  Stream<ProgressSnapshot> watchProgress() {
    return _db.progressDao.watchCompletedLessons().asyncMap((completed) async {
      final evidence = await _buildUnitEvidence(completed);
      final components = await _buildComponentEvidence();
      final conceptErrors = await _buildConceptErrors();
      return ProgressSnapshot(
        unitScores: evidence.scores,
        completedLessonsByUnit: evidence.completed,
        totalLessonsByUnit: evidence.total,
        evidenceUpdatedAt: evidence.updatedAt,
        componentEvidence: components,
        conceptErrors: conceptErrors,
      );
    });
  }

  @override
  Future<bool> recordCompletion({
    required String attemptId,
    required int unitId,
    required int lessonId,
    required double score,
    required int correctCount,
    required int incorrectCount,
    required int skippedCount,
    required DateTime startedAt,
    required int activityXp,
    required List<ExerciseAttemptEvidence> exerciseEvidence,
    String phase = 'initial',
    PendingReferralReceipt? referralReceipt,
  }) {
    return _db.progressDao.recordLessonCompletion(
      attemptId: attemptId,
      unitId: unitId,
      lessonId: lessonId,
      score: score,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      skippedCount: skippedCount,
      startedAt: startedAt,
      activityXp: activityXp,
      exerciseEvidence: exerciseEvidence,
      phase: phase,
      referralReceipt: referralReceipt,
    );
  }

  @override
  Future<Set<int>> getCompletedLessonIds() async {
    final completed = await _db.progressDao.getCompletedLessons();
    return completed.map((l) => l.lessonId).toSet();
  }

  @override
  Future<ProgressSnapshot> getSnapshot() async {
    final completed = await _db.progressDao.getCompletedLessons();
    final badgeIds = await _db.progressDao.getEarnedBadgeIds();

    final evidence = await _buildUnitEvidence(completed);
    final components = await _buildComponentEvidence();
    final conceptErrors = await _buildConceptErrors();

    // Get streak from KV store
    final longestStreakStr = await _db.progressDao.getProgressValue(
      'longest_streak',
    );
    final examsPassedStr = await _db.progressDao.getProgressValue(
      'exams_passed',
    );

    return ProgressSnapshot(
      unitScores: evidence.scores,
      completedLessonsByUnit: evidence.completed,
      totalLessonsByUnit: evidence.total,
      evidenceUpdatedAt: evidence.updatedAt,
      componentEvidence: components,
      conceptErrors: conceptErrors,
      longestStreak: int.tryParse(longestStreakStr ?? '0') ?? 0,
      examsPassed:
          examsPassedStr != null
              ? (jsonDecode(examsPassedStr) as List<dynamic>)
                  .cast<String>()
                  .toSet()
              : {},
      earnedBadges: badgeIds.toSet(),
    );
  }

  Future<
    ({
      Map<int, double> scores,
      Map<int, int> completed,
      Map<int, int> total,
      DateTime? updatedAt,
    })
  >
  _buildUnitEvidence(List<db.LessonProgressData> completedRows) async {
    final lessons =
        await (_db.select(_db.lessons)
          ..where((lesson) => lesson.isActive.equals(true))).get();
    final total = <int, int>{};
    for (final lesson in lessons) {
      total[lesson.unitId] = (total[lesson.unitId] ?? 0) + 1;
    }

    final scoreSums = <int, double>{};
    final completed = <int, int>{};
    DateTime? updatedAt;
    for (final row in completedRows) {
      scoreSums[row.unitId] = (scoreSums[row.unitId] ?? 0) + row.bestScore;
      completed[row.unitId] = (completed[row.unitId] ?? 0) + 1;
      final attempted = row.lastAttempted;
      if (attempted != null &&
          (updatedAt == null || attempted.isAfter(updatedAt))) {
        updatedAt = attempted;
      }
    }

    final scores = <int, double>{
      for (final entry in total.entries)
        entry.key:
            entry.value == 0 ? 0 : (scoreSums[entry.key] ?? 0) / entry.value,
    };
    return (
      scores: scores,
      completed: completed,
      total: total,
      updatedAt: updatedAt,
    );
  }

  Future<Map<String, PracticeEvidence>> _buildComponentEvidence() async {
    final rows =
        await _db.customSelect('''
      SELECT ea.phase, ea.outcome, ea.answered_at,
             e.type, e.grammar_rule_id, gr.rule_name
      FROM exercise_attempts ea
      JOIN exercises e ON e.id = ea.exercise_id
      LEFT JOIN grammar_rules gr ON gr.id = e.grammar_rule_id
      ORDER BY ea.answered_at
    ''').get();
    final aggregates = <String, _EvidenceAggregate>{};

    for (final row in rows) {
      final type = row.read<String>('type');
      final components = _skillComponentsFor(type);
      final grammarRuleId = row.readNullable<String>('grammar_rule_id');
      if (grammarRuleId != null) {
        components['grammar:$grammarRuleId'] =
            row.readNullable<String>('rule_name') ?? grammarRuleId;
      }

      final phase = row.read<String>('phase');
      final outcome = row.read<String>('outcome');
      final answeredAt = row.read<DateTime>('answered_at');
      for (final entry in components.entries) {
        final aggregate = aggregates.putIfAbsent(
          entry.key,
          () => _EvidenceAggregate(entry.value),
        );
        aggregate.add(phase: phase, outcome: outcome, answeredAt: answeredAt);
      }
    }

    return {
      for (final entry in aggregates.entries)
        entry.key: entry.value.toEvidence(entry.key),
    };
  }

  Map<String, String> _skillComponentsFor(String type) => switch (type) {
    'reading_comprehension' => {'skill:reading': 'Reading'},
    'listening_comprehension' ||
    'listening' ||
    'dictation' => {'skill:listening': 'Listening'},
    'writing_task' => {'skill:writing': 'Writing'},
    'speaking_task' || 'dialogue' => {'skill:speaking': 'Speaking'},
    'pronunciation' => {'skill:pronunciation': 'Pronunciation'},
    'word_order' => {'skill:word_order': 'Word order'},
    'declension_table' || 'preposition_case' => {'skill:case': 'Case forms'},
    'translation' || 'matching' => {'skill:vocabulary': 'Vocabulary recall'},
    'fill_blank' ||
    'error_correction' ||
    'multiple_choice' => {'skill:grammar': 'Grammar'},
    _ => const {},
  };

  Future<Map<String, ConceptErrorEvidence>> _buildConceptErrors() async {
    final rows =
        await _db.customSelect('''
      SELECT ea.lesson_attempt_id, ea.exercise_id, ea.phase, ea.outcome,
             ea.answered_at, e.type, gr.rule_name, gr.pattern,
             gr.explanation, gr.case_affected, e.data
      FROM exercise_attempts ea
      JOIN exercises e ON e.id = ea.exercise_id
      LEFT JOIN grammar_rules gr ON gr.id = e.grammar_rule_id
      ORDER BY ea.answered_at
    ''').get();
    const classifier = ConceptClassifier();
    final aggregates = <String, _ConceptErrorAggregate>{};
    final repairable = <String>{};

    for (final row in rows) {
      final exerciseData = _decodeExerciseData(row.read<String>('data'));
      final concepts = classifier.classify(
        exerciseType: row.read<String>('type'),
        ruleName: row.readNullable<String>('rule_name'),
        rulePattern: row.readNullable<String>('pattern'),
        ruleExplanation: row.readNullable<String>('explanation'),
        caseAffected: row.readNullable<String>('case_affected'),
        conceptTags: switch (exerciseData['concept_tags']) {
          final List<dynamic> tags => tags.whereType<String>().toList(),
          _ => const [],
        },
        communicativeFunction: switch (exerciseData['communicative_function']) {
          final String function => function,
          _ => null,
        },
      );
      final phase = row.read<String>('phase');
      final outcome = row.read<String>('outcome');
      final answeredAt = row.read<DateTime>('answered_at');
      final attemptId = row.read<String>('lesson_attempt_id');
      final exerciseId = row.read<int>('exercise_id');

      for (final concept in concepts.entries) {
        final matchKey = '$attemptId:$exerciseId:${concept.key}';
        if (phase == 'initial' && outcome == 'incorrect') {
          aggregates
              .putIfAbsent(
                concept.key,
                () => _ConceptErrorAggregate(concept.value),
              )
              .addError(answeredAt);
          repairable.add(matchKey);
        } else if (phase == 'immediate_repair' &&
            outcome == 'correct' &&
            repairable.remove(matchKey)) {
          aggregates[concept.key]?.addRepair();
        }
      }
    }

    return {
      for (final entry in aggregates.entries)
        entry.key: entry.value.toEvidence(entry.key),
    };
  }

  Map<String, dynamic> _decodeExerciseData(String encoded) {
    try {
      return jsonDecode(encoded) as Map<String, dynamic>;
    } on FormatException {
      return const {};
    } on TypeError {
      return const {};
    }
  }

  @override
  Future<void> recordExamPassed(String level) async {
    final snapshot = await getSnapshot();
    final exams = Set<String>.from(snapshot.examsPassed);
    exams.add(level);
    await _db.progressDao.setProgressValue(
      'exams_passed',
      jsonEncode(exams.toList()),
    );
  }

  @override
  Future<void> updateStreak(int currentStreak, int longestStreak) async {
    await _db.progressDao.setProgressValue('streak', currentStreak.toString());
    await _db.progressDao.setProgressValue(
      'longest_streak',
      longestStreak.toString(),
    );
  }
}

class _ConceptErrorAggregate {
  final String label;
  int initialErrors = 0;
  int repairedErrors = 0;
  DateTime? latestErrorAt;

  _ConceptErrorAggregate(this.label);

  void addError(DateTime answeredAt) {
    initialErrors++;
    if (latestErrorAt == null || answeredAt.isAfter(latestErrorAt!)) {
      latestErrorAt = answeredAt;
    }
  }

  void addRepair() => repairedErrors++;

  ConceptErrorEvidence toEvidence(String key) => ConceptErrorEvidence(
    conceptKey: key,
    label: label,
    initialErrors: initialErrors,
    repairedErrors: repairedErrors,
    latestErrorAt: latestErrorAt!,
  );
}

class _EvidenceAggregate {
  final String label;
  int exposures = 0;
  int initialAttempts = 0;
  int initialCorrect = 0;
  int repairAttempts = 0;
  int repairCorrect = 0;
  DateTime? latestAt;

  _EvidenceAggregate(this.label);

  void add({
    required String phase,
    required String outcome,
    required DateTime answeredAt,
  }) {
    exposures++;
    if (latestAt == null || answeredAt.isAfter(latestAt!)) {
      latestAt = answeredAt;
    }
    if (outcome == 'skipped') return;
    if (phase == 'initial') {
      initialAttempts++;
      if (outcome == 'correct') initialCorrect++;
    } else if (phase == 'immediate_repair') {
      repairAttempts++;
      if (outcome == 'correct') repairCorrect++;
    }
  }

  PracticeEvidence toEvidence(String key) => PracticeEvidence(
    componentKey: key,
    label: label,
    exposures: exposures,
    initialAttempts: initialAttempts,
    initialCorrect: initialCorrect,
    repairAttempts: repairAttempts,
    repairCorrect: repairCorrect,
    latestAt: latestAt,
  );
}
