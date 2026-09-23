import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/monetization/billing_flow.dart';
import '../../data/monetization/monetization_api.dart';
import '../../data/monetization/store_adapter.dart';
import 'account_providers.dart';
import 'monetization_providers.dart';
import 'sync_providers.dart';

/// Shows the subscriptions entry in internal and staging builds before the
/// server enables checkout for a cohort. It only reveals the screen: the
/// server still refuses disabled products.
const checkoutPreview = bool.fromEnvironment('MONETIZATION_CHECKOUT_PREVIEW');

/// Play Billing is the only store integrated so far.
final billingPlatformSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

final monetizationApiProvider = Provider<MonetizationApi?>((ref) {
  final client = ref.watch(backendServiceProvider).client;
  return client == null
      ? null
      : MonetizationApi(supabaseMonetizationCall(client));
});

final storeAdapterProvider = Provider<StoreAdapter>(
  (ref) => PlayStoreAdapter(),
);

/// Whether this build may offer Play checkout at all. Any doubt reads as no.
final checkoutEnabledProvider = FutureProvider<bool>((ref) async {
  await ref.watch(backendInitProvider.future);
  if (!ref.watch(billingPlatformSupportedProvider)) return false;
  final api = ref.watch(monetizationApiProvider);
  if (api == null) return false;
  return checkoutPreview || await api.checkoutEnabled();
});

final billingProvider =
    NotifierProvider.autoDispose<BillingNotifier, BillingState>(
      BillingNotifier.new,
    );

/// One [BillingFlow] per signed-in account; an account change rebuilds it,
/// so a late store result cannot be verified under the next account.
class BillingNotifier extends Notifier<BillingState> {
  BillingFlow? _flow;

  @override
  BillingState build() {
    // Never keep the previous account's (disposed) flow reachable.
    _flow = null;
    final user = ref.watch(accountUserProvider).value;
    final api = ref.watch(monetizationApiProvider);
    if (user == null ||
        api == null ||
        !ref.watch(billingPlatformSupportedProvider)) {
      return const BillingState();
    }
    final flow = BillingFlow(
      api: api,
      store: ref.watch(storeAdapterProvider),
      accountId: user.id,
      currentAccount: () => ref.read(backendServiceProvider).userId,
      onEntitlementsChanged: () => ref.invalidate(monetizationLoadProvider),
      onState: (next) => state = next,
      newIdempotencyKey: () => const Uuid().v4(),
    );
    _flow = flow;
    ref.onDispose(flow.dispose);
    Future.microtask(flow.start);
    return flow.state;
  }

  Future<void> buy(String productId) async {
    final flow = _flow;
    if (flow == null) return;
    final user = ref.read(accountUserProvider).value;
    await flow.buy(
      productId,
      linkedAccount: user != null && !user.isAnonymous,
      checkoutEnabled: await ref.read(checkoutEnabledProvider.future),
    );
  }

  Future<void> restore() async => _flow?.restore();
}
