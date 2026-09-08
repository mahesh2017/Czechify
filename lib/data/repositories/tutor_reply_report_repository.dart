import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';

/// Files reports about what the AI tutor said.
///
/// Written locally and enqueued for sync in one transaction, so a report filed
/// with no signal is durable before the learner is told it was received — the
/// mail-draft handoff this replaces could say neither.
class TutorReplyReportRepository {
  TutorReplyReportRepository(this._db, {this.appVersion = ''});

  final AppDatabase _db;

  /// The build that produced the reply being reported.
  final String appVersion;
  static const _uuid = Uuid();

  /// Records a report and queues it for the backend. Returns its id.
  ///
  /// The id is generated here rather than by the server so the row is
  /// idempotent: a retried push upserts the same report instead of filing it
  /// twice.
  Future<String> file({
    required String scenarioId,
    required String reason,
    required String replyText,
    String learnerNote = '',
    String? messageId,
    String? conversationId,
  }) async {
    final reportId = 'rep_${_uuid.v4()}';
    final reportedAt = DateTime.now();

    await _db.transaction(() async {
      await _db
          .into(_db.tutorReplyReports)
          .insert(
            TutorReplyReportsCompanion.insert(
              reportId: reportId,
              messageId: Value(messageId),
              conversationId: Value(conversationId),
              scenarioId: scenarioId,
              reason: reason,
              replyText: replyText,
              learnerNote: Value(learnerNote),
              appVersion: Value(appVersion),
              reportedAt: Value(reportedAt),
            ),
          );
      await _db.syncDao.enqueue(
        entity: 'tutor_reply_reports',
        entityKey: reportId,
        payload: {
          'report_id': reportId,
          'message_id': messageId,
          'conversation_id': conversationId,
          'scenario_id': scenarioId,
          'reason': reason,
          'reply_text': replyText,
          'learner_note': learnerNote,
          'app_version': appVersion,
          'reported_at': reportedAt.toUtc().toIso8601String(),
        },
      );
    });

    return reportId;
  }

  /// Reports filed on this device, newest first.
  Future<List<TutorReplyReport>> history() {
    return (_db.select(_db.tutorReplyReports)..orderBy([
      (r) => OrderingTerm(expression: r.reportedAt, mode: OrderingMode.desc),
      (r) => OrderingTerm(expression: r.reportId, mode: OrderingMode.desc),
    ])).get();
  }
}
