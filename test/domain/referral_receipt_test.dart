import 'dart:convert';
import 'dart:io';

import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/exercise_attempt_evidence.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';
import 'package:czechify/domain/entities/referral_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Deno server hashes receipts too; both must match this fixture, which
/// was generated with Python's json module independently of either.
final fixture =
    jsonDecode(
          File(
            'test/fixtures/monetization/referral_receipt.v1.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

Exercise _exercise(int id, ExerciseType type) => Exercise(
  id: id,
  lessonId: 100,
  type: type,
  prompt: '',
  data: const {},
  xpReward: 10,
);

ExerciseAttemptEvidence _evidence(
  int id,
  ExerciseOutcome outcome, {
  ExerciseEvidencePhase phase = ExerciseEvidencePhase.initial,
}) => ExerciseAttemptEvidence(
  presentationId: 'p',
  exerciseId: id,
  phase: phase,
  outcome: outcome,
  answeredAt: DateTime.utc(2026),
);

void main() {
  final sent = fixture['receipt_as_sent'] as Map<String, dynamic>;

  test('canonical bytes and digest match the cross-language fixture', () {
    // The fixture's coverage arrives reversed; canonical order sorts it.
    final coverage = [...(sent['initial_coverage'] as List)]..sort(
      (a, b) => (a['exercise_id'] as int).compareTo(b['exercise_id'] as int),
    );
    final normalized = {...sent, 'initial_coverage': coverage};
    expect(canonicalJson(normalized), fixture['canonical']);
    expect(sha256Hex(canonicalJson(normalized)), fixture['receipt_digest']);
  });

  test('a receipt built from the player reproduces the fixture digest', () {
    final receipt = ReferralReceipt(
      claimId: sent['claim_id'] as String,
      lessonId: sent['lesson_id'] as int,
      attemptId: sent['attempt_id'] as String,
      startedAt: DateTime.parse(sent['started_at_client'] as String),
      completedAt: DateTime.parse(sent['completed_at_client'] as String),
      coverage: {
        for (final item in sent['initial_coverage'] as List)
          item['exercise_id'] as int: ReferralInteraction.values.firstWhere(
            (i) => i.wireName == item['interaction'],
          ),
      },
    );
    expect(canonicalJson(receipt.toJson()), fixture['canonical']);
    expect(receipt.digest, fixture['receipt_digest']);
  });

  test('the Integrity request hash matches the fixture', () {
    final binding = fixture['integrity_binding'] as Map<String, dynamic>;
    expect(canonicalJson(binding), fixture['integrity_binding_canonical']);
    expect(
      referralIntegrityRequestHash(
        accountId: binding['account_id'] as String,
        claimId: binding['claim_id'] as String,
        nonce: binding['nonce'] as String,
        receiptDigest: binding['receipt_digest'] as String,
      ),
      fixture['integrity_request_hash'],
    );
  });

  test('timestamps always carry milliseconds in UTC', () {
    expect(
      referralTimestamp(DateTime.utc(2026, 10, 1, 11, 40)),
      '2026-10-01T11:40:00.000Z',
    );
    expect(
      referralTimestamp(DateTime.utc(2026, 10, 1, 11, 52, 30, 250, 999)),
      '2026-10-01T11:52:30.250Z',
    );
    expect(
      referralTimestamp(DateTime.parse('2026-10-01T13:40:00+02:00')),
      '2026-10-01T11:40:00.000Z',
    );
  });

  test('values two encoders could disagree on are refused', () {
    expect(() => canonicalJson({'a': 1.5}), throwsFormatException);
    expect(() => canonicalJson({'a': 'č'}), throwsFormatException);
  });

  group('coverage from the player', () {
    final exercises = [
      _exercise(1, ExerciseType.teaching),
      _exercise(2, ExerciseType.multipleChoice),
      _exercise(3, ExerciseType.fillBlank),
    ];
    ReferralReceipt? build(List<ExerciseAttemptEvidence> evidence) =>
        ReferralReceipt.fromAttempt(
          claimId: 'c',
          lessonId: 100,
          attemptId: 'a',
          startedAt: DateTime.utc(2026),
          completedAt: DateTime.utc(2026),
          exercises: exercises,
          evidence: evidence,
        );

    test('a teaching card\'s Continue counts as acknowledgement', () {
      final receipt =
          build([
            _evidence(1, ExerciseOutcome.skipped),
            _evidence(2, ExerciseOutcome.incorrect),
            _evidence(
              2,
              ExerciseOutcome.correct,
              phase: ExerciseEvidencePhase.immediateRepair,
            ),
            _evidence(3, ExerciseOutcome.correct),
          ])!;
      expect(receipt.coverage, {
        1: ReferralInteraction.teachingAcknowledged,
        2: ReferralInteraction.answeredIncorrectly,
        3: ReferralInteraction.answeredCorrectly,
      });
    });

    test('a skipped practice exercise is recorded as skipped', () {
      final receipt =
          build([
            _evidence(1, ExerciseOutcome.skipped),
            _evidence(2, ExerciseOutcome.skipped),
            _evidence(3, ExerciseOutcome.correct),
          ])!;
      expect(receipt.coverage[2], ReferralInteraction.skipped);
    });

    test('repairs never replace the first interaction', () {
      final receipt =
          build([
            _evidence(1, ExerciseOutcome.skipped),
            _evidence(
              2,
              ExerciseOutcome.correct,
              phase: ExerciseEvidencePhase.immediateRepair,
            ),
            _evidence(2, ExerciseOutcome.incorrect),
            _evidence(3, ExerciseOutcome.correct),
          ])!;
      expect(receipt.coverage[2], ReferralInteraction.answeredIncorrectly);
    });

    test('an attempt missing an exercise produces no receipt', () {
      expect(
        build([
          _evidence(1, ExerciseOutcome.skipped),
          _evidence(2, ExerciseOutcome.correct),
        ]),
        isNull,
      );
    });

    test('evidence for a foreign exercise is ignored', () {
      final receipt =
          build([
            _evidence(1, ExerciseOutcome.skipped),
            _evidence(2, ExerciseOutcome.correct),
            _evidence(3, ExerciseOutcome.correct),
            _evidence(99, ExerciseOutcome.correct),
          ])!;
      expect(receipt.coverage.keys, [1, 2, 3]);
    });
  });
}
