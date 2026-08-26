import 'package:ceskina_pro/core/legal/legal_content.dart';
import 'package:ceskina_pro/data/database/database.dart';
import 'package:ceskina_pro/data/repositories/consent_repository.dart';
import 'package:ceskina_pro/presentation/providers/database_providers.dart';
import 'package:ceskina_pro/presentation/widgets/common/cloud_speech_consent.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Consent is a record, not a prompt. It is asked in two places — Settings,
/// and the moment a learner's phone turns out not to recognise Czech — and
/// both have to ask the same thing and write the same row.
void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() async => database.close());

  Future<bool?> openDialog(WidgetTester tester) async {
    bool? granted;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: Consumer(
            builder:
                (context, ref, _) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed:
                          () async =>
                              granted = await requestCloudSpeechConsent(
                                context,
                                ref,
                              ),
                      child: const Text('ask'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    return granted;
  }

  testWidgets('the ask names where the recording goes and who processes it', (
    tester,
  ) async {
    await openDialog(tester);

    expect(find.text('Allow cloud speech?'), findsOneWidget);
    // GDPR Art. 13 makes the recipient and the destination part of what is
    // being agreed to, so neither may be dropped from this wording.
    expect(find.textContaining('OpenAI'), findsOneWidget);
    expect(find.textContaining('United States'), findsOneWidget);
    expect(find.textContaining('does not store the recording'), findsOneWidget);
    expect(find.textContaining('up to 30 days'), findsOneWidget);
    // Consent has to be as easy to withdraw as to give, and this states so.
    expect(find.textContaining('switched off at any time'), findsOneWidget);
    expect(find.textContaining('at least 16'), findsOneWidget);
  });

  testWidgets('accepting records the consent against the notice version', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.tap(find.text('Allow cloud speech'));
    await tester.pumpAndSettle();

    final repo = ConsentRepository(database);
    expect(await repo.isGranted(ConsentPurpose.voiceCloudProcessing), isTrue);

    // The version is the evidence of *what* was agreed to. Without it a later
    // change to the wording silently reinterprets an old agreement.
    final rows = await database.select(database.consentRecords).get();
    expect(rows, hasLength(1));
    expect(rows.single.noticeVersion, kVoiceCloudConsentVersion);
    expect(rows.single.granted, isTrue);
  });

  testWidgets('declining records nothing and reports refusal', (tester) async {
    bool? granted;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: Consumer(
            builder:
                (context, ref, _) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed:
                          () async =>
                              granted = await requestCloudSpeechConsent(
                                context,
                                ref,
                              ),
                      child: const Text('ask'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(granted, isFalse);
    // Refusing is not a decision worth storing as one — nothing was agreed.
    expect(await database.select(database.consentRecords).get(), isEmpty);
  });
}
