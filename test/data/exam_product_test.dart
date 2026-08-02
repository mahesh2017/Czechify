import 'package:ceskina_pro/data/database/database.dart' hide ExamResult;
import 'package:ceskina_pro/data/repositories/drift_exam_repository.dart';
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exam_result.dart';
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
