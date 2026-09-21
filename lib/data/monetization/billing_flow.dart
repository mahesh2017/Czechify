import 'dart:async';

import 'monetization_api.dart';
import 'store_adapter.dart';

/// What the subscriptions screen should tell the learner after the last
/// purchase or restore step.
enum BillingNotice {
  none,
  checkoutDisabled,
  linkedAccountRequired,
  storeUnavailable,
  paymentPending,
  verifying,
  provisioned,
  nothingToRestore,
  accountChanged,
  bindingMismatch,
  canceled,
  failed,
}

class BillingState {
  final bool storeAvailable;
  final Map<String, StoreProduct> products;
  final String? busyProductId;
  final bool restoring;
  final BillingNotice notice;

  const BillingState({
    this.storeAvailable = false,
    this.products = const {},
    this.busyProductId,
    this.restoring = false,
    this.notice = BillingNotice.none,
  });

  BillingState copyWith({
    bool? storeAvailable,
    Map<String, StoreProduct>? products,
    String? Function()? busyProductId,
    bool? restoring,
    BillingNotice? notice,
  }) => BillingState(
    storeAvailable: storeAvailable ?? this.storeAvailable,
    products: products ?? this.products,
    busyProductId: busyProductId != null ? busyProductId() : this.busyProductId,
    restoring: restoring ?? this.restoring,
    notice: notice ?? this.notice,
  );
}

/// Play subscription purchase and restore for one account.
///
/// Access is never inferred on the device. A purchase counts only after the
/// server verified it with Play; only then is the store transaction completed.
/// One instance belongs to one account: it is disposed on account change, and
/// a purchase started for another account is never verified under this one.
class BillingFlow {
  static const basePlans = {
    'czechify_core': 'monthly',
    'czechify_ai': 'monthly',
  };
  static const _maxPolls = 4;

  final MonetizationApi api;
  final StoreAdapter store;
  final String accountId;
  final String? Function() currentAccount;
  final void Function() onEntitlementsChanged;
  final void Function(BillingState) onState;
  final Future<void> Function(Duration) delay;
  final String Function() newIdempotencyKey;

  BillingState _state = const BillingState();
  final _intents = <String, ({String account, String id})>{};
  StreamSubscription<List<StorePurchase>>? _subscription;
  Future<void> _queue = Future.value();
  bool _disposed = false;
  bool _restoreFoundPurchase = false;

  BillingFlow({
    required this.api,
    required this.store,
    required this.accountId,
    required this.currentAccount,
    required this.onEntitlementsChanged,
    required this.onState,
    required this.newIdempotencyKey,
    Future<void> Function(Duration)? delay,
  }) : delay = delay ?? Future<void>.delayed;

  BillingState get state => _state;

  void _emit(BillingState next) {
    if (_disposed) return;
    _state = next;
    onState(next);
  }

