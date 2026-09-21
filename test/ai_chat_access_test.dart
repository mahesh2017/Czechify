import 'package:czechify/data/monetization/monetization_api.dart';
import 'package:czechify/data/monetization/monetization_repository.dart';
import 'package:czechify/data/monetization/snapshot_verifier.dart';
import 'package:czechify/domain/entities/curriculum_entitlement.dart';
import 'package:czechify/domain/entities/monetization_snapshot.dart';
import 'package:czechify/presentation/providers/billing_providers.dart';
import 'package:czechify/presentation/providers/monetization_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chat stays open to everyone until the server requires the AI
/// subscription; then only an active one in the verified snapshot opens new
/// conversations. Core, however complete, is not AI chat.
void main() {
  final now = DateTime.now().toUtc();
  final active = FeatureEntitlement(
    active: true,
    validUntil: now.add(const Duration(days: 20)),
    offlineValidUntil: now.add(const Duration(days: 7)),
  );

  Future<bool> access({
    required bool required,
    FeatureEntitlement ai = FeatureEntitlement.none,
    FeatureEntitlement core = FeatureEntitlement.none,
  }) async {
    final container = ProviderContainer(
      overrides: [
        monetizationConfigurationProvider.overrideWith(
          (_) async => MonetizationConfiguration(
            playCheckoutEnabled: true,
            coursePaywallEnabled: true,
            paidChatRequired: required,
          ),
        ),
        monetizationLoadProvider.overrideWith(
          (_) async => MonetizationLoad(
            VerifiedMonetizationDocument(
              MonetizationSnapshot(
                userId: 'account-a',
                revision: 1,
                verifiedAt: now,
                core: core,
                aiChat: ai,
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
    return container.read(aiChatAccessProvider.future);
  }

  test('before the server requires it, everyone may chat', () async {
    expect(await access(required: false), isTrue);
  });

  test('once required, chat needs an active AI subscription', () async {
    expect(await access(required: true), isFalse);
    expect(await access(required: true, ai: active), isTrue);
  });

  test('Core alone is not AI chat', () async {
    expect(await access(required: true, core: active), isFalse);
  });

  group('configuration', () {
    test('reads the paid-chat switch and the enforced turn limit', () async {
      final config =
          await MonetizationApi(
            (route, {required method, body, headers = const {}}) async =>
                const ApiResponse(200, {
                  'paid_chat_required': true,
                  'ai_daily_turn_limit': 12,
                }),
          ).fetchConfiguration();
      expect(config!.paidChatRequired, isTrue);
      expect(config.aiDailyTurnLimit, 12);
    });

    test('an older server that sends neither keeps chat open at 20', () async {
      final config =
          await MonetizationApi(
            (route, {required method, body, headers = const {}}) async =>
                const ApiResponse(200, {}),
          ).fetchConfiguration();
      expect(config!.paidChatRequired, isFalse);
      expect(config.aiDailyTurnLimit, 20);
    });

    test('a nonsensical limit is ignored', () async {
      for (final limit in [0, -3, '15', null]) {
        final config =
            await MonetizationApi(
              (route, {required method, body, headers = const {}}) async =>
                  ApiResponse(200, {'ai_daily_turn_limit': limit}),
            ).fetchConfiguration();
        expect(config!.aiDailyTurnLimit, 20, reason: '$limit');
      }
    });
  });
}
