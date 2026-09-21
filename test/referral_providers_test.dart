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
  }) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
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
}
