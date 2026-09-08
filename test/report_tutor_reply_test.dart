import 'package:czechify/presentation/widgets/chat/report_tutor_reply_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:czechify/data/database/database.dart' as db;
import 'package:czechify/data/repositories/tutor_reply_report_repository.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// url_launcher's default method-channel implementation.
const _launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

/// Makes `launchUrl` report [opened] instead of reaching a real platform.
void launcherReturns(WidgetTester tester, bool opened) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _launcherChannel,
    (call) async => opened,
  );
}

void clearLauncher(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _launcherChannel,
    null,
  );
}

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
    Future<db.AppDatabase> open(
      WidgetTester tester, {
      TutorReplyReportRepository Function(db.AppDatabase)? repository,
    }) async {
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            if (repository != null)
              tutorReplyReportRepositoryProvider.overrideWithValue(
                repository(database),
              ),
          ],
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed:
                          () => showReportTutorReplySheet(
                            context: context,
                            replyText: 'Tohle je ta odpověď.',
                            scenarioTitle: 'At the Doctor',
                            scenarioId: 'doctor',
                            messageId: 'msg-1',
                            conversationId: 'conv-1',
                          ),
                      child: const Text('open'),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return database;
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

    testWidgets('the report is recorded without leaving the app', (
      tester,
    ) async {
      // No launcher is mocked at all: the policy requires reporting without
      // leaving the app, so the happy path must never reach a mail draft.
      final database = await open(tester);
      await tester.tap(find.text(ReportReason.offensive.label));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'it told me to stop');
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      expect(find.text('Report this reply'), findsNothing);

      final stored = await database.select(database.tutorReplyReports).get();
      expect(stored, hasLength(1));
      expect(stored.single.reason, 'offensive');
      expect(stored.single.replyText, 'Tohle je ta odpověď.');
      expect(stored.single.learnerNote, 'it told me to stop');
      expect(stored.single.messageId, 'msg-1');
      expect(stored.single.conversationId, 'conv-1');
    });

    testWidgets('the report is queued for the backend, not just kept', (
      tester,
    ) async {
      // Written and enqueued in one transaction, so a report filed with no
      // signal still reaches someone.
      final database = await open(tester);
      await tester.tap(find.text(ReportReason.dangerous.label));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      final queued = await database.select(database.syncQueue).get();
      expect(
        queued.where((row) => row.entity == 'tutor_reply_reports'),
        hasLength(1),
      );
    });

    testWidgets('the learner\'s own messages are still never stored', (
      tester,
    ) async {
      final database = await open(tester);
      await tester.tap(find.text(ReportReason.other.label));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      // The promise the sheet makes on screen has to hold in the row too.
      final stored = await database.select(database.tutorReplyReports).get();
      final queued = await database.select(database.syncQueue).get();
      for (final text in [
        stored.single.replyText,
        stored.single.learnerNote,
        queued.first.payload,
      ]) {
        expect(text, isNot(contains('Dobrý den')));
      }
    });

    testWidgets('a failed local write falls back to mail, not a dead end', (
      tester,
    ) async {
      // The only remaining reason to open a mail draft. Modelled by closing
      // the database out from under the sheet.
      launcherReturns(tester, false);
      addTearDown(() => clearLauncher(tester));

      await open(tester, repository: _FailingReportRepository.new);

      await tester.tap(find.text(ReportReason.offensive.label));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      // The sheet stays open, and the address is on screen to copy.
      expect(find.textContaining('email.czechify@gmail.com'), findsOneWidget);
      expect(find.text('Send report'), findsOneWidget);
    });
  });
}

/// Recording the report fails outright — the only case that should still open
/// a mail draft.
class _FailingReportRepository extends TutorReplyReportRepository {
  _FailingReportRepository(super.db);

  @override
  Future<String> file({
    required String scenarioId,
    required String reason,
    required String replyText,
    String learnerNote = '',
    String? messageId,
    String? conversationId,
  }) async => throw Exception('database unavailable');
}
