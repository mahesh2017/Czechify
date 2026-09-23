import 'package:czechify/data/monetization/monetization_repository.dart';
import 'package:czechify/data/monetization/snapshot_verifier.dart';
import 'package:czechify/domain/entities/curriculum_entitlement.dart';
import 'package:czechify/domain/entities/monetization_snapshot.dart';
import 'package:czechify/presentation/providers/billing_providers.dart';
import 'package:czechify/presentation/providers/course_admission_providers.dart';
import 'package:czechify/presentation/providers/monetization_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Settings shows Subscriptions only once monetization applies to the account,
/// and then keeps it, so pausing new purchases never hides restore or
/// subscription management.
void main() {
  Future<bool> visible({
    bool supported = true,
    bool checkout = false,
    bool paywall = false,
    FeatureEntitlement core = FeatureEntitlement.none,
  }) async {
    final now = DateTime.now().toUtc();
    final container = ProviderContainer(
      overrides: [
        billingPlatformSupportedProvider.overrideWithValue(supported),
        checkoutEnabledProvider.overrideWith((_) async => checkout),
        coursePaywallEnabledProvider.overrideWith((_) async => paywall),
        monetizationLoadProvider.overrideWith(
          (_) async => MonetizationLoad(
            VerifiedMonetizationDocument(
              MonetizationSnapshot(
                userId: 'account-a',
                revision: 1,
                verifiedAt: now,
                core: core,
              ),
              const CurriculumEntitlement(unlockAll: false),
              now,
              'signed',
            ),
            offline: false,
            requiresReverification: false,
            now: now,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Settle the async switches the provider reads synchronously.
    final listener = container.listen(
      subscriptionsEntryVisibleProvider,
      (_, _) {},
    );
    addTearDown(listener.close);
    await container.read(checkoutEnabledProvider.future);
    await container.read(coursePaywallEnabledProvider.future);
    await container.read(monetizationLoadProvider.future);
    return container.read(subscriptionsEntryVisibleProvider);
  }

  final activeCore = FeatureEntitlement(
    active: true,
    validUntil: DateTime.now().toUtc().add(const Duration(days: 20)),
    offlineValidUntil: DateTime.now().toUtc().add(const Duration(days: 7)),
  );

  test('before launch nothing is shown', () async {
    expect(await visible(), isFalse);
  });

  test('an unsupported platform never shows it', () async {
    expect(await visible(supported: false, checkout: true), isFalse);
  });

  test('open checkout shows it', () async {
    expect(await visible(checkout: true), isTrue);
  });

  test('a live paywall keeps it while new purchases are paused', () async {
    expect(await visible(paywall: true), isTrue);
  });

  test(
    'a subscriber keeps restore and management with checkout paused',
    () async {
      expect(await visible(core: activeCore), isTrue);
    },
  );
}
