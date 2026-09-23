import 'package:czechify/core/age_signals/play_age_signals_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Play channel wrapper: what reaches Play, and how its answers decode.
/// Release Android builds are the only ones that ask Play; everything else
/// is treated as unsupported, which the policy allows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.eminentsite.czechify/age_signals');
  final calls = <String>[];

  void answer(Object? Function(MethodCall call) reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return reply(call);
        });
  }

  setUp(calls.clear);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  final release = GooglePlayAgeSignalsService.forTesting(android: true);

  test('only release Android builds ask Play', () async {
    answer((_) => {'status': 'shared'});
    for (final service in [
      GooglePlayAgeSignalsService.forTesting(android: false),
      GooglePlayAgeSignalsService.forTesting(android: true, debugBuild: true),
    ]) {
      expect(
        (await service.requestAgeSignals()).status,
        AgeSignalsStatus.unsupported,
      );
    }
    expect(calls, isEmpty);
    await release.requestAgeSignals();
    expect(calls, ['requestAgeSignals']);
  });

  test('a shared signal carries its age band and parent approval', () async {
    answer(
      (_) => {
        'status': 'shared',
        'ageLower': 13,
        'ageUpper': 15,
        'significantChangeStatus': 'pending',
      },
    );
    final snapshot = await release.requestAgeSignals();
    expect(snapshot.status, AgeSignalsStatus.shared);
    expect([snapshot.ageLower, snapshot.ageUpper], [13, 15]);
    expect(snapshot.significantChangeStatus, SignificantChangeStatus.pending);
  });

  test('each status and approval Play reports is decoded', () async {
    for (final (raw, status) in [
      ('not_shared', AgeSignalsStatus.notShared),
      ('verification_required', AgeSignalsStatus.verificationRequired),
      ('something_new', AgeSignalsStatus.error),
    ]) {
      answer((_) => {'status': raw});
      expect((await release.requestAgeSignals()).status, status, reason: raw);
    }
    for (final (raw, change) in [
      ('approved', SignificantChangeStatus.approved),
      ('declined', SignificantChangeStatus.declined),
      ('unknown', null),
    ]) {
      answer((_) => {'status': 'shared', 'significantChangeStatus': raw});
      expect(
        (await release.requestAgeSignals()).significantChangeStatus,
        change,
        reason: raw,
      );
    }
    answer((_) => null);
    expect(
      (await release.requestAgeSignals()).status,
      AgeSignalsStatus.error,
      reason: 'no answer at all',
    );
  });

  test('a failed or missing channel reads as an error, never as allowed', () async {
    answer((_) => throw PlatformException(code: 'play_unavailable'));
    expect(
      (await release.requestAgeSignals()).status,
      AgeSignalsStatus.error,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(
      (await release.requestAgeSignals()).status,
      AgeSignalsStatus.error,
    );
    expect(
      evaluateAgeEligibility(
        const AgeSignalsSnapshot(status: AgeSignalsStatus.error),
      ).isAllowed,
      isFalse,
    );
  });

  test('the Play Store opens only on Android', () async {
    answer((_) => null);
    await GooglePlayAgeSignalsService.forTesting(
      android: false,
    ).openPlayStore();
    expect(calls, isEmpty);
    await release.openPlayStore();
    expect(calls, ['openPlayStore']);
  });

  test('an allowed decision says so', () {
    expect(
      const AgeEligibilityDecision(AgeEligibilityOutcome.allowed).isAllowed,
      isTrue,
    );
  });
}
