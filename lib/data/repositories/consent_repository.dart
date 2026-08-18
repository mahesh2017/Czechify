import 'dart:io';

import 'package:drift/drift.dart';

import '../../core/legal/legal_content.dart';
import '../database/database.dart';

/// Purposes a learner can consent to. String values are stored, so they must
/// stay stable — a renamed purpose would orphan every existing record.
class ConsentPurpose {
  static const voiceCloudProcessing = 'voice_cloud_processing';
}

/// Reads and writes the consent audit log.
///
/// Two rules shape this class, both from GDPR rather than convenience:
///
/// * Nothing is ever updated or deleted. Withdrawing consent appends a
///   `granted: false` row, so the history of what was agreed, and when it
///   stopped, both survive.
/// * The notice version is recorded with every decision, because being able
///   to demonstrate consent (Art. 7(1)) means being able to show the wording.
class ConsentRepository {
  ConsentRepository(this._db, {String appVersion = '1.0.0'})
    : _appVersion = appVersion,
      assert(appVersion != '');

  final AppDatabase _db;
  final String _appVersion;

  String get _platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    return Platform.operatingSystem;
  }

  /// Whether [purpose] is currently consented to — the most recent decision
  /// wins, and no decision means no consent.
  ///
  /// Defaulting to false matters: consent must be an active choice, never the
  /// result of a missing row or a failed read.
  Future<bool> isGranted(String purpose) async {
    final latest =
        await (_db.select(_db.consentRecords)
              ..where((r) => r.purpose.equals(purpose))
              ..orderBy([
                (r) => OrderingTerm(
                  expression: r.decidedAt,
                  mode: OrderingMode.desc,
                ),
                (r) => OrderingTerm(expression: r.id, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();
    return latest?.granted ?? false;
  }

  /// Record a decision. Returns the row written.
  Future<ConsentRecord> record({
    required String purpose,
    required bool granted,
    required String noticeVersion,
  }) async {
    final id = await _db
        .into(_db.consentRecords)
        .insert(
          ConsentRecordsCompanion.insert(
            purpose: purpose,
            noticeVersion: noticeVersion,
            policyVersion: kPrivacyPolicyVersion,
            granted: granted,
            // Explicit UTC, explicitly marked: records from different time
            // zones stay comparable and the value reads unambiguously.
            decidedAt: DateTime.now().toUtc().toIso8601String(),
            appVersion: Value(_appVersion),
            platform: Value(_platform),
          ),
        );
    return (_db.select(_db.consentRecords)
      ..where((r) => r.id.equals(id))).getSingle();
  }

  /// The full history, newest first — what a subject-access request or a
  /// complaint would need to be answered.
  Future<List<ConsentRecord>> history([String? purpose]) {
    final query = _db.select(_db.consentRecords)..orderBy([
      (r) => OrderingTerm(expression: r.decidedAt, mode: OrderingMode.desc),
    ]);
    if (purpose != null) query.where((r) => r.purpose.equals(purpose));
    return query.get();
  }

  /// Records not yet pushed to the server.
  ///
  /// NOTE: nothing calls this yet. There is no server-side consent table, so
  /// the audit log is device-local and does not survive a lost or wiped
  /// device — a weaker position than it looks, because evidence a controller
  /// must be able to produce currently sits only on the data subject's phone.
  /// The `synced` column and these two methods are the client half of closing
  /// that; the missing half is a `consent_records` table with owner RLS and an
  /// entry in the sync entity map. Deliberately not built yet — see the
  /// decision noted in docs/MANUAL_VERIFICATION_PHASES_1-3.md.
  Future<List<ConsentRecord>> pendingSync() {
    return (_db.select(_db.consentRecords)
          ..where((r) => r.synced.equals(false))
          ..orderBy([(r) => OrderingTerm(expression: r.decidedAt)]))
        .get();
  }

  /// Mark rows as pushed. Only the flag changes — the decision itself stays
  /// exactly as written.
  Future<void> markSynced(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await (_db.update(_db.consentRecords)..where(
      (r) => r.id.isIn(ids),
    )).write(const ConsentRecordsCompanion(synced: Value(true)));
  }
}
