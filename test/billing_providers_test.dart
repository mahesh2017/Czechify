import 'dart:async';

import 'package:czechify/data/monetization/billing_flow.dart';
import 'package:czechify/data/monetization/monetization_api.dart';
import 'package:czechify/data/monetization/store_adapter.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/presentation/providers/billing_providers.dart';
import 'package:czechify/presentation/providers/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Backend extends BackendService {
  @override
  String? userId = 'account-a';
  @override
  SupabaseClient? get client => null;
}

class _Store implements StoreAdapter {
  final log = <String>[];
  final updates = StreamController<List<StorePurchase>>.broadcast();

  @override
  Stream<List<StorePurchase>> get purchases => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<Map<String, StoreProduct>> products(Map<String, String> plans) async =>
      {
        for (final id in plans.keys)
          id: StoreProduct(id: id, price: '250 Kč', handle: id),
      };
  @override
  Future<bool> buy(
    StoreProduct product, {
    required String obfuscatedAccountId,
  }) async {
    log.add('buy:${product.id}:$obfuscatedAccountId');
    return true;
  }

  @override
  Future<void> restore() async => log.add('restore');
  @override
  Future<void> complete(StorePurchase purchase) async {}
}

User _user({required bool anonymous}) => User(
  id: 'account-a',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-09-01T00:00:00Z',
  isAnonymous: anonymous,
);

MonetizationApi _api({bool checkout = true}) =>
    MonetizationApi((route, {required method, body, headers = const {}}) async {
      if (route == 'configuration') {
        return ApiResponse(200, {'play_checkout_enabled': checkout});
      }
      return const ApiResponse(201, {
        'intent_id': 'intent-1',
        'obfuscated_account_id': 'binding-a',
      });
    });

