import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/monetization/billing_flow.dart';
import 'package:czechify/data/monetization/monetization_api.dart';
import 'package:czechify/data/monetization/monetization_repository.dart';
import 'package:czechify/data/monetization/snapshot_verifier.dart';
import 'package:czechify/data/monetization/store_adapter.dart';
import 'package:czechify/domain/entities/curriculum_entitlement.dart';
import 'package:czechify/domain/entities/monetization_snapshot.dart';
import 'package:czechify/l10n/app_localizations.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/presentation/providers/billing_providers.dart';
import 'package:czechify/presentation/providers/monetization_providers.dart';
import 'package:czechify/presentation/screens/settings/subscriptions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Billing extends BillingNotifier {
  _Billing(this.initial, this.calls);
  final BillingState initial;
  final List<String> calls;

  @override
  BillingState build() => initial;

  @override
  Future<void> buy(String productId) async => calls.add('buy:$productId');

  @override
  Future<void> restore() async => calls.add('restore');
}

User _user({required bool anonymous}) => User(
  id: 'account-a',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-09-01T00:00:00Z',
  isAnonymous: anonymous,
);

const _products = {
  'czechify_core': StoreProduct(
    id: 'czechify_core',
    price: '250 Kč',
    handle: 0,
  ),
  'czechify_ai': StoreProduct(id: 'czechify_ai', price: '150 Kč', handle: 0),
};

Future<List<String>> _pump(
  WidgetTester tester, {
  bool checkout = true,
  bool supported = true,
  bool anonymous = false,
  BillingState billing = const BillingState(
    storeAvailable: true,
    products: _products,
  ),
  FeatureEntitlement core = FeatureEntitlement.none,
  Set<String>? onSale,
}) async {
  final calls = <String>[];
  final now = DateTime.now().toUtc();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        billingPlatformSupportedProvider.overrideWithValue(supported),
        checkoutEnabledProvider.overrideWith((_) async => checkout),
        if (onSale != null)
          monetizationConfigurationProvider.overrideWith(
            (_) async => MonetizationConfiguration(
              playCheckoutEnabled: checkout,
              coursePaywallEnabled: false,
              productIds: onSale,
            ),
          ),
        accountUserProvider.overrideWith(
          (_) => Stream.value(_user(anonymous: anonymous)),
        ),
        billingProvider.overrideWith(() => _Billing(billing, calls)),
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
      child: MaterialApp(
        theme: lightTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SubscriptionsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets(
    'both subscriptions show Store prices and can be bought separately',
    (tester) async {
      final calls = await _pump(tester);
      expect(find.text('250 Kč / month'), findsOneWidget);
      expect(find.text('150 Kč / month'), findsOneWidget);
      expect(find.text('Not subscribed'), findsNWidgets(2));
      expect(
        find.textContaining('two separate monthly subscriptions'),
        findsOneWidget,
      );

      await tester.tap(find.text('Subscribe').first);
      await tester.scrollUntilVisible(find.text('Restore purchases'), 200);
      await tester.tap(find.text('Restore purchases'));
      expect(calls, ['buy:czechify_core', 'restore']);
    },
  );

  testWidgets('an anonymous account is asked to link before buying', (
    tester,
  ) async {
    final calls = await _pump(tester, anonymous: true);
    expect(find.text('Link your account to subscribe'), findsOneWidget);
    await tester.tap(find.text('Subscribe').first);
    await tester.scrollUntilVisible(find.text('Restore purchases'), 200);
    await tester.tap(find.text('Restore purchases'));
    expect(calls, isEmpty);
  });

  testWidgets(
    'an active Core subscription shows its end date, not a buy button',
    (tester) async {
      await _pump(
        tester,
        core: FeatureEntitlement(
          active: true,
          validUntil: DateTime.utc(2099, 1, 15, 12),
          offlineValidUntil: DateTime.utc(2099, 1, 8),
        ),
      );
      expect(find.textContaining('Active until'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
    },
  );

  testWidgets('a product switched off on the server is shown but not sold', (
    tester,
  ) async {
    final calls = await _pump(tester, onSale: {'czechify_core'});
    expect(find.text('Subscribe'), findsNWidgets(2));
    await tester.tap(find.text('Subscribe').last);
    await tester.tap(find.text('Subscribe').first);
    expect(calls, ['buy:czechify_core']);
  });

  testWidgets('with checkout off the screen offers nothing to buy', (
    tester,
  ) async {
    final calls = await _pump(tester, checkout: false);
    expect(find.text('Subscriptions are not available yet.'), findsOneWidget);
    await tester.tap(find.text('Subscribe').first);
    expect(calls, isEmpty);
    await tester.scrollUntilVisible(find.text('Restore purchases'), 200);
    await tester.tap(find.text('Restore purchases'));
    expect(calls, ['restore']);
    await tester.scrollUntilVisible(find.text('Manage in Google Play'), 200);
  });

  testWidgets('a missing Store price is said plainly and cannot be bought', (
    tester,
  ) async {
    final calls = await _pump(
      tester,
      billing: const BillingState(storeAvailable: true, products: {}),
    );
    expect(find.text('Price not available'), findsNWidgets(2));
    await tester.tap(find.text('Subscribe').first);
    expect(calls, isEmpty);
  });

  testWidgets('a purchase on another account shows how support can move it', (
    tester,
  ) async {
    await _pump(
      tester,
      billing: const BillingState(
        storeAvailable: true,
        products: _products,
        notice: BillingNotice.bindingMismatch,
        supportReference: '0b6f2c1e-4d3a-4f5b-9c8d-7e6f5a4b3c2d',
      ),
    );
    expect(
      find.text('Your reference: 0b6f2c1e-4d3a-4f5b-9c8d-7e6f5a4b3c2d'),
      findsOneWidget,
    );
    expect(find.textContaining('order number'), findsOneWidget);
    await tester.tap(find.text('Email support'));
    await tester.pump();
  });

  testWidgets('without a case there is no support reference', (tester) async {
    await _pump(
      tester,
      billing: const BillingState(
        storeAvailable: true,
        products: _products,
        notice: BillingNotice.bindingMismatch,
      ),
    );
    expect(find.text('Email support'), findsNothing);
  });

  testWidgets('purchase outcomes are announced', (tester) async {
    await _pump(
      tester,
      billing: const BillingState(
        storeAvailable: true,
        products: _products,
        notice: BillingNotice.bindingMismatch,
      ),
    );
    expect(
      find.textContaining('belongs to a different Czechify account'),
      findsOneWidget,
    );
  });
  testWidgets('unsupported platforms do not offer Google Play recovery', (
    tester,
  ) async {
    await _pump(tester, checkout: false, supported: false);
    expect(
      find.text('Subscriptions are not available on this device yet.'),
      findsOneWidget,
    );
    expect(find.text('Restore purchases'), findsNothing);
    expect(find.text('Manage in Google Play'), findsNothing);
  });
}
