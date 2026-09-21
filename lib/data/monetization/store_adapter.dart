import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// A subscription as the store sells it. [price] is the store's localized
/// text; the app never converts or hard-codes a price.
class StoreProduct {
  final String id;
  final String price;
  final Object handle;
  const StoreProduct({
    required this.id,
    required this.price,
    required this.handle,
  });
}

enum StorePurchaseStatus { pending, purchased, restored, canceled, error }

class StorePurchase {
  final String productId;
  final String token;
  final StorePurchaseStatus status;
  final bool needsCompletion;
  final Object handle;
  const StorePurchase({
    required this.productId,
    required this.token,
    required this.status,
    required this.needsCompletion,
    required this.handle,
  });
}

/// The store operations the billing flow needs. Implemented for Google Play;
/// fakes stand in for it in tests.
abstract interface class StoreAdapter {
  Stream<List<StorePurchase>> get purchases;
  Future<bool> isAvailable();
  Future<Map<String, StoreProduct>> products(Map<String, String> basePlans);

  /// Opens the store sheet. [obfuscatedAccountId] binds the purchase to the
  /// server's account reference.
  Future<bool> buy(StoreProduct product, {required String obfuscatedAccountId});
  Future<void> restore();

  /// Clears the store transaction. Called only after the server provisioned.
  Future<void> complete(StorePurchase purchase);
}

class PlayStoreAdapter implements StoreAdapter {
  final InAppPurchase _store;
  PlayStoreAdapter([InAppPurchase? store])
    : _store = store ?? InAppPurchase.instance;

  @override
  Stream<List<StorePurchase>> get purchases => _store.purchaseStream.map(
    (list) => [
      for (final p in list)
        StorePurchase(
          productId: p.productID,
          token: p.verificationData.serverVerificationData,
          status: switch (p.status) {
            PurchaseStatus.pending => StorePurchaseStatus.pending,
            PurchaseStatus.purchased => StorePurchaseStatus.purchased,
            PurchaseStatus.restored => StorePurchaseStatus.restored,
            PurchaseStatus.canceled => StorePurchaseStatus.canceled,
            PurchaseStatus.error => StorePurchaseStatus.error,
          },
          needsCompletion: p.pendingCompletePurchase,
          handle: p,
        ),
    ],
  );

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  /// One entry per product: its base plan without a promotional offer.
  @override
  Future<Map<String, StoreProduct>> products(
    Map<String, String> basePlans,
  ) async {
    final response = await _store.queryProductDetails(basePlans.keys.toSet());
    final result = <String, StoreProduct>{};
    for (final details in response.productDetails) {
      if (details is! GooglePlayProductDetails) continue;
      final index = details.subscriptionIndex;
      final offers = details.productDetails.subscriptionOfferDetails;
      if (index == null || offers == null || index >= offers.length) continue;
      final offer = offers[index];
      if (offer.basePlanId != basePlans[details.id] || offer.offerId != null) {
        continue;
      }
      result[details.id] = StoreProduct(
        id: details.id,
        price: details.price,
        handle: (details, offer.offerIdToken),
      );
    }
    return result;
  }

  @override
  Future<bool> buy(
    StoreProduct product, {
    required String obfuscatedAccountId,
  }) {
    final (details, offerToken) =
        product.handle as (GooglePlayProductDetails, String);
    return _store.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(
        productDetails: details,
        offerToken: offerToken,
        applicationUserName: obfuscatedAccountId,
      ),
    );
  }

  @override
  Future<void> restore() => _store.restorePurchases();

  @override
  Future<void> complete(StorePurchase purchase) =>
      _store.completePurchase(purchase.handle as PurchaseDetails);
}
