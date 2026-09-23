import 'dart:async';

import 'package:czechify/data/monetization/store_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Stands in for the plugin so the adapter's Play-specific choices (which
/// offer, which token, which account reference) are tested without Play.
class _FakeInAppPurchase implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  final List<PurchaseParam> bought = [];
  final List<PurchaseDetails> completed = [];
  int restores = 0;
  List<ProductDetails> catalogue = const [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [
      for (final p in catalogue)
        if (identifiers.contains(p.id)) p,
    ],
    notFoundIDs: const [],
  );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought.add(purchaseParam);
    return true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async =>
      restores++;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async =>
      completed.add(purchase);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SubscriptionOfferDetailsWrapper _offer(
  String basePlan,
  String token, {
  String? offerId,
  String price = '250,00 Kč',
}) => SubscriptionOfferDetailsWrapper(
  basePlanId: basePlan,
  offerId: offerId,
  offerTags: const [],
  offerIdToken: token,
  pricingPhases: [
    PricingPhaseWrapper(
      billingCycleCount: 0,
      billingPeriod: 'P1M',
      formattedPrice: price,
      priceAmountMicros: 250000000,
      priceCurrencyCode: 'CZK',
      recurrenceMode: RecurrenceMode.infiniteRecurring,
    ),
  ],
);

List<GooglePlayProductDetails> _product(
  String id,
  List<SubscriptionOfferDetailsWrapper> offers,
) => GooglePlayProductDetails.fromProductDetails(
  ProductDetailsWrapper(
    description: '',
    name: id,
    productId: id,
    productType: ProductType.subs,
    subscriptionOfferDetails: offers,
    title: id,
  ),
);

void main() {
  late _FakeInAppPurchase plugin;
  late PlayStoreAdapter adapter;

  setUp(() {
    plugin =
        _FakeInAppPurchase()
          ..catalogue = [
            ..._product('czechify_core', [
              _offer('monthly', 'intro-token', offerId: 'intro', price: '0 Kč'),
              _offer('yearly', 'yearly-token', price: '2 500,00 Kč'),
              _offer('monthly', 'base-token'),
            ]),
            ..._product('czechify_ai', [
              _offer('monthly', 'ai-token', price: '150,00 Kč'),
            ]),
          ];
    adapter = PlayStoreAdapter(plugin);
  });

  test(
    'only the configured base plan without a promotion is offered',
    () async {
      final products = await adapter.products({
        'czechify_core': 'monthly',
        'czechify_ai': 'monthly',
      });
      expect(products.keys, unorderedEquals(['czechify_core', 'czechify_ai']));
      expect(products['czechify_core']!.price, '250,00 Kč');
      expect(products['czechify_ai']!.price, '150,00 Kč');
    },
  );

  test(
    'a purchase carries the base-plan offer and the server account reference',
    () async {
      final products = await adapter.products({'czechify_core': 'monthly'});
      expect(
        await adapter.buy(
          products['czechify_core']!,
          obfuscatedAccountId: 'binding-a',
        ),
        isTrue,
      );
      final param = plugin.bought.single as GooglePlayPurchaseParam;
      expect(param.offerToken, 'base-token');
      expect(param.applicationUserName, 'binding-a');
      expect(param.productDetails.id, 'czechify_core');
    },
  );

  test('a product without the configured plan is left out', () async {
    expect(await adapter.products({'czechify_core': 'weekly'}), isEmpty);
  });

  test('store updates map every status and keep the purchase token', () async {
    final seen = <StorePurchase>[];
    final subscription = adapter.purchases.listen(seen.addAll);
    addTearDown(subscription.cancel);
    PurchaseDetails details(PurchaseStatus status) => PurchaseDetails(
      productID: 'czechify_core',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: 'play-token',
        source: 'google_play',
      ),
      transactionDate: null,
      status: status,
    )..pendingCompletePurchase = status == PurchaseStatus.purchased;
    plugin.updates.add([for (final s in PurchaseStatus.values) details(s)]);
    await Future<void>.delayed(Duration.zero);
    expect(seen.map((p) => p.status), [
      StorePurchaseStatus.pending,
      StorePurchaseStatus.purchased,
      StorePurchaseStatus.error,
      StorePurchaseStatus.restored,
      StorePurchaseStatus.canceled,
    ]);
    expect(seen.every((p) => p.token == 'play-token'), isTrue);
    expect(seen[1].needsCompletion, isTrue);

    await adapter.complete(seen[1]);
    await adapter.restore();
    expect(plugin.completed.single.status, PurchaseStatus.purchased);
    expect(plugin.restores, 1);
    expect(await adapter.isAvailable(), isTrue);
  });
}
