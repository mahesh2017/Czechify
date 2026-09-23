import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../domain/entities/course_catalog.dart';
import '../../domain/entities/curriculum_entitlement.dart';
import '../../domain/entities/monetization_snapshot.dart';

class VerifiedMonetizationDocument {
  final MonetizationSnapshot snapshot;
  final CurriculumEntitlement staff;
  final DateTime issuedAt;
  final String signedPayload;
  const VerifiedMonetizationDocument(
    this.snapshot,
    this.staff,
    this.issuedAt,
    this.signedPayload,
  );
}

/// Fixed compact-JWS profile. Public keys are shipped with the application;
/// never accept a key, algorithm or key URL supplied by the document itself.
class SnapshotVerifier {
  final Map<String, SimplePublicKey> _keys;
  SnapshotVerifier(Map<String, List<int>> publicKeys)
    : _keys = Map.unmodifiable({
        for (final e in publicKeys.entries)
          e.key: SimplePublicKey(
            List<int>.unmodifiable(e.value),
            type: KeyPairType.ed25519,
          ),
      }) {
    if (publicKeys.values.any((key) => key.length != 32)) {
      throw ArgumentError('Ed25519 public keys must be 32 bytes.');
    }
  }

  Future<VerifiedMonetizationDocument> verify(
    String jws, {
    required String accountId,
  }) async {
    if (accountId.isEmpty || jws.length > 128 * 1024) _invalid();
    final parts = jws.split('.');
    if (parts.length != 3 ||
        parts.any((p) => !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(p))) {
      _invalid();
    }
    final header = _object(
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[0])))),
    );
    if (header.length != 3 ||
        header['alg'] != 'EdDSA' ||
        header['typ'] != 'czechify-entitlements+jws' ||
        header['kid'] is! String) {
      _invalid();
    }
    final key = _keys[header['kid']];
    if (key == null) _invalid();
    final signature = base64Url.decode(base64Url.normalize(parts[2]));
    if (signature.length != 64 ||
        !await Ed25519().verify(
          ascii.encode('${parts[0]}.${parts[1]}'),
          signature: Signature(signature, publicKey: key),
        )) {
      _invalid();
    }
    final body = _object(
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))),
    );
    if (body['schema_version'] != 1 ||
        body['user_id'] != accountId ||
        body['policy_version'] != 'course-access-v1' ||
        body['manifest_revision'] != 25 ||
        body['campaign_id'] != 'a1-referral-v1') {
      _invalid();
    }
    final revision = body['revision'];
    if (revision is! int || revision < 0 || revision > 9007199254740991) {
      _invalid();
    }
    final issuedAt = _date(body['issued_at'])!;
    final verifiedAt = _date(body['verified_at'])!;
    if (verifiedAt.isAfter(issuedAt)) _invalid();
    final features = _object(body['features']);
    final rawGrants = body['permanent_unit_grants'];
    if (rawGrants is! List || rawGrants.length > 512) _invalid();
    final grantIds = <String>{};
    final grants = <PermanentUnitGrant>[];
    for (final raw in rawGrants) {
      final g = _object(raw);
      final id = g['grant_id'];
      final unit = g['unit_id'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 128 ||
          !grantIds.add(id) ||
          unit is! int ||
          !CourseCatalog.a1ReferralV1.allUnitIds.contains(unit)) {
        _invalid();
      }
      final source = switch (g['source']) {
        'referral' => PermanentGrantSource.referral,
        'legacy' => PermanentGrantSource.legacy,
        'staff_permanent' => PermanentGrantSource.staffPermanent,
        _ => _invalid(),
      };
      if (source == PermanentGrantSource.referral &&
          !CourseCatalog.a1ReferralV1.rewardUnitIds.contains(unit)) {
        _invalid();
      }
      grants.add(PermanentUnitGrant(id: id, unitId: unit, source: source));
    }
    final staffUntil = _date(body['staff_course_until'], nullable: true);
    if (body['staff_course_unlimited'] is! bool) _invalid();
    final unlimited = body['staff_course_unlimited'] == true;
    if (unlimited && staffUntil != null) _invalid();
    return VerifiedMonetizationDocument(
      MonetizationSnapshot(
        userId: accountId,
        revision: revision,
        verifiedAt: verifiedAt,
        core: _feature(features['core']),
        aiChat: _feature(features['ai_chat']),
        permanentGrants: grants,
        migrationGraceUntil: _date(
          body['migration_grace_until'],
          nullable: true,
        ),
        referralTrialUntil: _date(body['referral_trial_until'], nullable: true),
      ),
      CurriculumEntitlement(
        unlockAll: unlimited || staffUntil != null,
        expiresAt: staffUntil,
      ),
      issuedAt,
      jws,
    );
  }

  static FeatureEntitlement _feature(Object? value) {
    final f = _object(value);
    if (f['state'] != 'active' && f['state'] != 'inactive') _invalid();
    final until = _date(f['valid_until'], nullable: true);
    final offline = _date(f['offline_valid_until'], nullable: true);
    final active = f['state'] == 'active';
    if (active && (until == null || offline == null)) _invalid();
    if (!active && (until != null || offline != null)) _invalid();
    if (until != null && offline != null && offline.isAfter(until)) _invalid();
    return FeatureEntitlement(
      active: active,
      validUntil: until,
      offlineValidUntil: offline,
    );
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) _invalid();
    return value;
  }

  static DateTime? _date(Object? value, {bool nullable = false}) {
    if (value == null && nullable) return null;
    if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      _invalid();
    }
    final date = DateTime.tryParse(value);
    if (date == null) _invalid();
    return date.toUtc();
  }

  static Never _invalid() =>
      throw const FormatException('Invalid entitlement snapshot.');
}
