import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// One configuration fetch per account, shared by every switch: cohorts are
/// per account, so a switch fetches again. Lessons wait on this, so the fetch
/// is short; when the server cannot be reached the account's last answer on
/// this device applies (a paywall that was on stays on offline), and with no
/// answer ever received everything is off. Without a backend everything is off.
final monetizationConfigurationProvider =
    FutureProvider<MonetizationConfiguration>((ref) async {
      await ref.watch(backendInitProvider.future);
      ref.watch(accountUserProvider.select((user) => user.value?.id));
      final api = ref.watch(monetizationApiProvider);
      final account = ref.read(backendServiceProvider).userId;
      if (api == null || account == null) return MonetizationConfiguration.off;
      final key = 'monetization_configuration_v1:$account';
      final prefs = await SharedPreferences.getInstance();
      MonetizationConfiguration? fresh;
      try {
        fresh = await api.fetchConfiguration().timeout(
          const Duration(seconds: 3),
        );
      } on TimeoutException {
        fresh = null;
      }
      if (fresh != null) {
        await prefs.setString(
          key,
          jsonEncode({
            'checkout': fresh.playCheckoutEnabled,
            'paywall': fresh.coursePaywallEnabled,
            'referrals': fresh.referralClaimsEnabled,
            'paid_chat': fresh.paidChatRequired,
            'ai_turns': fresh.aiDailyTurnLimit,
          }),
        );
        return fresh;
      }
      try {
        final cached = jsonDecode(prefs.getString(key) ?? 'null');
        if (cached is Map) {
          return MonetizationConfiguration(
            playCheckoutEnabled: cached['checkout'] == true,
            coursePaywallEnabled: cached['paywall'] == true,
            referralClaimsEnabled: cached['referrals'] == true,
            paidChatRequired: cached['paid_chat'] == true,
            aiDailyTurnLimit: switch (cached['ai_turns']) {
              final int limit when limit > 0 => limit,
              _ => MonetizationConfiguration.defaultAiDailyTurnLimit,
            },
          );
        }
      } on FormatException {
        // An unreadable cache is no answer.
      }
      return MonetizationConfiguration.off;
    });

/// Whether this build may offer Play checkout at all. Any doubt reads as no.
final checkoutEnabledProvider = FutureProvider<bool>((ref) async {
  await ref.watch(backendInitProvider.future);
  if (!ref.watch(billingPlatformSupportedProvider)) return false;
  if (ref.watch(monetizationApiProvider) == null) return false;
  return checkoutPreview ||
      (await ref.watch(monetizationConfigurationProvider.future))
          .playCheckoutEnabled;
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

/// Shows the AI chat subscription requirement in staging builds before the
/// server requires it for a cohort. The server alone decides what it serves.
const paidChatPreview = bool.fromEnvironment('MONETIZATION_PAID_CHAT_PREVIEW');

/// Whether this account may start new tutor conversations: always, until
/// the server requires paid chat; after that only with an active AI chat
/// subscription in the verified snapshot. The server enforces the same rule;
/// this only decides what the chat screen offers.
final aiChatAccessProvider = FutureProvider<bool>((ref) async {
  final required =
      paidChatPreview ||
      (await ref.watch(monetizationConfigurationProvider.future))
          .paidChatRequired;
  if (!required) return true;
  final load = await ref.watch(monetizationLoadProvider.future);
  final snapshot = load.document?.snapshot;
  if (snapshot == null) return false;
  return snapshot.aiChat.isActiveAt(load.now, offline: load.offline);
});
