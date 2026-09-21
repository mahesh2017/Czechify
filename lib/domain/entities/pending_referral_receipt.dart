import 'referral_receipt.dart';

/// A receipt to queue with a lesson attempt, for the account that was signed
/// in when the attempt began.
class PendingReferralReceipt {
  final String accountId;
  final ReferralReceipt receipt;
  const PendingReferralReceipt({
    required this.accountId,
    required this.receipt,
  });
}
