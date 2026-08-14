import 'package:ceskina_pro/presentation/widgets/chat/report_tutor_reply_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reporting an AI reply is a Play requirement, but the interesting part is the
/// promise attached to it: the report carries the tutor's words, not the
/// learner's. These tests pin that promise, and the gating that stops a report
/// leaving without a reason on it.
void main() {
  final at = DateTime.utc(2026, 8, 14, 9, 30);

  group('report body', () {
    test('carries the tutor reply, the reason, and the scenario', () {
      final body = buildReportBody(
        reason: ReportReason.offensive,
        scenarioTitle: 'At the Doctor',
        replyText: 'Tohle je ta odpověď.',
        note: '',
        reportedAt: at,
      );

      expect(body, contains('Offensive or hateful'));
      expect(body, contains('At the Doctor'));
      expect(body, contains('Tohle je ta odpověď.'));
      expect(body, contains('2026-08-14T09:30:00.000Z'));
    });

    test('never carries anything the learner said', () {
      // The learner's own messages are not a parameter, so there is no way for
      // this function to include them. If someone adds one, this fails.
      final body = buildReportBody(
        reason: ReportReason.wrongCzech,
        scenarioTitle: 'Shopping',
        replyText: 'tutor words only',
        note: '',
        reportedAt: at,
      );

      expect(body, isNot(contains('learner')));
      expect(body.split('\n').where((l) => l.startsWith('You said:')), isEmpty);
    });

    test('an empty note says so rather than trailing off', () {
      final body = buildReportBody(
        reason: ReportReason.other,
        scenarioTitle: 'Casual chat',
        replyText: 'x',
        note: '   ',
        reportedAt: at,
      );

      expect(body, contains('(nothing added)'));
    });

    test('a note the learner wrote is included, trimmed', () {
      final body = buildReportBody(
        reason: ReportReason.dangerous,
        scenarioTitle: 'Casual chat',
        replyText: 'x',
        note: '  it told me to skip my medication  ',
        reportedAt: at,
      );

      expect(body, contains('it told me to skip my medication'));
      expect(body, isNot(contains('  it told me')));
    });
  });

  group('report sheet', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => ElevatedButton(
                    onPressed:
                        () => showReportTutorReplySheet(
                          context: context,
                          replyText: 'Tohle je ta odpověď.',
                          scenarioTitle: 'At the Doctor',
                        ),
                    child: const Text('open'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers every reason', (tester) async {
      await open(tester);
      for (final reason in ReportReason.values) {
        expect(find.text(reason.label), findsOneWidget);
      }
    });

    testWidgets('cannot send until a reason is chosen', (tester) async {
      await open(tester);

      final send = find.widgetWithText(FilledButton, 'Send report');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);

      await tester.tap(find.text(ReportReason.offensive.label));
      await tester.pump();

      expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    });

    testWidgets('says plainly that the learner\'s messages stay out', (
      tester,
    ) async {
      await open(tester);
      expect(
        find.textContaining('Your own messages are not included'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling reports nothing', (tester) async {
      await open(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Report this reply'), findsNothing);
    });
  });
}
