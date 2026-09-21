import 'dart:async';

import 'package:czechify/data/monetization/billing_flow.dart';
import 'package:czechify/data/monetization/monetization_api.dart';
import 'package:czechify/data/monetization/store_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements StoreAdapter {
  final log = <String>[];
  final updates = StreamController<List<StorePurchase>>.broadcast();
  bool available = true;
  bool listened = false;
  List<StorePurchase> onRestore = const [];

  @override
  Stream<List<StorePurchase>> get purchases {
    listened = true;
    return updates.stream;
  }

  @override
  Future<bool> isAvailable() async {
    log.add('available:listened=$listened');
    return available;
  }

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
  Future<void> restore() async {
    log.add('restore');
    if (onRestore.isNotEmpty) updates.add(onRestore);
  }

  @override
  Future<void> complete(StorePurchase purchase) async =>
      log.add('complete:${purchase.token}');
}

StorePurchase _purchase(
  StorePurchaseStatus status, {
  String product = 'czechify_core',
  String token = 'token-1',
}) => StorePurchase(
  productId: product,
  token: token,
  status: status,
  needsCompletion: true,
  handle: token,
);

void main() {
  late _Store store;
  late List<ApiResponse> replies;
  late List<String> calls;
  late List<Duration> waits;
  late String? account;
  late int refreshes;
  late BillingFlow flow;
  Future<ApiResponse>? pendingReply;

  setUp(() async {
    store = _Store();
    replies = [];
    calls = [];
    waits = [];
    account = 'account-a';
    refreshes = 0;
    pendingReply = null;
    flow = BillingFlow(
      api: MonetizationApi((
        route, {
        required method,
        body,
        headers = const {},
      }) async {
        calls.add('$method $route ${body ?? ''}');
        store.log.add('api:$route');
        if (pendingReply != null) return pendingReply!;
        return replies.isEmpty ? const ApiResponse(503) : replies.removeAt(0);
      }),
      store: store,
      accountId: 'account-a',
      currentAccount: () => account,
      onEntitlementsChanged: () => refreshes++,
      onState: (_) {},
      newIdempotencyKey: () => 'key-1',
      delay: (d) async => waits.add(d),
    );
    await flow.start();
  });
  tearDown(() async {
    flow.dispose();
    await store.updates.close();
  });

  Future<void> settle() => Future<void>.delayed(
    Duration.zero,
  ).then((_) => Future<void>.delayed(Duration.zero));
  const intent = ApiResponse(201, {
    'intent_id': 'intent-1',
    'obfuscated_account_id': 'binding-a',
  });
  const provisioned = ApiResponse(200, {
    'status': 'provisioned',
    'verification_id': 'v-1',
    'state': 'active',
    'access': true,
  });

  test('listens to the store before anything else, then loads prices', () {
    expect(store.log.first, 'available:listened=true');
    expect(flow.state.storeAvailable, isTrue);
    expect(flow.state.products['czechify_core']!.price, '250 Kč');
  });

  test(
    'checkout is refused before any server or store call when off or unlinked',
    () async {
      await flow.buy(
        'czechify_core',
        linkedAccount: true,
        checkoutEnabled: false,
      );
      expect(flow.state.notice, BillingNotice.checkoutDisabled);
      await flow.buy(
        'czechify_core',
        linkedAccount: false,
        checkoutEnabled: true,
      );
      expect(flow.state.notice, BillingNotice.linkedAccountRequired);
      expect(calls, isEmpty);
    },
  );

  test(
    'a purchase is bound to the server account, verified, then completed',
    () async {
      replies.addAll([intent, provisioned]);
      await flow.buy(
        'czechify_core',
        linkedAccount: true,
        checkoutEnabled: true,
      );
      expect(store.log, contains('buy:czechify_core:binding-a'));
      expect(flow.state.busyProductId, isNull);

      store.updates.add([_purchase(StorePurchaseStatus.purchased)]);
      await settle();
      expect(calls.last, contains('purchases/verify'));
      expect(calls.last, contains('intent-1'));
      expect(calls.last, contains('source: purchase'));
      // The transaction is cleared only after the server provisioned access.
      final verifyAt = store.log.indexOf('api:purchases/verify');
      expect(store.log.indexOf('complete:token-1'), greaterThan(verifyAt));
      expect(refreshes, 1);
      expect(flow.state.notice, BillingNotice.provisioned);
    },
  );

  test('a pending payment is neither verified nor completed', () async {
    store.updates.add([_purchase(StorePurchaseStatus.pending)]);
    await settle();
    expect(calls, isEmpty);
    expect(store.log.where((l) => l.startsWith('complete')), isEmpty);
    expect(flow.state.notice, BillingNotice.paymentPending);
  });

  test(
    'slow verification polls with backoff and completes once provisioned',
    () async {
      replies.addAll([
        const ApiResponse(202, {
          'verification_id': 'v-1',
          'retry_after_seconds': 5,
        }),
        const ApiResponse(200, {'verification': 'pending', 'state': null}),
        const ApiResponse(200, {
          'verification': 'verified',
          'state': 'active',
          'valid_until': '2099-01-01T00:00:00Z',
        }),
      ]);
      store.updates.add([_purchase(StorePurchaseStatus.restored)]);
      await settle();
      expect(waits, [const Duration(seconds: 5), const Duration(seconds: 10)]);
      expect(calls.skip(1), everyElement(contains('purchases/status/v-1')));
      expect(store.log, contains('complete:token-1'));
      expect(flow.state.notice, BillingNotice.provisioned);
    },
  );

  test(
    'verification still pending after polling is left to the server',
    () async {
      replies.addAll([
        const ApiResponse(202, {'verification_id': 'v-1'}),
        for (var i = 0; i < 4; i++)
          const ApiResponse(200, {'verification': 'pending', 'state': null}),
      ]);
      store.updates.add([_purchase(StorePurchaseStatus.restored)]);
      await settle();
      expect(waits, hasLength(4));
      expect(store.log.where((l) => l.startsWith('complete')), isEmpty);
      expect(flow.state.notice, BillingNotice.verifying);
    },
  );

  test(
    'a token owned by another account is reported and not completed',
    () async {
      replies.add(const ApiResponse(403, {'code': 'account_binding_mismatch'}));
      store.updates.add([_purchase(StorePurchaseStatus.restored)]);
      await settle();
      expect(flow.state.notice, BillingNotice.bindingMismatch);
      expect(store.log.where((l) => l.startsWith('complete')), isEmpty);
      expect(refreshes, 0);
    },
  );

  test(
    'a purchase is never verified under a different signed-in account',
    () async {
      replies.add(intent);
      await flow.buy(
        'czechify_core',
        linkedAccount: true,
        checkoutEnabled: true,
      );
      account = 'account-b';
      store.updates.add([_purchase(StorePurchaseStatus.purchased)]);
      await settle();
      expect(calls.where((c) => c.contains('verify')), isEmpty);
      expect(flow.state.notice, BillingNotice.accountChanged);
    },
  );

  test('restore verifies each store purchase as a restore', () async {
    replies.add(provisioned);
    store.onRestore = [_purchase(StorePurchaseStatus.restored)];
    await flow.restore();
    expect(calls.single, contains('source: restore'));
    expect(calls.single, isNot(contains('intent_id')));
    expect(flow.state.notice, BillingNotice.provisioned);
    expect(flow.state.restoring, isFalse);
  });

  test('restore with nothing to restore says so', () async {
    await flow.restore();
    expect(flow.state.notice, BillingNotice.nothingToRestore);
  });

  test('other products and updates after disposal are ignored', () async {
    store.updates.add([
      _purchase(StorePurchaseStatus.purchased, product: 'someone_else'),
    ]);
    await settle();
    flow.dispose();
    store.updates.add([_purchase(StorePurchaseStatus.purchased)]);
    await settle();
    expect(calls, isEmpty);
  });

  test('a disposed flow cannot start checkout or restore', () async {
    flow.dispose();
    store.log.clear();
    await flow.start();
    await flow.buy('czechify_core', linkedAccount: true, checkoutEnabled: true);
    await flow.restore();
    expect(calls, isEmpty);
    expect(store.log, isEmpty);
  });

  test('a lagging account flow cannot create an intent or restore', () async {
    account = 'account-b';
    store.log.clear();
    await flow.buy('czechify_core', linkedAccount: true, checkoutEnabled: true);
    await flow.restore();
    expect(calls, isEmpty);
    expect(store.log, isEmpty);
    expect(flow.state.notice, BillingNotice.accountChanged);
  });

  test('disposal while creating an intent prevents opening Play', () async {
    final reply = Completer<ApiResponse>();
    pendingReply = reply.future;
    final buying = flow.buy(
      'czechify_core',
      linkedAccount: true,
      checkoutEnabled: true,
    );
    await settle();
    expect(calls, hasLength(1));
    flow.dispose();
    reply.complete(intent);
    await buying;
    expect(store.log.where((entry) => entry.startsWith('buy:')), isEmpty);
  });

  test(
    'a purchase-stream error is reported and later updates still work',
    () async {
      store.updates.addError(StateError('store disconnected'));
      await settle();
      expect(flow.state.notice, BillingNotice.failed);
      replies.add(provisioned);
      store.updates.add([_purchase(StorePurchaseStatus.restored)]);
      await settle();
      expect(flow.state.notice, BillingNotice.provisioned);
      expect(refreshes, 1);
    },
  );

  test('an unavailable store offers nothing to buy', () async {
    final offline = _Store()..available = false;
    final other = BillingFlow(
      api: MonetizationApi(
        (route, {required method, body, headers = const {}}) async =>
            const ApiResponse(503),
      ),
      store: offline,
      accountId: 'a',
      currentAccount: () => 'a',
      onEntitlementsChanged: () {},
      onState: (_) {},
      newIdempotencyKey: () => 'k',
    );
    addTearDown(other.dispose);
    await other.start();
    expect(other.state.storeAvailable, isFalse);
    expect(other.state.products, isEmpty);
  });
}
