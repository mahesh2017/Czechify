import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/monetization/billing_flow.dart';
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
  bool anonymous = false,
  BillingState billing = const BillingState(
    storeAvailable: true,
    products: _products,
  ),
  FeatureEntitlement core = FeatureEntitlement.none,
}) async {
  final calls = <String>[];
  final now = DateTime.now().toUtc();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        checkoutEnabledProvider.overrideWith((_) async => checkout),
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

  testWidgets('with checkout off the screen offers nothing to buy', (
    tester,
  ) async {
    await _pump(tester, checkout: false);
    expect(
      find.text('Subscriptions are not available on this device yet.'),
      findsOneWidget,
    );
    expect(find.text('Subscribe'), findsNothing);
    expect(find.text('Restore purchases'), findsNothing);
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
}