  /// Listens to the store before anything can be bought, then loads prices.
  Future<void> start() async {
    _subscription = store.purchases.listen(
      (updates) => _queue = _queue.then((_) => _handle(updates)),
    );
    try {
      if (!await store.isAvailable()) {
        return _emit(_state.copyWith(storeAvailable: false));
      }
      final products = await store.products(basePlans);
      _emit(_state.copyWith(storeAvailable: true, products: products));
    } on Exception {
      _emit(_state.copyWith(storeAvailable: false));
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
  }

  Future<void> buy(
    String productId, {
    required bool linkedAccount,
    required bool checkoutEnabled,
  }) async {
    if (_state.busyProductId != null || _state.restoring) return;
    if (!checkoutEnabled) {
      return _emit(_state.copyWith(notice: BillingNotice.checkoutDisabled));
    }
    if (!linkedAccount) {
      return _emit(
        _state.copyWith(notice: BillingNotice.linkedAccountRequired),
      );
    }
    final product = _state.products[productId];
    if (product == null) {
      return _emit(_state.copyWith(notice: BillingNotice.storeUnavailable));
    }
    _emit(
      _state.copyWith(
        busyProductId: () => productId,
        notice: BillingNotice.none,
      ),
    );
    try {
      final intent = await api.createIntent(
        productId: productId,
        basePlanId: basePlans[productId]!,
        idempotencyKey: newIdempotencyKey(),
      );
      if (currentAccount() != accountId) {
        return _emit(_state.copyWith(notice: BillingNotice.accountChanged));
      }
      _intents[productId] = (account: accountId, id: intent.id);
      final launched = await store.buy(
        product,
        obfuscatedAccountId: intent.obfuscatedAccountId,
      );
      if (!launched) _emit(_state.copyWith(notice: BillingNotice.failed));
    } on BillingApiException catch (error) {
      _emit(_state.copyWith(notice: _noticeFor(error.code)));
    } on Exception {
      _emit(_state.copyWith(notice: BillingNotice.failed));
    } finally {
      _emit(_state.copyWith(busyProductId: () => null));
    }
  }

  /// Asks the store for this device's subscriptions; each one found is
  /// verified with the server, which decides whose it is.
  Future<void> restore() async {
    if (_state.busyProductId != null || _state.restoring) return;
    _restoreFoundPurchase = false;
    _emit(_state.copyWith(restoring: true, notice: BillingNotice.none));
    try {
      await store.restore();
      // Restored purchases arrive on the stream; let them finish first.
      await delay(const Duration(seconds: 2));
      await _queue;
      if (!_restoreFoundPurchase) {
        _emit(_state.copyWith(notice: BillingNotice.nothingToRestore));
      }
    } on Exception {
      _emit(_state.copyWith(notice: BillingNotice.failed));
    } finally {
      _emit(_state.copyWith(restoring: false));
    }
  }

  Future<void> _handle(List<StorePurchase> updates) async {
    for (final purchase in updates) {
      if (_disposed) return;
      if (!basePlans.containsKey(purchase.productId)) continue;
      switch (purchase.status) {
        case StorePurchaseStatus.pending:
          // Play has not been paid yet. Nothing is granted or completed.
          _emit(_state.copyWith(notice: BillingNotice.paymentPending));
        case StorePurchaseStatus.canceled:
          _emit(_state.copyWith(notice: BillingNotice.canceled));
        case StorePurchaseStatus.error:
          _emit(_state.copyWith(notice: BillingNotice.failed));
        case StorePurchaseStatus.purchased:
        case StorePurchaseStatus.restored:
          await _verify(purchase);
      }
    }
  }

  Future<void> _verify(StorePurchase purchase) async {
    final intent = _intents.remove(purchase.productId);
    // A purchase begun for another account must not be claimed by this one.
    if ((intent != null && intent.account != accountId) ||
        currentAccount() != accountId) {
      return _emit(_state.copyWith(notice: BillingNotice.accountChanged));
    }
    if (purchase.token.isEmpty) {
      return _emit(_state.copyWith(notice: BillingNotice.failed));
    }
    _restoreFoundPurchase = true;
    _emit(_state.copyWith(notice: BillingNotice.verifying));
    VerifyOutcome outcome;
    try {
      outcome = await api.verify(
        purchaseToken: purchase.token,
        productId: purchase.productId,
        restore: intent == null,
        intentId: intent?.id,
      );
      for (
        var polls = 0;
        outcome is PurchaseVerificationPending && polls < _maxPolls;
        polls++
      ) {
        await delay(outcome.retryAfter * (1 << polls));
        if (_disposed || currentAccount() != accountId) return;
        outcome = await api.status(outcome.verificationId);
      }
    } on Exception {
      return _emit(_state.copyWith(notice: BillingNotice.failed));
    }
    if (_disposed || currentAccount() != accountId) return;
    switch (outcome) {
      case PurchaseProvisioned(:final access, :final state):
        // Only now is the store transaction cleared. The server has already
        // acknowledged, so a failure here changes nothing.
        if (purchase.needsCompletion) {
          try {
            await store.complete(purchase);
          } on Exception {
            // Retried by the store on the next launch.
          }
        }
        onEntitlementsChanged();
        _emit(
          _state.copyWith(
            notice:
                access
                    ? BillingNotice.provisioned
                    : state == 'pending'
                    ? BillingNotice.paymentPending
                    : BillingNotice.nothingToRestore,
          ),
        );
      case PurchaseVerificationPending():
        // The server keeps verifying in the background.
        _emit(_state.copyWith(notice: BillingNotice.verifying));
      case PurchaseRejected(:final code):
        _emit(_state.copyWith(notice: _noticeFor(code)));
    }
  }

  static BillingNotice _noticeFor(String code) => switch (code) {
    'account_binding_mismatch' => BillingNotice.bindingMismatch,
    'linked_account_required' => BillingNotice.linkedAccountRequired,
    'product_unavailable' => BillingNotice.checkoutDisabled,
    _ => BillingNotice.failed,
  };
}
