import 'package:ceskina_pro/core/legal/legal_content.dart';
import 'package:ceskina_pro/data/database/database.dart';
import 'package:ceskina_pro/data/repositories/consent_repository.dart';
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
    expect(await repo.isGranted(ConsentPurpose.voiceCloudProcessing), isFalse);
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

    expect(await repo.isGranted(ConsentPurpose.voiceCloudProcessing), isFalse);

    final history = await repo.history(ConsentPurpose.voiceCloudProcessing);
    expect(
      history.length,
      2,
      reason: 'the original grant must survive withdrawal — an audit trail '
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
    expect(await repo.isGranted(ConsentPurpose.voiceCloudProcessing), isTrue);
    expect((await repo.history()).length, 3);
  });

  test('purposes are independent', () async {
    await repo.record(
      purpose: 'some_other_purpose',
      granted: true,
      noticeVersion: 'other-v1',
    );
    expect(
      await repo.isGranted(ConsentPurpose.voiceCloudProcessing),
      isFalse,
      reason: 'consent to one thing is never consent to another',
    );
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
