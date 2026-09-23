import 'dart:convert';

import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/account/account_service.dart';
import 'package:czechify/data/monetization/snapshot_verifier.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:czechify/domain/entities/curriculum_entitlement.dart';
import 'package:czechify/domain/entities/monetization_snapshot.dart';
import 'package:czechify/data/monetization/monetization_repository.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/monetization_providers.dart';
import 'package:czechify/presentation/screens/settings/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/localized_app.dart';

/// Deleting Czechify data does not cancel a Google Play subscription. The
/// learner is told before a renewing subscription is left behind.
class _Account extends Fake implements AccountService {
  final calls = <bool>[];
  int refusals;
  _Account({this.refusals = 0});

  @override
  bool get deletionNeedsPassword => false;

  @override
  Future<void> deleteAccountAndLocalData({
    String? password,
    bool subscriptionAcknowledged = false,
  }) async {
    calls.add(subscriptionAcknowledged);
    if (!subscriptionAcknowledged && refusals-- > 0) {
      throw const StoreSubscriptionActiveException();
    }
  }
}

void main() {
  group('deletion request', () {
    Future<List<String>> request(
      http.Response response, {
      bool acknowledged = false,
    }) async {
      final headers = <String>[];
      final functions = FunctionsClient(
        'https://example.supabase.co/functions/v1',
        const {},
        httpClient: MockClient((request) async {
          headers.add(
            '${request.method} ${request.url.path} '
            '${request.headers['x-confirm-account-deletion']} '
            '${request.headers['x-confirm-store-subscription']}',
          );
          return response;
        }),
      );
      addTearDown(functions.dispose);
      await requestAccountDeletion(
        functions,
        subscriptionAcknowledged: acknowledged,
        failed: 'Could not delete.',
      );
      return headers;
    }

    http.Response json(int status, Map<String, Object?> body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

    test(
      'a deletion confirms intent, and the subscription once told',
      () async {
        expect(await request(http.Response('', 204)), [
          'DELETE /functions/v1/account-data DELETE MY ACCOUNT null',
        ]);
        expect(await request(http.Response('', 204), acknowledged: true), [
          'DELETE /functions/v1/account-data DELETE MY ACCOUNT '
              'KEEPS RENEWING IN GOOGLE PLAY',
        ]);
      },
    );

    test('a renewing subscription stops the deletion to warn', () async {
      await expectLater(
        request(json(409, {'code': 'store_subscription_active'})),
        throwsA(isA<StoreSubscriptionActiveException>()),
      );
    });

    test('other refusals keep their messages', () async {
      await expectLater(
        request(json(401, {'code': 'reauthentication_required'})),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('sign in again'),
          ),
        ),
      );
      for (final response in [
        json(409, {'code': 'something_else'}),
        json(503, {'error': 'down'}),
        http.Response('', 200),
      ]) {
        await expectLater(
          request(response),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Could not delete.',
            ),
          ),
        );
      }
    });
  });

  group('account screen', () {
    Future<void> pump(
      WidgetTester tester,
      _Account account, {
      bool subscribed = false,
    }) async {
      tester.view.physicalSize = const Size(500, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now().toUtc();
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            accountUserProvider.overrideWith((ref) => Stream.value(null)),
            curriculumEntitlementProvider.overrideWith(
              (ref) async => CurriculumEntitlement.none,
            ),
            accountServiceProvider.overrideWithValue(account),
            monetizationLoadProvider.overrideWith(
              (_) async => MonetizationLoad(
                VerifiedMonetizationDocument(
                  MonetizationSnapshot(
                    userId: 'account-a',
                    revision: 1,
                    verifiedAt: now,
                    core:
                        subscribed
                            ? FeatureEntitlement(
                              active: true,
                              validUntil: now.add(const Duration(days: 20)),
                              offlineValidUntil: now.add(
                                const Duration(days: 7),
                              ),
                            )
                            : FeatureEntitlement.none,
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
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home: const AccountScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // A busy indicator spins while deletion runs, so this never settles.
    Future<void> settleFrames(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> startDeletion(WidgetTester tester) async {
      await tester.tap(find.text('Delete cloud account and local data'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DELETE MY ACCOUNT');
      await tester.tap(find.text('Continue'));
      await settleFrames(tester);
    }

    const warning = 'Your subscription keeps renewing';

    testWidgets('a subscriber is warned before anything is deleted', (
      tester,
    ) async {
      final account = _Account();
      await pump(tester, account, subscribed: true);
      await startDeletion(tester);
      expect(find.text(warning), findsOneWidget);
      expect(find.textContaining('Payments & subscriptions'), findsOneWidget);
      await tester.tap(find.text('Keep my account'));
      await settleFrames(tester);
      expect(account.calls, isEmpty);

      await startDeletion(tester);
      await tester.tap(find.text('Delete anyway'));
      await settleFrames(tester);
      expect(account.calls, [true]);
      expect(
        find.text('Cloud account and learner data deleted.'),
        findsOneWidget,
      );
    });

    testWidgets('without a subscription nothing extra is asked', (
      tester,
    ) async {
      final account = _Account();
      await pump(tester, account);
      await startDeletion(tester);
      expect(find.text(warning), findsNothing);
      expect(account.calls, [false]);
    });

    testWidgets('the server can still ask when this device did not know', (
      tester,
    ) async {
      final account = _Account(refusals: 1);
      await pump(tester, account);
      await startDeletion(tester);
      expect(find.text(warning), findsOneWidget);
      await tester.tap(find.text('Delete anyway'));
      await settleFrames(tester);
      expect(account.calls, [false, true]);
      expect(
        find.text('Cloud account and learner data deleted.'),
        findsOneWidget,
      );
    });

    testWidgets('keeping the account after the server asks deletes nothing', (
      tester,
    ) async {
      final account = _Account(refusals: 1);
      await pump(tester, account);
      await startDeletion(tester);
      await tester.tap(find.text('Keep my account'));
      await settleFrames(tester);
      expect(account.calls, [false]);
      expect(find.text('Your account was not deleted.'), findsOneWidget);
    });
  });
}
