import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';

import '../../domain/entities/referral_receipt.dart';
import '../database/database.dart';
import 'play_integrity_service.dart';
import 'referral_api.dart';
import 'referral_store.dart';

/// Uploads queued lesson receipts for one account: a challenge, a Play
/// Integrity token bound to it, then the receipt.
///
/// Learning is never undone here: the receipt was committed with the lesson,
/// and every failure only changes when it is tried again. Uploads stop the
/// moment the signed-in account changes, so a receipt never travels under
/// another account's session.
class ReferralUploader {
  final ReferralStore store;
  final ReferralApi api;
  final PlayIntegrityService integrity;
  final String? Function() currentAccount;

  /// Whether the account consented to Play Integrity checks. Without it no
  /// token is requested and the receipt goes to support review.
  final Future<bool> Function(String account) integrityAllowed;
  final DateTime Function() now;
  final double Function() random;
  final Logger _log = Logger('ReferralUploader');
  Future<void>? _running;

  ReferralUploader({
    required this.store,
    required this.api,
    required this.integrity,
    required this.currentAccount,
    required this.integrityAllowed,
    DateTime Function()? now,
    double Function()? random,
  }) : now = now ?? DateTime.now,
       random = random ?? Random().nextDouble;

  /// Coalesces overlapping calls: one pass at a time.
  Future<void> drain() =>
      _running ??= _drain().whenComplete(() => _running = null);

  Future<void> _drain() async {
    final account = currentAccount();
    if (account == null) return;
    for (final row in await store.due(account, now())) {
      if (currentAccount() != account) return;
      try {
        await _upload(account, row);
      } on Exception catch (error) {
        // Network or transport failure: the same receipt waits and retries.
        await store.retryLater(row, _backoff(row.attempts), 'transport');
        _log.fine('Referral receipt upload failed', error);
      }
    }
  }

  Future<void> _upload(String account, ReferralReceiptOutboxData row) async {
    final challenge = await api.challenge(row.claimId, row.receiptDigest);
    if (currentAccount() != account) return;
    final nonce = challenge.body['nonce'];
    if (challenge.status != 201 || nonce is! String) {
      return _refused(row, challenge.status, challenge.code);
    }
    // Without consent the device is not asked at all.
    final token =
        await integrityAllowed(account)
            ? await integrity.requestToken(
              referralIntegrityRequestHash(
                accountId: account,
                claimId: row.claimId,
                nonce: nonce,
                receiptDigest: row.receiptDigest,
              ),
            )
            : const IntegrityUnsupported();
    if (currentAccount() != account) return;
    final String? tokenValue;
    switch (token) {
      case IntegrityToken(:final token):
        tokenValue = token;
      case IntegrityUnsupported():
        tokenValue = null;
      case IntegrityRetry():
        return store.retryLater(row, _backoff(row.attempts), 'integrity_retry');
      case IntegrityMisconfigured():
        _log.warning('Play Integrity is not configured in this build');
        return store.retryLater(
          row,
          now().add(const Duration(hours: 6)),
          'integrity_misconfigured',
        );
    }
    final receipt = jsonDecode(row.receiptJson) as Map<String, Object?>;
    final response = await api.submit(receipt, nonce, tokenValue);
    if (response.status == 202) {
      return store.settle(account, row.attemptId, 'sent');
    }
    return _refused(row, response.status, response.code);
  }

  Future<void> _refused(
    ReferralReceiptOutboxData row,
    int status,
    String? code,
  ) {
    switch (code) {
      // Permanent: retrying the same receipt can never succeed.
      case 'integrity_rejected' ||
          'invalid_receipt' ||
          'referral_unavailable' ||
          'idempotency_conflict':
        return store.settle(
          row.accountId,
          row.attemptId,
          'rejected',
          error: code,
        );
      // Waits for a server-side change; kept for support to resolve.
      case 'content_update_required' || 'campaign_unavailable':
        return store.settle(row.accountId, row.attemptId, 'held', error: code);
      // A fresh challenge fixes it.
      case 'challenge_invalid':
        return store.retryLater(
          row,
          now().add(const Duration(seconds: 5)),
          code!,
        );
      case 'rate_limited':
        return store.retryLater(
          row,
          now().add(const Duration(hours: 1)),
          code!,
        );
      default:
        return store.retryLater(
          row,
          _backoff(row.attempts),
          code ?? 'http_$status',
        );
    }
  }

  /// 30 s doubling to six hours, with jitter.
  DateTime _backoff(int attempts) {
    final seconds = min(6 * 3600, 30 * pow(2, min(attempts, 20)).toInt());
    return now().add(
      Duration(seconds: (seconds * (0.5 + random() / 2)).ceil()),
    );
  }
}
