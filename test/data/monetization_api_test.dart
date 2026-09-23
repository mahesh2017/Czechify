import 'package:czechify/data/monetization/monetization_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MonetizationApi api(ApiResponse reply, [List<Map<String, Object?>>? sent]) =>
      MonetizationApi((
        route, {
        required method,
        body,
        headers = const {},
      }) async {
        sent?.add({'route': route, 'method': method, 'body': body, ...headers});
        return reply;
      });

  test('checkout is off unless the server explicitly enables it', () async {
    expect(
      await api(
        const ApiResponse(200, {'play_checkout_enabled': true}),
      ).checkoutEnabled(),
      isTrue,
    );
    expect(
      await api(
        const ApiResponse(200, {'play_checkout_enabled': 'true'}),
      ).checkoutEnabled(),
      isFalse,
    );
    expect(await api(const ApiResponse(503)).checkoutEnabled(), isFalse);
    final throwing = MonetizationApi(
      (route, {required method, body, headers = const {}}) =>
          throw Exception('offline'),
    );
    expect(await throwing.checkoutEnabled(), isFalse);
  });

  test('an intent sends the idempotency key and returns the binding', () async {
    final sent = <Map<String, Object?>>[];
    final intent = await api(
      const ApiResponse(201, {'intent_id': 'i', 'obfuscated_account_id': 'b'}),
      sent,
    ).createIntent(
      productId: 'czechify_core',
      basePlanId: 'monthly',
      idempotencyKey: 'k',
    );
    expect([intent.id, intent.obfuscatedAccountId], ['i', 'b']);
    expect(sent.single['Idempotency-Key'], 'k');
    expect(sent.single['body'], {
      'product_id': 'czechify_core',
      'base_plan_id': 'monthly',
      'platform': 'android',
    });
    expect(
      () => api(
        const ApiResponse(403, {'code': 'linked_account_required'}),
      ).createIntent(
        productId: 'czechify_core',
        basePlanId: 'monthly',
        idempotencyKey: 'k',
      ),
      throwsA(
        isA<BillingApiException>().having(
          (e) => e.code,
          'code',
          'linked_account_required',
        ),
      ),
    );
  });

  test('verify omits a missing intent and maps each reply', () async {
    final sent = <Map<String, Object?>>[];
    final provisioned = await api(
      const ApiResponse(200, {
        'status': 'provisioned',
        'verification_id': 'v',
        'state': 'active',
        'access': true,
      }),
      sent,
    ).verify(purchaseToken: 't', productId: 'czechify_ai', restore: true);
    expect(sent.single['body'], {
      'purchase_token': 't',
      'product_id': 'czechify_ai',
      'source': 'restore',
    });
    expect(
      provisioned,
      isA<PurchaseProvisioned>().having((p) => p.access, 'access', isTrue),
    );

    final pending = await api(
      const ApiResponse(202, {
        'verification_id': 'v',
        'retry_after_seconds': 7,
      }),
    ).verify(
      purchaseToken: 't',
      productId: 'czechify_ai',
      restore: false,
      intentId: 'i',
    );
    expect(
      pending,
      isA<PurchaseVerificationPending>().having(
        (p) => p.retryAfter,
        'retry',
        const Duration(seconds: 7),
      ),
    );

    final rejected = await api(
      const ApiResponse(403, {'code': 'account_binding_mismatch'}),
    ).verify(purchaseToken: 't', productId: 'czechify_ai', restore: true);
    expect(
      rejected,
      isA<PurchaseRejected>().having(
        (p) => p.code,
        'code',
        'account_binding_mismatch',
      ),
    );
    expect(
      await api(
        const ApiResponse(500),
      ).verify(purchaseToken: 't', productId: 'czechify_ai', restore: true),
      isA<PurchaseRejected>().having(
        (p) => p.code,
        'code',
        'verification_unavailable',
      ),
    );
  });

  test('status reports pending, access and expiry', () async {
    expect(
      await api(
        const ApiResponse(200, {'verification': 'pending', 'state': null}),
      ).status('v'),
      isA<PurchaseVerificationPending>(),
    );
    expect(
      await api(
        const ApiResponse(200, {
          'verification': 'verified',
          'state': 'canceled',
          'valid_until': '2099-01-01T00:00:00Z',
        }),
      ).status('v'),
      isA<PurchaseProvisioned>().having((p) => p.access, 'access', isTrue),
    );
    expect(
      await api(
        const ApiResponse(200, {
          'verification': 'verified',
          'state': 'expired',
          'valid_until': '2020-01-01T00:00:00Z',
        }),
      ).status('v'),
      isA<PurchaseProvisioned>().having((p) => p.access, 'access', isFalse),
    );
    expect(
      await api(
        const ApiResponse(200, {
          'verification': 'account_binding_mismatch',
          'state': 'active',
        }),
      ).status('v'),
      isA<PurchaseRejected>(),
    );
  });
}
