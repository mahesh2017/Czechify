import 'package:czechify/data/database/database.dart' hide ExamResult;
import 'package:czechify/data/repositories/drift_exam_repository.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exam_result.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The exam layer is product-aware: one engine, versioned blueprints, one bank
/// per (product, level). Results are labeled by product; legacy rows read as
/// permanent-residence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftExamRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftExamRepository(db);
  });
  tearDown(() => db.close());

  test(
    'permanent-residence A2 bank loads with its versioned blueprint',
    () async {
      final exam = await repo.getMockExam(ExamLevel.a2);
      expect(exam.product, ExamProduct.permanentResidence);
      expect(exam.blueprint.effectiveDate, '2026-04-11');
      expect(
        exam.blueprint.scoringRule,
        ExamScoringRule.rawPointsWrittenSpeakingGate,
      );
      expect(exam.sections, isNotEmpty);
    },
  );

  test('A1 bank is labeled as independent course practice', () async {
    final practice = await repo.getMockExam(
      ExamLevel.a1,
      product: ExamProduct.coursePractice,
    );
    expect(practice.product, ExamProduct.coursePractice);
    expect(practice.blueprint.effectiveDate, 'not_applicable');
  });

  test(
    'a bank for an unshipped product falls back to a labeled sample',
    () async {
      // No CCE bank asset ships yet; the fallback must still carry the product.
      final exam = await repo.getMockExam(
        ExamLevel.a2,
        product: ExamProduct.cce,
      );
      expect(exam.product, ExamProduct.cce);
      expect(exam.sections, isNotEmpty);
    },
  );

  /// Resuming an interrupted attempt has to land on the paper the answers were
  /// given to, so the checkpoint stores a paper id and the screen resolves it
  /// through here rather than drawing again.
  group('findMockExam', () {
    test('returns the paper the id names, not a fresh draw', () async {
      // Every paper in the bank, so this cannot pass by drawing lucky.
      for (final paper in await repo.getAllMockExams(ExamLevel.a2)) {
        final found = await repo.findMockExam(ExamLevel.a2, paper.id);

        expect(found, isNotNull, reason: '${paper.id} was not findable');
        expect(found!.id, paper.id);
        expect(
          found.sections.first.questions.first,
          paper.sections.first.questions.first,
        );
      }
    });

    test('returns null for a paper the bank no longer has', () async {
      // The caller discards the checkpoint on null. Anything else would put
      // the saved answers on a different paper.
      expect(await repo.findMockExam(ExamLevel.a2, 'a2-retired-paper'), isNull);
    });

    test('does not match a paper id from another level', () async {
      final a1 = await repo.getAllMockExams(
        ExamLevel.a1,
        product: ExamProduct.coursePractice,
      );

      expect(await repo.findMockExam(ExamLevel.a2, a1.first.id), isNull);
    });

    test('resolves the sample that stands in for an unshipped bank', () async {
      // No CCE bank ships, so getMockExam hands back the labeled sample — and
      // a checkpoint taken against it has to resolve here too.
      final sample = await repo.getMockExam(
        ExamLevel.a2,
        product: ExamProduct.cce,
      );

      final found = await repo.findMockExam(
        ExamLevel.a2,
        sample.id,
        product: ExamProduct.cce,
      );

      expect(found, isNotNull);
      expect(found!.id, sample.id);
    });
  });

  test('results are persisted and filterable by product', () async {
    await repo.saveResult(_result(ExamProduct.permanentResidence));
    await repo.saveResult(_result(ExamProduct.cce));

    final perm = await repo.getResults(
      ExamLevel.a2,
      product: ExamProduct.permanentResidence,
    );
    final cce = await repo.getResults(ExamLevel.a2, product: ExamProduct.cce);
    final all = await repo.getResults(ExamLevel.a2);

    expect(
      perm.map((r) => r.product),
      everyElement(ExamProduct.permanentResidence),
    );
    expect(cce.map((r) => r.product), everyElement(ExamProduct.cce));
    expect(all, hasLength(2));
  });

  test(
    'legacy result rows (no product column value) read as permanent-residence',
    () async {
      // Simulate a pre-v18 row by inserting without a product (column default).
      await db.customStatement(
        "INSERT INTO exam_results (level, product, total_score, passed) VALUES ('a2', 'permanent_residence', 80, 1)",
      );
      final results = await repo.getResults(ExamLevel.a2);
      expect(results.single.product, ExamProduct.permanentResidence);
    },
  );
}

ExamResult _result(ExamProduct product) => ExamResult(
  id: 0,
  level: ExamLevel.a2,
  product: product,
  takenAt: DateTime.utc(2026, 7, 24),
  readingScore: 20,
  listeningScore: 20,
  writingScore: 15,
  speakingScore: 30,
  totalScore: 85,
  passed: true,
);
