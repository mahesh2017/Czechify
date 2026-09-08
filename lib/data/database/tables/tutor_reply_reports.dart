import 'package:drift/drift.dart';

/// Reports a learner has filed about something the AI tutor said.
///
/// Google Play's generative-AI policy requires that a reader can report
/// offensive generated content *without leaving the app*. Handing off to a
/// mail draft satisfied neither half of that: it left the app, and it left no
/// record — nothing could say a report had been received, let alone answered.
///
/// Written locally first and pushed through the sync outbox, so a report
/// survives being filed on a train. That also means the report is durable
/// before the learner is told it was received, rather than after.
///
/// Deliberately holds the tutor's reply and not the learner's messages. The
/// offending output is what needs looking at; the other half of the
/// conversation is theirs. Anything more is for them to type into the note.
class TutorReplyReports extends Table {
  /// Client-generated uuid, so the row is idempotent across retries and the
  /// outbox can upsert it without the server assigning anything.
  TextColumn get reportId => text()();

  /// The message being reported, when it is known. Reports are deduplicated on
  /// it server-side so one reply cannot be filed twice.
  TextColumn get messageId => text().nullable()();
  TextColumn get conversationId => text().nullable()();

  TextColumn get scenarioId => text()();
  TextColumn get reason => text()();
  TextColumn get replyText => text()();
  TextColumn get learnerNote => text().withDefault(const Constant(''))();

  /// The build that produced the reply, so a later question about which model
  /// or prompt version said it can be answered.
  TextColumn get appVersion => text().withDefault(const Constant(''))();

  DateTimeColumn get reportedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {reportId};
}
