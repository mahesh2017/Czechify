import 'package:czechify/core/legal/legal_content.dart';
import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/repositories/consent_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The consent log is evidence, not state. These tests pin the properties that
/// make it usable as evidence under GDPR Article 7 — if any of them stops
/// holding, the log stops being able to demonstrate anything.
void main() {
  late AppDatabase db;
  late ConsentRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ConsentRepository(db, appVersion: '1.2.3');
  });

  tearDown(() => db.close());

  test('nothing is consented to by default', () async {
    // Consent must be an active choice. A missing row is not agreement.
    expect(
      await repo.isGranted(
        ConsentPurpose.voiceCloudProcessing,
        noticeVersion: kVoiceCloudConsentVersion,
      ),
      isFalse,
    );
  });

  test('a decision records the wording that was shown', () async {
    final row = await repo.record(
      purpose: ConsentPurpose.voiceCloudProcessing,
      granted: true,
      noticeVersion: kVoiceCloudConsentVersion,
    );
    expect(row.granted, isTrue);
    expect(row.noticeVersion, kVoiceCloudConsentVersion);
    expect(row.policyVersion, kPrivacyPolicyVersion);
    expect(row.appVersion, '1.2.3');
    // Self-describing UTC: readable as evidence without the writing code.
    expect(row.decidedAt, endsWith('Z'));
    expect(DateTime.parse(row.decidedAt).isUtc, isTrue);
  });

  test('a grant against older wording does not carry forward', () async {
    // The privacy policy promises materially changed terms are presented
    // again. A grant is evidence of agreement to what was actually read, so
    // an obsolete one reads as no grant and the learner is asked afresh.
    await repo.record(
      purpose: ConsentPurpose.voiceCloudProcessing,
      granted: true,
      noticeVersion: 'voice-cloud-v1',
    );

    expect(
      await repo.isGranted(
        ConsentPurpose.voiceCloudProcessing,
        noticeVersion: kVoiceCloudConsentVersion,
      ),
      isFalse,
    );

    // The obsolete decision is still in the log — it happened, and the log is
    // evidence, not state.
    final history = await repo.history(ConsentPurpose.voiceCloudProcessing);
    expect(history.single.noticeVersion, 'voice-cloud-v1');
    expect(history.single.granted, isTrue);
  });

  test('one account does not inherit another account\'s consent', () async {
    final ada = ConsentRepository(db, appVersion: '1.2.3', accountId: 'ada');
    final bob = ConsentRepository(db, appVersion: '1.2.3', accountId: 'bob');

    await ada.record(
      purpose: ConsentPurpose.voiceCloudProcessing,
      granted: true,
      noticeVersion: kVoiceCloudConsentVersion,
    );

    expect(
      await ada.isGranted(
        ConsentPurpose.voiceCloudProcessing,
        noticeVersion: kVoiceCloudConsentVersion,
      ),
      isTrue,
    );
    // Signing in as someone else used to inherit this — permission to send
    // voice to a cloud service, granted by a person Bob has never met.
    expect(
      await bob.isGranted(
        ConsentPurpose.voiceCloudProcessing,
        noticeVersion: kVoiceCloudConsentVersion,
      ),
      isFalse,
    );
  });

  test('a device-local learner is not the same as a signed-in one', () async {
    final local = ConsentRepository(db, appVersion: '1.2.3');
    final signedIn = ConsentRepository(db, appVersion: '1.2.3', accountId: 'x');

    await local.record(
      purpose: ConsentPurpose.voiceCloudProcessing,
      granted: true,
      noticeVersion: kVoiceCloudConsentVersion,
    );

    expect(
      await signedIn.isGranted(
        ConsentPurpose.voiceCloudProcessing,
        noticeVersion: kVoiceCloudConsentVersion,
      ),
      isFalse,
    );
  });

  test('withdrawal appends rather than erasing', () async {
    await repo.record(
      purpose: ConsentPurpose.voiceCloudProcessing,
      granted: true,
      noticeVersion: kVoiceCloudConsentVersion,
    );
    await repo.record(
      purpose: ConsentPurpose.voiceCloudProcessing,
      granted: false,
      noticeVersion: kVoiceCloudConsentVersion,
    );

    expect(
      await repo.isGranted(
        ConsentPurpose.voiceCloudProcessing,
        noticeVersion: kVoiceCloudConsentVersion,
      ),
      isFalse,
    );

    final history = await repo.history(ConsentPurpose.voiceCloudProcessing);
    expect(
      history.length,
      2,
      reason:
          'the original grant must survive withdrawal — an audit trail '
          'that can be erased is not an audit trail',
    );
    expect(history.any((r) => r.granted), isTrue);
  });

  test('the most recent decision wins, including re-granting', () async {
    for (final granted in [true, false, true]) {
      await repo.record(
        purpose: ConsentPurpose.voiceCloudProcessing,
        granted: granted,
        noticeVersion: kVoiceCloudConsentVersion,
      );
    }
    expect(
      await repo.isGranted(
        ConsentPurpose.voiceCloudProcessing,
        noticeVersion: kVoiceCloudConsentVersion,
      ),
      isTrue,
    );
    expect((await repo.history()).length, 3);
  });

  test('purposes are independent', () async {
    await repo.record(
      purpose: 'some_other_purpose',
      granted: true,
      noticeVersion: 'other-v1',
    );
    expect(
      await repo.isGranted(
        ConsentPurpose.voiceCloudProcessing,
        noticeVersion: kVoiceCloudConsentVersion,
      ),
      isFalse,
      reason: 'consent to one thing is never consent to another',
    );
  });

  test('history belongs to the account that made the decisions', () async {
    // The log deliberately survives an account switch, so an unscoped read
    // returns the previous learner's decisions to whoever signs in next —
    // their evidence, under someone else's name, in the export they share.
    // Whose grant counts as current and whose history this is are the same
    // question, and were being answered two different ways.
    final a = ConsentRepository(db, accountId: 'account-a');
    final b = ConsentRepository(db, accountId: 'account-b');
    await a.record(
      purpose: ConsentPurpose.voiceCloudProcessing,
      granted: true,
      noticeVersion: kVoiceCloudConsentVersion,
    );
    await b.record(
      purpose: ConsentPurpose.voiceCloudProcessing,
      granted: false,
      noticeVersion: kVoiceCloudConsentVersion,
    );

    expect((await b.history()).single.accountId, 'account-b');
    expect((await b.history()).single.granted, isFalse);
    expect((await a.history()).single.accountId, 'account-a');

    // Both rows are still there. Scoping the read never removes evidence.
    expect(await db.select(db.consentRecords).get(), hasLength(2));
  });

  test('records are written locally before they are synced', () async {
    final row = await repo.record(
      purpose: ConsentPurpose.voiceCloudProcessing,
      granted: true,
      noticeVersion: kVoiceCloudConsentVersion,
    );
    expect(row.synced, isFalse);
    expect((await repo.pendingSync()).map((r) => r.id), [row.id]);

    await repo.markSynced([row.id]);
    expect(await repo.pendingSync(), isEmpty);

    // Syncing must not alter the decision itself.
    final after = (await repo.history()).single;
    expect(after.granted, isTrue);
    expect(after.decidedAt, row.decidedAt);
    expect(after.policyVersion, row.policyVersion);
    expect(after.noticeVersion, row.noticeVersion);
  });
}
