import 'package:supabase_flutter/supabase_flutter.dart';

/// One `monetization-api` reply: HTTP status and the JSON object, if any.
class ApiResponse {
  final int status;
  final Map<String, Object?> body;
  const ApiResponse(this.status, [this.body = const {}]);

  String? get code => body['code'] as String?;
}

typedef ApiCall =
    Future<ApiResponse> Function(
      String route, {
      required String method,
      Map<String, Object?>? body,
      Map<String, String> headers,
    });

/// Calls the deployed function with the current session. Non-2xx replies come
/// back as responses, not exceptions, so callers can read the stable `code`.
ApiCall supabaseMonetizationCall(SupabaseClient client) => (
  route, {
  required method,
  body,
  headers = const {},
}) async {
  try {
    final response = await client.functions.invoke(
      'monetization-api/$route',
      method: method == 'GET' ? HttpMethod.get : HttpMethod.post,
      body: body,
      headers: headers,
    );
    return ApiResponse(response.status, _object(response.data));
  } on FunctionException catch (error) {
    return ApiResponse(error.status, _object(error.details));
  }
};

Map<String, Object?> _object(Object? data) =>
    data is Map ? Map<String, Object?>.from(data) : const {};

/// Server activation switches. Only `true` from the server turns one on.
class MonetizationConfiguration {
  final bool playCheckoutEnabled;
  final bool coursePaywallEnabled;
  final bool referralClaimsEnabled;

  /// Whether the AI tutor needs the AI chat subscription.
  final bool paidChatRequired;

  /// Tutor turns per day on the AI chat subscription, as the server enforces.
  final int aiDailyTurnLimit;

  /// Products on sale now. Empty when the server did not say (an older
  /// server, or a cached answer from before it did): every product is then
  /// offered and the server still refuses one that is off.
  final Set<String> productIds;

  const MonetizationConfiguration({
    required this.playCheckoutEnabled,
    required this.coursePaywallEnabled,
    this.referralClaimsEnabled = false,
    this.paidChatRequired = false,
    this.aiDailyTurnLimit = defaultAiDailyTurnLimit,
    this.productIds = const {},
  });

  /// Whether checkout may offer [productId].
  bool offers(String productId) =>
      productIds.isEmpty || productIds.contains(productId);

  static const defaultAiDailyTurnLimit = 20;

  static const off = MonetizationConfiguration(
    playCheckoutEnabled: false,
    coursePaywallEnabled: false,
  );
}

class PurchaseIntent {
  final String id;
  final String obfuscatedAccountId;
  const PurchaseIntent(this.id, this.obfuscatedAccountId);
}

/// Why the server would not start or accept a purchase. Stable API codes.
class BillingApiException implements Exception {
  final String code;
  const BillingApiException(this.code);

  @override
  String toString() => 'BillingApiException: $code';
}

sealed class VerifyOutcome {
  const VerifyOutcome();
}

/// The server committed Play's state. [access] is false for a purchase Play
/// still reports as pending payment.
class PurchaseProvisioned extends VerifyOutcome {
  final String verificationId;
  final String state;
  final bool access;
  const PurchaseProvisioned(this.verificationId, this.state, this.access);
}

/// Accepted, but Play has not answered yet; poll [verificationId].
class PurchaseVerificationPending extends VerifyOutcome {
  final String verificationId;
  final Duration retryAfter;
  const PurchaseVerificationPending(this.verificationId, this.retryAfter);
}

class PurchaseRejected extends VerifyOutcome {
  final String code;

  /// Support's reference when the purchase belongs to another account and a
  /// recovery case was opened for this one.
  final String? recoveryCaseId;
  const PurchaseRejected(this.code, [this.recoveryCaseId]);
}

/// The existing-user migration as it applies to this account.
class LegacyMigrationStatus {
  final DateTime cutoffAt;
  final DateTime graceEndsAt;
  final DateTime claimWindowEndsAt;

  /// Whether the account existed before the cutoff.
  final bool eligible;
  final bool claimWindowOpen;

  /// Units this account keeps for good from the migration.
  final List<int> legacyUnitIds;

  /// This account's one offline claim, once made.
  final LegacyClaim? claim;

  const LegacyMigrationStatus({
    required this.cutoffAt,
    required this.graceEndsAt,
    required this.claimWindowEndsAt,
    required this.eligible,
    required this.claimWindowOpen,
    required this.legacyUnitIds,
    this.claim,
  });

  /// Whether this device may still send its one claim.
  bool get canClaim => eligible && claimWindowOpen && claim == null;
}

/// An offline claim's result: `applied`, `needs_review` or `rejected`.
class LegacyClaim {
  final String status;
  final List<int> unitIds;
  const LegacyClaim(this.status, this.unitIds);

  static LegacyClaim? parse(Object? value) {
    if (value is! Map) return null;
    final status = value['status'];
    if (status is! String) return null;
    return LegacyClaim(status, _unitIds(value['unit_ids']));
  }
}

/// Why the server refused a legacy claim. Stable API codes.
class LegacyClaimException implements Exception {
  final String code;
  const LegacyClaimException(this.code);

  @override
  String toString() => 'LegacyClaimException: $code';
}

/// Product IDs from the server's configuration; anything else is ignored.
Set<String> productIdSet(Object? value) => {
  if (value is List)
    for (final id in value)
      if (id is String && id.isNotEmpty) id,
};

List<int> _unitIds(Object? value) =>
    value is List
        ? [
          for (final id in value)
            if (id is int) id,
        ]
        : const [];

class MonetizationApi {
  final ApiCall call;
  const MonetizationApi(this.call);

