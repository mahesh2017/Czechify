import 'dart:io';

import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/referrals/referral_store.dart';
import 'package:czechify/domain/entities/pending_referral_receipt.dart';
import 'package:czechify/domain/entities/referral_receipt.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

ReferralReceipt _receipt(String attemptId) => ReferralReceipt(
  claimId: 'claim-1',
  lessonId: 100,
  attemptId: attemptId,
  startedAt: DateTime.utc(2026, 10, 1, 11),
  completedAt: DateTime.utc(2026, 10, 1, 11, 10),
  coverage: const {
    898: ReferralInteraction.teachingAcknowledged,
    899: ReferralInteraction.answeredCorrectly,
  },
);

void main() {
  late AppDatabase db;
  late ReferralStore store;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = ReferralStore(db);
  });
  tearDown(() => db.close());

  Future<bool> complete(String attemptId, {String account = 'account-a'}) =>
      db.progressDao.recordLessonCompletion(
        attemptId: attemptId,
        lessonId: 100,
        unitId: 1,
        score: 1,
        correctCount: 1,
        incorrectCount: 0,
        skippedCount: 1,
        startedAt: DateTime.utc(2026, 10, 1, 11),
        activityXp: 10,
        exerciseEvidence: const [],
        referralReceipt: PendingReferralReceipt(
          accountId: account,
          receipt: _receipt(attemptId),
        ),
      );

  test(
    'a receipt is queued in the same commit as its lesson attempt',
    () async {
      expect(await complete('attempt-1'), isTrue);
      final rows = await store.all('account-a');
      expect(rows.single.attemptId, 'attempt-1');
      expect(rows.single.status, 'pending');
      expect(rows.single.receiptDigest, _receipt('attempt-1').digest);
      expect(
        (await db.select(db.lessonAttempts).get()).single.attemptId,
        'attempt-1',
      );
    },
  );

  test('a replayed attempt queues nothing a second time', () async {
    await complete('attempt-1');
    expect(await complete('attempt-1'), isFalse);
    expect(await store.all('account-a'), hasLength(1));
  });

  test('a failed receipt write rolls the lesson attempt back too', () async {
    // Fail the receipt insert, which runs after the attempt row is written:
    // only a shared transaction removes that attempt again.
    await db.customStatement(
      'CREATE TRIGGER fail_receipt BEFORE INSERT ON referral_receipt_outbox '
      "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    await expectLater(complete('attempt-1'), throwsA(anything));
    expect(await db.select(db.lessonAttempts).get(), isEmpty);
    expect(await store.all('account-a'), isEmpty);
  });

  test('each account sees only its own receipts and claim', () async {
    await complete('attempt-a', account: 'account-a');
    await complete('attempt-b', account: 'account-b');
    await store.saveClaim('account-a', 'claim-a', DateTime.utc(2026));
    expect(
      (await store.due(
        'account-a',
        DateTime.utc(2100),
      )).map((r) => r.attemptId),
      ['attempt-a'],
    );
    expect(await store.activeClaim('account-a'), 'claim-a');
    expect(await store.activeClaim('account-b'), isNull);
  });

  test('settled and backing-off receipts are not due', () async {
    await complete('attempt-1');
    await complete('attempt-2');
    await complete('attempt-3');
    final rows = await store.all('account-a');
    await store.settle('account-a', 'attempt-1', 'sent');
    await store.retryLater(rows[1], DateTime.utc(2100), 'transport');
    final due = await store.due('account-a', DateTime.utc(2099));
    expect(due.map((r) => r.attemptId), ['attempt-3']);
    final retried = (await store.all('account-a'))[1];
    expect([retried.attempts, retried.lastError], [1, 'transport']);
  });

  test('clearing learner data erases claims and receipts', () async {
    await complete('attempt-1');
    await store.saveClaim('account-a', 'claim-a', DateTime.utc(2026));
    await db.clearLearnerData();
    expect(await store.all('account-a'), isEmpty);
    expect(await store.activeClaim('account-a'), isNull);
  });

  test('a version 9 database gains both referral tables on upgrade', () async {
    final dir = await Directory.systemTemp.createTemp('czechify-v9-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.db');
    final current = AppDatabase.forTesting(NativeDatabase(file));
    await current.customSelect('SELECT 1').get();
    await current.close();
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('''
      DROP TABLE referral_claims;
      DROP TABLE referral_receipt_outbox;
      PRAGMA user_version = 9;
    ''');
    raw.close();

    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);
    final upgradedStore = ReferralStore(upgraded);
    await upgradedStore.saveClaim('account-a', 'claim-a', DateTime.utc(2026));
    expect(await upgradedStore.activeClaim('account-a'), 'claim-a');
    expect(await upgradedStore.all('account-a'), isEmpty);
  });
}
