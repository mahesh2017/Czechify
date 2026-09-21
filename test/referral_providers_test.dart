import 'package:czechify/data/monetization/monetization_repository.dart';
import 'package:czechify/presentation/providers/monetization_providers.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/monetization/monetization_api.dart';
import 'package:czechify/data/referrals/referral_api.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/referral_providers.dart';
import 'package:czechify/presentation/providers/sync_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Backend extends BackendService {
  @override
  String? userId = 'account-a';
  @override
  SupabaseClient? get client => null;
}

void main() {
  late AppDatabase db;
  late _Backend backend;
  late List<Map<String, Object?>> sent;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    backend = _Backend();
    sent = [];
  });
  tearDown(() => db.close());

  ProviderContainer container(
    ApiResponse Function() reply, {
    bool withApi = true,
    void Function()? duringCall,
    void Function()? snapshotLoaded,
  }) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        accountUserProvider.overrideWith((_) => const Stream.empty()),
        if (snapshotLoaded != null)
          monetizationLoadProvider.overrideWith((_) async {
            snapshotLoaded();
            return MonetizationLoad(
              null,
              offline: false,
              requiresReverification: false,
              now: DateTime.now(),
            );
          }),
        backendServiceProvider.overrideWithValue(backend),
        referralApiProvider.overrideWithValue(
          withApi
              ? ReferralApi((
                route, {
                required method,
                body,
                headers = const {},
              }) async {
                sent.add({'route': route, ...?body});
                duringCall?.call();
                return reply();
              })
              : null,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a successful claim is stored for the signed-in account', () async {
    final c = container(
      () =>
          const ApiResponse(201, {'claim_id': 'claim-1', 'status': 'claimed'}),
    );
    expect(await c.read(referralClaimProvider)(' abc123 '), isNull);
    expect(sent.single, {
      'route': 'referrals/claim',
      'campaign_id': 'a1-referral-v1',
      'code': 'ABC123',
      'attribution_source': 'manual',
    });
    expect(
      await c.read(referralStoreProvider).activeClaim('account-a'),
      'claim-1',
    );
  });

  test('a refusal returns its code and stores nothing', () async {
    final c = container(
      () => const ApiResponse(409, {'code': 'referral_already_claimed'}),
    );
    expect(
      await c.read(referralClaimProvider)('ABC'),
      'referral_already_claimed',
    );
    expect(
      await c.read(referralStoreProvider).activeClaim('account-a'),
      isNull,
    );
  });

  test('a claim answered after an account switch is not stored', () async {
    final c = container(
      () => const ApiResponse(201, {'claim_id': 'claim-1'}),
      duringCall: () => backend.userId = 'account-b',
    );
    expect(
      await c.read(referralClaimProvider)('ABC'),
      'verification_unavailable',
    );
    expect(
      await c.read(referralStoreProvider).activeClaim('account-a'),
      isNull,
    );
    expect(
      await c.read(referralStoreProvider).activeClaim('account-b'),
      isNull,
    );
  });

  test(
    'without a backend or an account there is nothing to claim or upload',
    () async {
      final offline = container(() => const ApiResponse(503), withApi: false);
      expect(
        await offline.read(referralClaimProvider)('ABC'),
        'verification_unavailable',
      );
      expect(offline.read(referralUploaderProvider), isNull);
      backend.userId = null;
      final signedOut = container(() => const ApiResponse(201));
      expect(
        await signedOut.read(referralClaimProvider)('ABC'),
        'verification_unavailable',
      );
      expect(sent, isEmpty);
    },
  );

  test('with a backend the uploader is built for the current session', () {
    final c = container(() => const ApiResponse(503));
    expect(c.read(referralUploaderProvider), isNotNull);
    expect(c.read(referralUploaderProvider)!.currentAccount(), 'account-a');
  });
  final recover = FutureProvider<String?>((ref) => recoverReferralClaim(ref));

  test(
    'recovers server claim after reinstall before collecting evidence',
    () async {
      final c = container(
        () => const ApiResponse(200, {
          'own_claim': {'claim_id': 'restored-claim', 'lessons_completed': 0},
        }),
      );
      expect(await c.read(recover.future), 'restored-claim');
      expect(
        await c.read(referralStoreProvider).activeClaim('account-a'),
        'restored-claim',
      );
    },
  );

  test('recovery cannot attach an old response after account switch', () async {
    final c = container(
      () => const ApiResponse(200, {
        'own_claim': {'claim_id': 'old-claim'},
      }),
      duringCall: () => backend.userId = 'account-b',
    );
    expect(await c.read(recover.future), isNull);
    expect(
      await c.read(referralStoreProvider).activeClaim('account-b'),
      isNull,
    );
    expect(
      await c.read(referralStoreProvider).activeClaim('account-a'),
      isNull,
    );
  });

  test(
    'offline local claim remains usable without another network call',
    () async {
      final c = container(() => throw StateError('offline'));
      await c
          .read(referralStoreProvider)
          .saveClaim('account-a', 'cached', DateTime.now());
      expect(await c.read(recover.future), 'cached');
      expect(sent, isEmpty);
    },
  );

  test('network failure during recovery leaves learning available', () async {
    final c = container(() => throw StateError('offline'));
    expect(await c.read(recover.future), isNull);
  });
  test(
    'reward status reloads signed entitlements instead of trusting status as access',
    () async {
      var loads = 0;
      final c = container(
        () => const ApiResponse(200, {'units_earned': 1}),
        snapshotLoaded: () => loads++,
      );
      await c.read(monetizationLoadProvider.future);
      expect(loads, 1);
      expect((await c.read(referralStatusProvider.future))?.unitsEarned, 1);
      await c.read(monetizationLoadProvider.future);
      expect(loads, 2);
    },
  );
}
