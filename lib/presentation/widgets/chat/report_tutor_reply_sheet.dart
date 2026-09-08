import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/database_providers.dart';

import '../../../core/legal/legal_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Why a learner is reporting a tutor reply.
///
/// The wording is the learner's, not a moderation taxonomy: someone who has
/// just read something upsetting should not have to work out which internal
/// category it belongs to.
enum ReportReason {
  offensive('Offensive or hateful', 'offensive'),
  sexual('Sexual or adult content', 'sexual'),
  dangerous('Dangerous or harmful advice', 'dangerous'),
  wrongCzech('The Czech is wrong', 'wrong_czech'),
  other('Something else', 'other');

  const ReportReason(this.label, this.id);

  /// What the learner reads.
  final String label;

  /// What is stored. Separate from [label] so the wording can be reworded, or
  /// translated, without orphaning every report already filed — and so it
  /// matches the `tutor_reply_reports_reason_valid` constraint.
  final String id;
}

/// The text of a report.
///
/// Pure and top-level so the privacy promise this file makes is testable:
/// the learner's own messages are not reachable from here, so no future edit
/// can quietly start including them.
String buildReportBody({
  required ReportReason reason,
  required String scenarioTitle,
  required String replyText,
  required String note,
  required DateTime reportedAt,
}) {
  final trimmed = note.trim();
  return 'Reason: ${reason.label}\n'
      'Scenario: $scenarioTitle\n'
      'Reported at: ${reportedAt.toUtc().toIso8601String()}\n'
      '\n'
      'Tutor reply:\n'
      '$replyText\n'
      '\n'
      'Anything you want to add:\n'
      '${trimmed.isEmpty ? '(nothing added)' : trimmed}\n';
}

/// Report an AI reply. Returns true once the report has been recorded.
///
/// Required by Google Play's generative-AI policy: an app whose model writes
/// free-form text has to give the reader somewhere to take it when the model
/// writes something it should not have — and the policy is explicit that this
/// must not require leaving the app.
///
/// The report is written locally and queued for the backend in one
/// transaction, so it is durable before the learner is told it was received,
/// and survives being filed with no signal. The mail draft remains only for a
/// learner with no account to file it against.
///
/// The report carries the tutor's own reply and the scenario. It deliberately
/// does not carry the learner's messages — those are the private half of the
/// conversation, and the offending output is what needs looking at. Anything
/// more is up to the learner to type into the note field.
Future<bool> showReportTutorReplySheet({
  required BuildContext context,
  required String replyText,
  required String scenarioTitle,
  required String scenarioId,
  String? messageId,
  String? conversationId,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (ctx) => _ReportSheet(
          replyText: replyText,
          scenarioTitle: scenarioTitle,
          scenarioId: scenarioId,
          messageId: messageId,
          conversationId: conversationId,
        ),
  );
  return sent ?? false;
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.replyText,
    required this.scenarioTitle,
    required this.scenarioId,
    this.messageId,
    this.conversationId,
  });

  final String replyText;
  final String scenarioTitle;
  final String scenarioId;
  final String? messageId;
  final String? conversationId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  final _note = TextEditingController();
  bool _sending = false;

  /// Shown when no mail app can be opened, so the report is never a dead end.
  bool _showFallback = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String get _body => buildReportBody(
    reason: _reason!,
    scenarioTitle: widget.scenarioTitle,
    replyText: widget.replyText,
    note: _note.text,
    reportedAt: DateTime.now(),
  );

  Future<void> _send() async {
    if (_reason == null) return;
    setState(() => _sending = true);

    // Recorded in the app, which is what the policy asks for and what makes a
    // report answerable. Written locally and queued in one transaction, so it
    // is durable before the learner is told it was received.
    try {
      await ref
          .read(tutorReplyReportRepositoryProvider)
          .file(
            scenarioId: widget.scenarioId,
            reason: _reason!.id,
            replyText: widget.replyText,
            learnerNote: _note.text,
            messageId: widget.messageId,
            conversationId: widget.conversationId,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    } catch (_) {
      // Falls through to the mail draft below. Reaching here means the local
      // write failed outright — a report must never be a dead end.
    }
    if (!mounted) return;

    // Built with queryParameters so the subject and body are percent-encoded;
    // a reply containing & or # would otherwise truncate the mail draft.
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      queryParameters: {
        'subject': 'Czechify — report about an AI tutor reply',
        'body': _body,
      },
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop(true);
      return;
    }
    // No mail app, or the platform refused the handoff. Show the address
    // rather than telling the learner their report failed.
    setState(() {
      _sending = false;
      _showFallback = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report this reply',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'We will see the tutor\'s reply and the scenario. Your own '
              'messages are not included.',
              style: TextStyle(fontSize: 13.5, height: 1.4, color: t.muted),
            ),
            const SizedBox(height: 16),
            // Hand-rolled rather than RadioListTile: that widget's groupValue
            // API is deprecated, and CI analyses with --fatal-infos.
            for (final reason in ReportReason.values)
              ListTile(
                onTap: _sending ? null : () => setState(() => _reason = reason),
                leading: Icon(
                  _reason == reason
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _reason == reason ? t.pri : t.muted,
                ),
                title: Text(reason.label, style: TextStyle(color: t.ink)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              enabled: !_sending,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).reportNoteLabel,
              ),
            ),
            if (_showFallback) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.amberSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No mail app opened. Please send your report to '
                  '$kSupportEmail and we will look into it.',
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: t.ink),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _sending ? null : () => Navigator.of(context).pop(false),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _reason == null || _sending ? null : _send,
                  child: Text(_sending ? 'Opening…' : 'Send report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