ProviderContainer _container({
  bool supported = true,
  MonetizationApi? api,
  bool apiMissing = false,
  User? user,
  _Store? store,
}) {
  final c = ProviderContainer(
    overrides: [
      backendServiceProvider.overrideWithValue(_Backend()),
      backendInitProvider.overrideWith((ref) async {}),
      billingPlatformSupportedProvider.overrideWithValue(supported),
      monetizationApiProvider.overrideWithValue(
        apiMissing ? null : api ?? _api(),
      ),
      accountUserProvider.overrideWith((ref) => Stream.value(user)),
      storeAdapterProvider.overrideWithValue(store ?? _Store()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('configuration', () {
    ProviderContainer withReply(Future<ApiResponse> Function() reply) {
      final c = ProviderContainer(
        overrides: [
          backendServiceProvider.overrideWithValue(_Backend()),
          backendInitProvider.overrideWith((ref) async {}),
          monetizationApiProvider.overrideWithValue(
            MonetizationApi(
              (route, {required method, body, headers = const {}}) => reply(),
            ),
          ),
          accountUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a fresh answer is used and remembered for this account', () async {
      final fresh = await withReply(
        () async => const ApiResponse(200, {'course_paywall_enabled': true}),
      ).read(monetizationConfigurationProvider.future);
      expect(fresh.coursePaywallEnabled, isTrue);
      expect(fresh.playCheckoutEnabled, isFalse);
      // Offline next time: the remembered answer still applies.
      final offline = await withReply(
        () => Future.error(Exception('offline')),
      ).read(monetizationConfigurationProvider.future);
      expect(offline.coursePaywallEnabled, isTrue);
    });

    test('the products on sale are read and remembered', () async {
      final fresh = await withReply(
        () async => const ApiResponse(200, {
          'play_checkout_enabled': true,
          'product_ids': ['czechify_core', 7, ''],
        }),
      ).read(monetizationConfigurationProvider.future);
      expect(fresh.productIds, {'czechify_core'});
      expect(fresh.offers('czechify_core'), isTrue);
      expect(fresh.offers('czechify_ai'), isFalse);
      final offline = await withReply(
        () => Future.error(Exception('offline')),
      ).read(monetizationConfigurationProvider.future);
      expect(offline.productIds, {'czechify_core'});
    });

    test('an older server that names no products offers them all', () async {
      final older = await withReply(
        () async => const ApiResponse(200, {'play_checkout_enabled': true}),
      ).read(monetizationConfigurationProvider.future);
      expect(older.productIds, isEmpty);
      expect(older.offers('czechify_ai'), isTrue);
    });

    test('a slow server does not hold lessons up', () async {
      final started = DateTime.now();
      final slow = await withReply(
        () => Completer<ApiResponse>().future,
      ).read(monetizationConfigurationProvider.future);
      expect(slow.coursePaywallEnabled, isFalse);
      expect(DateTime.now().difference(started).inSeconds, lessThan(5));
    });

    test('with no answer ever received everything is off', () async {
      final none = await withReply(
        () async => const ApiResponse(503),
      ).read(monetizationConfigurationProvider.future);
      expect(none.coursePaywallEnabled, isFalse);
      expect(none.playCheckoutEnabled, isFalse);
    });

    test('another account on the device does not inherit the answer', () async {
      await withReply(
        () async => const ApiResponse(200, {'course_paywall_enabled': true}),
      ).read(monetizationConfigurationProvider.future);
      final other = ProviderContainer(
        overrides: [
          backendServiceProvider.overrideWithValue(
            _Backend()..userId = 'account-b',
          ),
          backendInitProvider.overrideWith((ref) async {}),
          monetizationApiProvider.overrideWithValue(
            MonetizationApi(
              (route, {required method, body, headers = const {}}) =>
                  Future.error(Exception('offline')),
            ),
          ),
          accountUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(other.dispose);
      expect(
        (await other.read(
          monetizationConfigurationProvider.future,
        )).coursePaywallEnabled,
        isFalse,
      );
    });
  });

  test('checkout needs Android, a backend and the server switch', () async {
    expect(
      await _container(supported: false).read(checkoutEnabledProvider.future),
      isFalse,
    );
    expect(
      await _container(apiMissing: true).read(checkoutEnabledProvider.future),
      isFalse,
    );
    expect(
      await _container(
        api: _api(checkout: false),
      ).read(checkoutEnabledProvider.future),
      checkoutPreview,
    );
    expect(await _container().read(checkoutEnabledProvider.future), isTrue);
  });

  test('without a backend client there is no API', () {
    final c = ProviderContainer(
      overrides: [backendServiceProvider.overrideWithValue(_Backend())],
    );
    addTearDown(c.dispose);
    expect(c.read(monetizationApiProvider), isNull);
  });

  test(
    'a signed-in account gets a billing flow that loads Store prices',
    () async {
      final store = _Store();
      final c = _container(user: _user(anonymous: false), store: store);
      c.listen(billingProvider, (_, _) {});
      await c.read(accountUserProvider.future);
      await pumpEventQueue();
      expect(c.read(billingProvider).products.keys, hasLength(2));

      await c.read(billingProvider.notifier).buy('czechify_core');
      expect(store.log, ['buy:czechify_core:binding-a']);
      await c.read(billingProvider.notifier).restore();
      expect(store.log.last, 'restore');
    },
  );

  test('an anonymous account cannot start checkout', () async {
    final store = _Store();
    final c = _container(user: _user(anonymous: true), store: store);
    c.listen(billingProvider, (_, _) {});
    await c.read(accountUserProvider.future);
    await pumpEventQueue();
    await c.read(billingProvider.notifier).buy('czechify_core');
    expect(store.log, isEmpty);
    expect(c.read(billingProvider).notice, BillingNotice.linkedAccountRequired);
  });

  test('with nobody signed in billing stays idle', () async {
    final store = _Store();
    final c = _container(store: store);
    c.listen(billingProvider, (_, _) {});
    await c.read(accountUserProvider.future);
    await pumpEventQueue();
    await c.read(billingProvider.notifier).buy('czechify_core');
    await c.read(billingProvider.notifier).restore();
    expect(c.read(billingProvider).storeAvailable, isFalse);
    expect(store.log, isEmpty);
  });
}