  /// The server's activation switches for this account's cohort, or null when
  /// the server could not be asked. Only `true` turns a switch on.
  Future<MonetizationConfiguration?> fetchConfiguration() async {
    try {
      final response = await call('configuration', method: 'GET');
      if (response.status != 200) return null;
      return MonetizationConfiguration(
        playCheckoutEnabled: response.body['play_checkout_enabled'] == true,
        coursePaywallEnabled: response.body['course_paywall_enabled'] == true,
        referralClaimsEnabled: response.body['referral_claims_enabled'] == true,
        paidChatRequired: response.body['paid_chat_required'] == true,
        aiDailyTurnLimit: switch (response.body['ai_daily_turn_limit']) {
          final int limit when limit > 0 => limit,
          _ => MonetizationConfiguration.defaultAiDailyTurnLimit,
        },
        productIds: productIdSet(response.body['product_ids']),
      );
    } on Exception {
      return null;
    }
  }

  /// As [fetchConfiguration], with every switch off when it fails: a paywall
  /// must never appear by accident.
  Future<MonetizationConfiguration> configuration() async =>
      await fetchConfiguration() ?? MonetizationConfiguration.off;

  /// Whether Play checkout is switched on for this account's cohort.
  Future<bool> checkoutEnabled() async =>
      (await configuration()).playCheckoutEnabled;

  Future<PurchaseIntent> createIntent({
    required String productId,
    required String basePlanId,
    required String idempotencyKey,
  }) async {
    final response = await call(
      'purchase-intents',
      method: 'POST',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'product_id': productId,
        'base_plan_id': basePlanId,
        'platform': 'android',
      },
    );
    final id = response.body['intent_id'];
    final account = response.body['obfuscated_account_id'];
    if (response.status == 201 && id is String && account is String) {
      return PurchaseIntent(id, account);
    }
    throw BillingApiException(response.code ?? 'verification_unavailable');
  }

  Future<VerifyOutcome> verify({
    required String purchaseToken,
    required String productId,
    required bool restore,
    String? intentId,
  }) async {
    final response = await call(
      'purchases/verify',
      method: 'POST',
      body: {
        'purchase_token': purchaseToken,
        'product_id': productId,
        'source': restore ? 'restore' : 'purchase',
        if (intentId != null) 'intent_id': intentId,
      },
    );
    return _outcome(response);
  }

  /// Polls a pending verification. A still-pending one stays pending.
  Future<VerifyOutcome> status(String verificationId) async {
    final response = await call(
      'purchases/status/$verificationId',
      method: 'GET',
    );
    if (response.status != 200) return _outcome(response);
    final verification = response.body['verification'];
    final state = response.body['state'];
    if (verification == 'pending' || state is! String) {
      return PurchaseVerificationPending(
        verificationId,
        const Duration(seconds: 5),
      );
    }
    if (verification != 'verified') {
      return PurchaseRejected(verification as String? ?? 'unknown');
    }
    final validUntil = DateTime.tryParse(
      response.body['valid_until'] as String? ?? '',
    );
    final access =
        const {'active', 'in_grace_period', 'canceled'}.contains(state) &&
        validUntil != null &&
        validUntil.isAfter(DateTime.now());
    return PurchaseProvisioned(verificationId, state, access);
  }

  /// The applied existing-user migration for this account, or null when
  /// there is none or the server could not say. An older server without the
  /// route counts as none.
  Future<LegacyMigrationStatus?> fetchLegacyStatus() async {
    try {
      final response = await call('legacy/status', method: 'GET');
      final body = response.body;
      if (response.status != 200 || body['available'] != true) return null;
      final cutoff = DateTime.tryParse(body['cutoff_at'] as String? ?? '');
      final grace = DateTime.tryParse(body['grace_ends_at'] as String? ?? '');
      final window = DateTime.tryParse(
        body['claim_window_ends_at'] as String? ?? '',
      );
      if (cutoff == null || grace == null || window == null) return null;
      return LegacyMigrationStatus(
        cutoffAt: cutoff,
        graceEndsAt: grace,
        claimWindowEndsAt: window,
        eligible: body['eligible'] == true,
        claimWindowOpen: body['claim_window_open'] == true,
        legacyUnitIds: _unitIds(body['legacy_unit_ids']),
        claim: LegacyClaim.parse(body['claim']),
      );
    } on Exception {
      return null;
    }
  }

  /// Sends this device's record of lessons from before the cutoff. The
  /// server decides the units; throws [LegacyClaimException] when it refuses.
  Future<LegacyClaim> submitLegacyClaim({
    required Iterable<int> completedLessonIds,
    required Iterable<int> attemptedLessonIds,
  }) async {
    final response = await call(
      'legacy/claim',
      method: 'POST',
      body: {
        'completed_lesson_ids': completedLessonIds.toList(),
        'attempted_lesson_ids': attemptedLessonIds.toList(),
      },
    );
    final claim = LegacyClaim.parse(response.body);
    if (response.status == 200 && claim != null) return claim;
    throw LegacyClaimException(response.code ?? 'verification_unavailable');
  }

  VerifyOutcome _outcome(ApiResponse response) {
    final id = response.body['verification_id'];
    if (response.status == 200 &&
        response.body['status'] == 'provisioned' &&
        id is String) {
      return PurchaseProvisioned(
        id,
        response.body['state'] as String? ?? 'unknown',
        response.body['access'] == true,
      );
    }
    if (response.status == 202 && id is String) {
      final seconds = response.body['retry_after_seconds'];
      return PurchaseVerificationPending(
        id,
        Duration(seconds: seconds is int && seconds > 0 ? seconds : 5),
      );
    }
    final caseId = response.body['recovery_case_id'];
    return PurchaseRejected(
      response.code ?? 'verification_unavailable',
      caseId is String ? caseId : null,
    );
  }
}
