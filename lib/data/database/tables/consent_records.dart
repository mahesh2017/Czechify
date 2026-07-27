import 'package:drift/drift.dart';

/// An append-only log of consent given and withdrawn.
///
/// GDPR Article 7(1) puts the burden on the controller to *demonstrate* that
/// consent was given. "The user agreed" is close to useless in a dispute —
/// agreed to what wording, and when? So each row records the exact notice
/// version the learner was shown, and withdrawal writes a new row rather than
/// deleting or mutating the old one: an audit trail that can be edited is not
/// an audit trail.
///
/// Deliberately holds no copy of what was processed — no audio, no
/// transcripts. Only the fact, the time, and the wording.
class ConsentRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// What was consented to, e.g. `voice_cloud_processing`.
  TextColumn get purpose => text()();

  /// Version of the notice shown, e.g. `voice-cloud-v1`. Sourced from the same
  /// constant the screen renders, so it cannot drift from what was displayed.
  TextColumn get noticeVersion => text()();

  /// Privacy policy version current at the time of the decision.
  TextColumn get policyVersion => text()();

  /// True for granted, false for withdrawn.
  BoolColumn get granted => boolean()();

  /// ISO-8601 in UTC, e.g. `2026-07-26T09:12:33.000Z`.
  ///
  /// Text rather than a DateTime column on purpose. Drift reconstructs
  /// DateTime values in local time, so the UTC marker does not survive a
  /// round-trip — the instant is still correct, but the stored value is not
  /// self-describing. Evidence that might one day be handed to a regulator
  /// should say what it means without needing the code that wrote it.
  TextColumn get decidedAt => text()();

  /// App version and platform, so a later question about what a specific build
  /// showed can actually be answered.
  TextColumn get appVersion => text().withDefault(const Constant(''))();
  TextColumn get platform => text().withDefault(const Constant(''))();

  /// Whether this row has reached the server yet. Records are written locally
  /// first: if it only lived server-side, a failed sync would lose exactly the
  /// evidence you would need.
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}
