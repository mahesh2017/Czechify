import 'package:shared_preferences/shared_preferences.dart';

/// Whether this account agreed to Play Integrity checks for its invitation.
///
/// A Play Integrity request reads information from the device, which EU law
/// (ePrivacy Art. 5(3); in Czechia § 89(3) of Act 127/2005) allows only with
/// consent unless strictly necessary. Invitations work without it: receipts
/// then go to support review. So it is opt-in, off until chosen, and can be
/// withdrawn at any time. The same rule applies everywhere.
///
/// Until the learner has chosen, their lesson results wait on the device:
/// sending one unchecked would put the whole invitation into manual review
/// before they had a chance to say yes.
class ReferralIntegrityConsent {
  const ReferralIntegrityConsent._();

  static String _key(String account) =>
      'referral_integrity_consent_v1:$account';

  /// The learner's answer, or null if they have not been asked yet.
  static Future<bool?> choice(String account) async =>
      (await SharedPreferences.getInstance()).getBool(_key(account));

  static Future<bool> granted(String account) async =>
      await choice(account) ?? false;

  /// Records the choice and when it was made.
  static Future<void> set(String account, bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(account), granted);
    await prefs.setString(
      '${_key(account)}:at',
      DateTime.now().toUtc().toIso8601String(),
    );
  }
}
