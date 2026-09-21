import '../../domain/entities/referral_receipt.dart';
import '../monetization/monetization_api.dart';
import 'referral_status.dart';

export 'referral_status.dart';

/// Referral routes of `monetization-api`. The account is always the signed-in
/// session; nothing here names one.
class ReferralApi {
  final ApiCall call;
  const ReferralApi(this.call);

  /// `claim_id` on success, otherwise the server's stable refusal code.
  Future<({String? claimId, String? code})> claim(String inviteCode) async {
    final response = await call(
      'referrals/claim',
      method: 'POST',
      body: {
        'campaign_id': referralCampaignId,
        'code': inviteCode.trim().toUpperCase(),
        'attribution_source': 'manual',
      },
    );
    final id = response.body['claim_id'];
    return response.status == 201 && id is String
        ? (claimId: id, code: null)
        : (claimId: null, code: response.code ?? 'verification_unavailable');
  }

  /// The account's invite code, created on first request. Refusals come back
  /// as the server's code (for example `linked_account_required`).
  Future<({String? code, String? refusal})> inviteCode() async {
    final response = await call(
      'referrals/code',
      method: 'POST',
      body: {'campaign_id': referralCampaignId},
    );
    final code = response.body['referral_code'];
    return response.status == 200 && code is String
        ? (code: code, refusal: null)
        : (code: null, refusal: response.code ?? 'verification_unavailable');
  }

  /// The account's referral picture, or null when it could not be loaded.
  Future<ReferralStatus?> status({int cursor = 0}) async {
    final response = await call(
      'referrals/status${cursor > 0 ? '?cursor=$cursor' : ''}',
      method: 'GET',
    );
    return response.status == 200
        ? ReferralStatus.fromJson(response.body)
        : null;
  }

  Future<ApiResponse> challenge(String claimId, String receiptDigest) => call(
    'referrals/challenges',
    method: 'POST',
    body: {'claim_id': claimId, 'receipt_digest': receiptDigest},
  );

  /// Either a Play Integrity [token], or null for a device that cannot
  /// produce one, which sends the claim to human review.
  Future<ApiResponse> submit(
    Map<String, Object?> receipt,
    String nonce,
    String? token,
  ) => call(
    'referrals/receipts',
    method: 'POST',
    body: {
      'receipt': receipt,
      'nonce': nonce,
      if (token != null)
        'integrity_token': token
      else
        'integrity_unavailable': true,
    },
  );
}
