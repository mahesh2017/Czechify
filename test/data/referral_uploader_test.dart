import 'dart:convert';

import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/monetization/monetization_api.dart';
import 'package:czechify/data/referrals/play_integrity_service.dart';
import 'package:czechify/data/referrals/referral_api.dart';
import 'package:czechify/data/referrals/referral_store.dart';
import 'package:czechify/data/referrals/referral_uploader.dart';
import 'package:czechify/domain/entities/pending_referral_receipt.dart';
import 'package:czechify/domain/entities/referral_receipt.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 1, 12);
const _nonce =
    '9999999999999999999999999999999999999999999999999999999999999999';

class _Integrity implements PlayIntegrityService {
  IntegrityTokenResult result = const IntegrityToken('play-token');
  final hashes = <String>[];
  @override
  Future<IntegrityTokenResult> requestToken(String requestHash) async {
    hashes.add(requestHash);
    return result;
  }
}

void main() {
  late AppDatabase db;
  late ReferralStore store;
  late _Integrity integrity;
  late List<Map<String, Object?>> calls;
  late List<ApiResponse> submitReplies;
  late ApiResponse challengeReply;
  late String? account;
  late ReferralUploader uploader;

  Future<void> queue(String attemptId, {String accountId = 'account-a'}) =>
      db.progressDao.recordLessonCompletion(
        attemptId: attemptId,
        lessonId: 100,
        unitId: 1,
        score: 1,
        correctCount: 1,
        incorrectCount: 0,
        skippedCount: 0,
        startedAt: _now,
        activityXp: 10,
        exerciseEvidence: const [],
        referralReceipt: PendingReferralReceipt(
          accountId: accountId,
          receipt: ReferralReceipt(
            claimId: 'claim-1',
            lessonId: 100,
            attemptId: attemptId,
            startedAt: _now,
            completedAt: _now,
            coverage: const {899: ReferralInteraction.answeredCorrectly},
          ),
        ),
      );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = ReferralStore(db);
    integrity = _Integrity();
    calls = [];
    submitReplies = [];
    challengeReply = const ApiResponse(201, {'nonce': _nonce});
    account = 'account-a';
    uploader = ReferralUploader(
      store: store,
      api: ReferralApi((
        route, {
        required method,
        body,
        headers = const {},
      }) async {
        calls.add({'route': route, ...?body});
        if (route == 'referrals/challenges') return challengeReply;
        return submitReplies.isEmpty
            ? const ApiResponse(202, {'receipt_id': 'r', 'status': 'accepted'})
            : submitReplies.removeAt(0);
      }),
      integrity: integrity,
      currentAccount: () => account,
      now: () => _now,
      random: () => 1,
    );
    await queue('attempt-1');
  });
  tearDown(() => db.close());

  Future<ReferralReceiptOutboxData> row([
    String attemptId = 'attempt-1',
  ]) async => (await store.all(
    'account-a',
  )).firstWhere((r) => r.attemptId == attemptId);

  test('challenge, a token bound to it, then the receipt', () async {
    await uploader.drain();
    final stored = await row();
    expect(stored.status, 'sent');
    expect(calls.first, {
      'route': 'referrals/challenges',
      'claim_id': 'claim-1',
      'receipt_digest': stored.receiptDigest,
    });
    expect(
      integrity.hashes.single,
      referralIntegrityRequestHash(
        accountId: 'account-a',
        claimId: 'claim-1',
        nonce: _nonce,
        receiptDigest: stored.receiptDigest,
      ),
    );
    expect(calls.last['integrity_token'], 'play-token');
    expect(calls.last['receipt'], jsonDecode(stored.receiptJson));
    expect(calls.last.containsKey('integrity_unavailable'), isFalse);
  });

  test('a device without Integrity takes the review route', () async {
    integrity.result = const IntegrityUnsupported();
    await uploader.drain();
    expect(calls.last['integrity_unavailable'], isTrue);
    expect(calls.last.containsKey('integrity_token'), isFalse);
    expect((await row()).status, 'sent');
  });

  test('a transient Integrity failure waits and sends nothing', () async {
    integrity.result = const IntegrityRetry();
    await uploader.drain();
    final stored = await row();
    expect(stored.status, 'pending');
    expect(stored.attempts, 1);
    expect(stored.nextAttemptAt.isAfter(_now), isTrue);
    expect(calls.where((c) => c['route'] == 'referrals/receipts'), isEmpty);
  });

  test('a build without Integrity configured holds, not reviews', () async {
    integrity.result = const IntegrityMisconfigured();
    await uploader.drain();
    final stored = await row();
    expect(stored.lastError, 'integrity_misconfigured');
    expect(stored.nextAttemptAt.toUtc(), _now.add(const Duration(hours: 6)));
    expect(calls.where((c) => c['route'] == 'referrals/receipts'), isEmpty);
  });

  test(
    'permanent refusals stop retrying; server-side waits are held',
    () async {
      await store.settle('account-a', 'attempt-1', 'sent');
      for (final (code, status) in const [
        ('integrity_rejected', 'rejected'),
        ('invalid_receipt', 'rejected'),
        ('referral_unavailable', 'rejected'),
        ('idempotency_conflict', 'rejected'),
        ('content_update_required', 'held'),
        ('campaign_unavailable', 'held'),
      ]) {
        // One fresh attempt per case; earlier ones are already settled.
        await queue('attempt-$code');
        submitReplies = [
          ApiResponse(409, {'code': code}),
        ];
        await uploader.drain();
        final stored = await row('attempt-$code');
        expect([stored.status, stored.lastError], [status, code]);
      }
    },
  );

  test(
    'a used challenge retries in seconds; a rate limit waits an hour',
    () async {
      submitReplies = [
        const ApiResponse(409, {'code': 'challenge_invalid'}),
      ];
      await uploader.drain();
      expect(
        (await row()).nextAttemptAt.toUtc(),
        _now.add(const Duration(seconds: 5)),
      );
      challengeReply = const ApiResponse(429, {'code': 'rate_limited'});
      await store.settle('account-a', 'attempt-1', 'sent');
      await queue('attempt-2');
      await uploader.drain();
      expect(
        (await row('attempt-2')).nextAttemptAt.toUtc(),
        _now.add(const Duration(hours: 1)),
      );
    },
  );

  test('a lost connection keeps the receipt for later', () async {
    final failing = ReferralUploader(
      store: store,
      api: ReferralApi(
        (route, {required method, body, headers = const {}}) =>
            throw Exception('offline'),
      ),
      integrity: integrity,
      currentAccount: () => 'account-a',
      now: () => _now,
      random: () => 1,
    );
    await failing.drain();
    final stored = await row();
    expect(
      [stored.status, stored.attempts, stored.lastError],
      ['pending', 1, 'transport'],
    );
  });

  test(
    'another account\'s receipts are never uploaded under this session',
    () async {
      await queue('attempt-b', accountId: 'account-b');
      await uploader.drain();
      final other = (await store.all('account-b')).single;
      expect(other.status, 'pending');
      expect(
        calls.where((c) => c['route'] == 'referrals/challenges'),
        hasLength(1),
      );
    },
  );

  test('uploads stop the moment the account changes', () async {
    await queue('attempt-2');
    integrity.result = const IntegrityToken('play-token');
    final switching = ReferralUploader(
      store: store,
      api: ReferralApi((
        route, {
        required method,
        body,
        headers = const {},
      }) async {
        calls.add({'route': route, ...?body});
        // The session changes while the first challenge is in flight.
        account = 'account-b';
        return const ApiResponse(201, {'nonce': _nonce});
      }),
      integrity: integrity,
      currentAccount: () => account,
      now: () => _now,
    );
    await switching.drain();
    expect(calls.map((c) => c['route']), ['referrals/challenges']);
    expect(integrity.hashes, isEmpty);
    expect(
      (await store.all('account-a')).every((r) => r.status == 'pending'),
      isTrue,
    );
  });

  test('overlapping drains share one pass', () async {
    final first = uploader.drain();
    final second = uploader.drain();
    await Future.wait([first, second]);
    expect(
      calls.where((c) => c['route'] == 'referrals/challenges'),
      hasLength(1),
    );
  });

  test('the native bridge\'s answers decode to the four outcomes', () {
    expect(
      decodeIntegrityResponse({'status': 'ok', 'token': 't'}),
      isA<IntegrityToken>(),
    );
    expect(
      decodeIntegrityResponse({'status': 'ok', 'token': ''}),
      isA<IntegrityRetry>(),
    );
    expect(
      decodeIntegrityResponse({'status': 'unsupported'}),
      isA<IntegrityUnsupported>(),
    );
    expect(
      decodeIntegrityResponse({'status': 'misconfigured'}),
      isA<IntegrityMisconfigured>(),
    );
    expect(decodeIntegrityResponse(null), isA<IntegrityRetry>());
  });
}
