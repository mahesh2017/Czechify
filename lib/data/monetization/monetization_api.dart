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
  const PurchaseRejected(this.code);
}

class MonetizationApi {
  final ApiCall call;
  const MonetizationApi(this.call);

  /// Whether Play checkout is switched on for this account's cohort. Any
  /// failure reads as off: a paywall must never appear by accident.
  Future<bool> checkoutEnabled() async {
    try {
      final response = await call('configuration', method: 'GET');
      return response.status == 200 &&
          response.body['play_checkout_enabled'] == true;
    } on Exception {
      return false;
    }
  }

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
    return PurchaseRejected(response.code ?? 'verification_unavailable');
  }
}
