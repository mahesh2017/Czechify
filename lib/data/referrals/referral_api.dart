import '../../domain/entities/referral_receipt.dart';
import '../monetization/monetization_api.dart';

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
