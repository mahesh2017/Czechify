import 'package:czechify/data/database/database.dart' as db;
import 'package:czechify/data/repositories/drift_exam_repository.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exam_result.dart';
import 'package:drift/drift.dart' show TableUpdate, TableUpdateQuery;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two things the exam history got wrong: it called every practice attempt a
/// failure, and it never noticed new ones.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late DriftExamRepository repo;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftExamRepository(database);
  });
  tearDown(() => database.close());

  ExamResult practiceAttempt({required int reading}) => ExamResult(
    id: 0,
    level: ExamLevel.a2,
    takenAt: DateTime.utc(2026, 9, 8),
    readingScore: reading,
    listeningScore: 90,
    writingScore: 85,
    speakingScore: 80,
    totalScore: 86,
    // The exam screen refuses to make an attainment claim while the shipped
    // banks are unvalidated, so every stored attempt looks like this.
    passed: false,
  );

  test('a perfect practice attempt is still stored as not passed', () async {
    await repo.saveResult(practiceAttempt(reading: 100));

    final stored = (await repo.getResults(ExamLevel.a2)).single;
    // The stats row keys its icon off this. Reading it as "failed" is what
    // painted a red cancel icon on a flawless run — the display now treats
    // `passed == false` as practice rather than as a verdict.
    expect(stored.passed, isFalse);
    expect(stored.readingScore, 100);
  });

  test(
    'saving an attempt notifies the tables the stats screen watches',
    () async {
      // The stats providers are cached futures kept alive by the mounted tab,
      // so they refresh off this stream rather than off each write's call site.
      final updates = database.tableUpdates(
        TableUpdateQuery.onAllTables([database.examResults]),
      );
      final seen = <Set<TableUpdate>>[];
      final subscription = updates.listen(seen.add);
      addTearDown(subscription.cancel);

      await repo.saveResult(practiceAttempt(reading: 70));
      await Future<void>.delayed(Duration.zero);

      expect(
        seen,
        isNotEmpty,
        reason: 'without this the history never learns a new attempt exists',
      );
    },
  );
}
