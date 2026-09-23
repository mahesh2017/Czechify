import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'enums.dart';
import 'exercise.dart';
import 'exercise_attempt_evidence.dart';
import 'exercise_outcome.dart';

/// The referral campaign whose manifest these receipts are checked against.
const referralCampaignId = 'a1-referral-v1';

/// Content revision the campaign's pinned manifest was reviewed for. A new
/// content revision needs a new reviewed manifest on the server first.
const referralContentRevision = 25;

/// How the learner first met one exercise in an attempt. Teaching cards are
/// acknowledged, never answered; the lesson player reports their Continue as
/// a skip, so that report is translated here rather than trusted.
enum ReferralInteraction {
  teachingAcknowledged('teaching_acknowledged'),
  answeredCorrectly('answered_correctly'),
  answeredIncorrectly('answered_incorrectly'),
  skipped('skipped');

  const ReferralInteraction(this.wireName);
  final String wireName;
}

/// Evidence that one lesson attempt was completed in the normal player: each
/// exercise's first interaction, the attempt, and the claim held when the
/// attempt began. It proves participation, not a unique human.
class ReferralReceipt {
  final String claimId;
  final int lessonId;
  final String attemptId;
  final DateTime startedAt;
  final DateTime completedAt;
  final Map<int, ReferralInteraction> coverage;

  const ReferralReceipt({
    required this.claimId,
    required this.lessonId,
    required this.attemptId,
    required this.startedAt,
    required this.completedAt,
    required this.coverage,
  });

  /// Builds coverage from the player's evidence: the first `initial` record
  /// per exercise. Returns null unless every exercise of the lesson has one,
  /// so a partial attempt never becomes a receipt.
  static ReferralReceipt? fromAttempt({
    required String claimId,
    required int lessonId,
    required String attemptId,
    required DateTime startedAt,
    required DateTime completedAt,
    required List<Exercise> exercises,
    required List<ExerciseAttemptEvidence> evidence,
  }) {
    final types = {for (final e in exercises) e.id: e.type};
    if (types.isEmpty) return null;
    final coverage = <int, ReferralInteraction>{};
    for (final record in evidence) {
      if (record.phase != ExerciseEvidencePhase.initial) continue;
      final type = types[record.exerciseId];
      if (type == null || coverage.containsKey(record.exerciseId)) continue;
      coverage[record.exerciseId] =
          type == ExerciseType.teaching
              ? ReferralInteraction.teachingAcknowledged
              : switch (record.outcome) {
                ExerciseOutcome.correct =>
                  ReferralInteraction.answeredCorrectly,
                ExerciseOutcome.incorrect =>
                  ReferralInteraction.answeredIncorrectly,
                ExerciseOutcome.skipped => ReferralInteraction.skipped,
              };
    }
    if (coverage.length != types.length) return null;
    return ReferralReceipt(
      claimId: claimId,
      lessonId: lessonId,
      attemptId: attemptId,
      startedAt: startedAt,
      completedAt: completedAt,
      coverage: coverage,
    );
  }

  /// The wire object. Coverage is sorted by exercise ID, as the server
  /// normalizes it, so both sides hash the same bytes.
  Map<String, Object> toJson() => {
    'schema_version': 1,
    'claim_id': claimId,
    'campaign_id': referralCampaignId,
    'content_revision': referralContentRevision,
    'lesson_id': lessonId,
    'attempt_id': attemptId,
    'started_at_client': referralTimestamp(startedAt),
    'completed_at_client': referralTimestamp(completedAt),
    'initial_coverage': [
      for (final id in coverage.keys.toList()..sort())
        {'exercise_id': id, 'interaction': coverage[id]!.wireName},
    ],
  };

  String get digest => sha256Hex(canonicalJson(toJson()));
}

/// UTC with exactly three fractional digits, the shape the server accepts.
String referralTimestamp(DateTime time) {
  final utc = time.toUtc();
  final truncated = DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
    utc.millisecond,
  );
  final iso = truncated.toIso8601String();
  // Dart omits the fraction when it is zero; always emit milliseconds.
  return iso.contains('.') ? iso : iso.replaceFirst('Z', '.000Z');
}

/// Canonical JSON shared with the server: keys sorted at every level, no
/// whitespace, integers only, printable-ASCII strings. Anything else throws
/// rather than risk a different encoding. Pinned by
/// test/fixtures/monetization/referral_receipt.v1.json.
String canonicalJson(Object? value) {
  if (value == null || value is bool) return jsonEncode(value);
  if (value is int) return value.toString();
  if (value is String) {
    if (!RegExp(r'^[\x20-\x7e]*$').hasMatch(value)) {
      throw const FormatException('Non-ASCII string in canonical JSON.');
    }
    return jsonEncode(value);
  }
  if (value is List) return '[${value.map(canonicalJson).join(',')}]';
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${canonicalJson(value[k])}').join(',')}}';
  }
  throw FormatException(
    'Unsupported canonical JSON value: ${value.runtimeType}',
  );
}

String sha256Hex(String text) => sha256.convert(utf8.encode(text)).toString();

/// Play Integrity `requestHash` binding a token to this account, claim,
/// receipt and single-use nonce.
String referralIntegrityRequestHash({
  required String accountId,
  required String claimId,
  required String nonce,
  required String receiptDigest,
}) => sha256Hex(
  canonicalJson({
    'account_id': accountId,
    'campaign_id': referralCampaignId,
    'claim_id': claimId,
    'nonce': nonce,
    'receipt_digest': receiptDigest,
  }),
);
