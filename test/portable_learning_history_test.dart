import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/database/daos/sync_dao.dart';
import 'package:czechify/data/sync/sync_service.dart';
import 'package:czechify/domain/entities/learning_evidence.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Account recovery restored headline progress but not the reasoning behind
/// it: the evidence placement reads, and practice already scheduled for a
/// future date. A restored learner kept their level and lost the record of
/// what they had shown they could do.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  LearningEvidence evidence({required String id, bool correct = true}) =>
      LearningEvidence(
        evidenceId: id,
        lessonId: 1,
        exerciseId: 7,
        skill: LearningSkill.vocabulary,
        phase: LearningPhase.retrieve,
        correct: correct,
        novelTask: false,
        supports: const {},
        conceptKeys: const {},
        responseLatency: const Duration(milliseconds: 1200),
        observedAt: DateTime.utc(2026, 9, 8),
      );

  Future<List<SyncQueueData>> queuedFor(String entity) async {
    final rows = await db.select(db.syncQueue).get();
    return rows.where((row) => row.entity == entity).toList();
  }

  test('recorded evidence is queued for the backend', () async {
    await db.progressDao.recordLearningEvidence(evidence(id: 'ev-1'));

    final queued = await queuedFor('learning_evidence_events');
    expect(queued, hasLength(1));
    expect(queued.single.entityKey, 'ev-1');
  });

  test('a duplicate observation is not queued twice', () async {
    await db.progressDao.recordLearningEvidence(evidence(id: 'ev-1'));
    await db.progressDao.recordLearningEvidence(evidence(id: 'ev-1'));

    // Evidence is immutable: the same observation is the same row, and
    // pushing it again would say it happened twice.
    expect(await queuedFor('learning_evidence_events'), hasLength(1));
  });

  test('pulled evidence restores without overwriting what is here', () async {
    await db.progressDao.recordLearningEvidence(evidence(id: 'ev-1'));

    // The same id arrives from another device, with the opposite verdict.
    await db.progressDao.mergeRemoteLearningEvidence(
      evidenceId: 'ev-1',
      lessonId: 1,
      exerciseId: 7,
      skill: 'vocabulary',
      phase: 'retrieve',
      correct: false,
      novelTask: false,
      supportsJson: '[]',
      conceptKeysJson: '[]',
      responseLatencyMs: 1200,
      observedAt: DateTime.utc(2026, 9, 8),
    );

    final stored = await db.select(db.learningEvidenceEvents).get();
    expect(stored, hasLength(1));
    expect(
      stored.single.correct,
      isTrue,
      reason: 'an observation already recorded here is not rewritten by a pull',
    );
  });

  test(
    'a pulled assignment restores, and completion wins over pending',
    () async {
      await db.progressDao.mergeRemoteTransferAssignment(
        assignmentId: 'transfer:a:7',
        sourceAttemptId: 'a',
        lessonId: 1,
        sourceExerciseId: 7,
        dueAt: DateTime.utc(2026, 9, 15),
        status: 'pending',
        createdAt: DateTime.utc(2026, 9, 8),
      );

      // Practice already promised for a future date survives the move.
      var stored = await db.select(db.delayedTransferAssignments).get();
      expect(stored.single.status, 'pending');

      await db.progressDao.mergeRemoteTransferAssignment(
        assignmentId: 'transfer:a:7',
        sourceAttemptId: 'a',
        lessonId: 1,
        sourceExerciseId: 7,
        dueAt: DateTime.utc(2026, 9, 15),
        status: 'completed',
        completedEvidenceId: 'ev-9',
        createdAt: DateTime.utc(2026, 9, 8),
        completedAt: DateTime.utc(2026, 9, 12),
      );

      // Unlike evidence, an assignment mutates — otherwise a restored learner is
      // asked to redo practice they have already done.
      stored = await db.select(db.delayedTransferAssignments).get();
      expect(stored, hasLength(1));
      expect(stored.single.status, 'completed');
      expect(stored.single.completedEvidenceId, 'ev-9');
    },
  );

  test('the raw attempt logs are deliberately not synced', () {
    // These stay local: the state a learner experiences is derived from them
    // and already syncs, so carrying them would multiply rows for
    // retrospective analytics nobody restores. The account screen says so.
    for (final entity in [
      'exercise_attempts',
      'review_attempts',
      'lesson_attempts',
      'reward_ledger',
    ]) {
      expect(SyncService.conflictKeys.keys, isNot(contains(entity)));
    }

    // And these two are, because they are the diagnosis and the promise.
    expect(
      SyncService.conflictKeys.keys,
      containsAll(<String>[
        'learning_evidence_events',
        'delayed_transfer_assignments',
      ]),
    );
  });

  group('pulled rows land in the right columns', () {
    // The seam where a server column name meets a local field. A typo here
    // drops a value silently rather than failing, so it is worth driving the
    // real mapping rather than the DAO underneath it.
    late SyncService sync;

    setUp(() {
      sync = SyncService(db: db, backend: _IdleBackend());
    });

    test('evidence keeps every field it was sent', () async {
      await sync.applyRemoteRow('learning_evidence_events', {
        'evidence_id': 'ev-remote',
        'lesson_id': 4,
        'exercise_id': 11,
        'skill': 'grammar',
        'phase': 'repair',
        'correct': true,
        'novel_task': true,
        'supports': ['hint'],
        'concept_keys': ['dative'],
        'response_latency_ms': 900,
        'observed_at': '2026-09-08T10:00:00.000Z',
      });

      final stored = (await db.select(db.learningEvidenceEvents).get()).single;
      expect(stored.evidenceId, 'ev-remote');
      expect(stored.lessonId, 4);
      expect(stored.exerciseId, 11);
      expect(stored.skill, 'grammar');
      expect(stored.phase, 'repair');
      expect(stored.correct, isTrue);
      expect(stored.novelTask, isTrue);
      expect(stored.supportsJson, contains('hint'));
      expect(stored.conceptKeysJson, contains('dative'));
      expect(stored.responseLatencyMs, 900);
    });

    test('an assignment keeps every field it was sent', () async {
      await sync.applyRemoteRow('delayed_transfer_assignments', {
        'assignment_id': 'transfer:b:3',
        'source_attempt_id': 'b',
        'lesson_id': 2,
        'source_exercise_id': 3,
        'due_at': '2026-09-15T09:00:00.000Z',
        'status': 'pending',
        'completed_evidence_id': null,
        'created_at': '2026-09-08T09:00:00.000Z',
        'completed_at': null,
      });

      final stored =
          (await db.select(db.delayedTransferAssignments).get()).single;
      expect(stored.assignmentId, 'transfer:b:3');
      expect(stored.sourceAttemptId, 'b');
      expect(stored.lessonId, 2);
      expect(stored.sourceExerciseId, 3);
      expect(stored.status, 'pending');
      expect(stored.completedAt, isNull);
    });
  });
}

/// Enough of a backend to construct the service; these tests never sync.
class _IdleBackend implements SyncBackend {
  @override
  bool get isReady => false;

  @override
  String? get userId => null;

  @override
  Future<String> deviceId() async => 'test-device';

  @override
  Future<void> send(
    SyncQueueData row, {
    required String onConflict,
    required String mutationDeviceId,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> pullPage(
    String entity, {
    required PullCursor? cursor,
    required int limit,
  }) async => const [];
}
