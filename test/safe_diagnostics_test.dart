import 'package:czechify/core/diagnostics/safe_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  test('diagnostics retain safe IDs without learner or exception text', () {
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);

    SafeDiagnostics.error(
      'review_commit',
      StateError('learner@example.com said: moje tajná odpověď'),
      StackTrace.empty,
      contentId: 42,
      releaseId: 'release:2026-07',
      fromState: 'answering',
      toState: 'committing',
    );

    final message = records.single.message;
    expect(message, contains('event=review_commit'));
    expect(message, contains('error_type=StateError'));
    expect(message, contains('content_id=42'));
    expect(message, contains('release_id=release:2026-07'));
    expect(message, isNot(contains('learner@example.com')));
    expect(message, isNot(contains('tajná')));
  });

  test('diagnostics discard arbitrary metadata', () {
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);

    SafeDiagnostics.error(
      'unsafe event with spaces',
      Exception('private response'),
      StackTrace.empty,
      contentId: 'the learner typed this sentence',
      releaseId: 'release\nheader',
    );

    expect(records.single.message, 'event=unknown_error error_type=_Exception');
  });
}
