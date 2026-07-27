import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/exam_result.dart' as entity;
import '../../domain/repositories/exam_repository.dart';
import '../database/database.dart' as db;

/// Concrete implementation of [ExamRepository] using Drift.
///
/// Exam content is loaded from bundled JSON assets named
/// `exam_bank_<product>_<level>.json` (e.g. `exam_bank_permres_a2.json`).
/// Each file carries a versioned `blueprint` and multiple practice exams.
/// Results are persisted to the `exam_results` table.
class DriftExamRepository implements ExamRepository {
  final db.AppDatabase _db;
  final Logger _log = Logger('DriftExamRepository');

  /// Cache of loaded exam banks, keyed by (product, level).
  final Map<String, List<MockExam>> _cache = {};

  DriftExamRepository(this._db);

  @override
  Future<MockExam> getMockExam(
    ExamLevel level, {
    ExamProduct product = ExamProduct.permanentResidence,
  }) async {
    final exams = await _loadExams(level, product);
    if (exams.isEmpty) {
      _log.warning(
        'No ${product.id} exams for ${level.name}; falling back to sample.',
      );
      return buildSampleExam(level, product: product);
    }
    // Return a random exam from the bank for variety.
    return exams[Random().nextInt(exams.length)];
  }

  /// Get all available mock exams for a product + level.
  Future<List<MockExam>> getAllMockExams(
    ExamLevel level, {
    ExamProduct product = ExamProduct.permanentResidence,
  }) async {
    return _loadExams(level, product);
  }

  Future<List<MockExam>> _loadExams(
    ExamLevel level,
    ExamProduct product,
  ) async {
    final key = '${product.slug}_${level.name}';
    if (_cache.containsKey(key)) return _cache[key]!;

    final assetPath = 'assets/curriculum/exam_bank_$key.json';
    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final blueprint = _parseBlueprint(json, product);
      final examsJson = json['exams'] as List<dynamic>? ?? [];

      final exams =
          examsJson
              .whereType<Map<String, dynamic>>()
              .map((e) => _parseExam(e, level, blueprint))
              .toList();

      _cache[key] = exams;
      _log.info(
        'Loaded ${exams.length} ${product.id} exams for ${level.name}.',
      );
      return exams;
    } catch (e, st) {
      _log.warning('Failed to load exam bank from $assetPath', e, st);
      _cache[key] = [];
      return [];
    }
  }

  ExamBlueprint _parseBlueprint(
    Map<String, dynamic> json,
    ExamProduct product,
  ) {
    final bp = json['blueprint'] as Map<String, dynamic>? ?? const {};
    return ExamBlueprint(
      product: ExamProductAsset.fromId(bp['product'] as String? ?? product.id),
      version: bp['version'] as String? ?? 'unversioned',
      effectiveDate: bp['effective_date'] as String? ?? 'unknown',
      scoringRule: ExamScoringRuleId.fromId(bp['scoring_rule'] as String?),
    );
  }

  MockExam _parseExam(
    Map<String, dynamic> json,
    ExamLevel level,
    ExamBlueprint blueprint,
  ) {
    final sectionsJson = json['sections'] as List<dynamic>? ?? [];
    final sections =
        sectionsJson
            .whereType<Map<String, dynamic>>()
            .map(_parseSection)
            .toList();

    return MockExam(
      level: level,
      blueprint: blueprint,
      totalTimeMinutes: json['total_time_minutes'] as int? ?? 120,
      sections: sections,
    );
  }

  MockExamSection _parseSection(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'reading';
    final type = ExamSectionType.values.byName(typeStr);

    final questionsJson = json['questions'] as List<dynamic>? ?? [];
    final questions = questionsJson.whereType<Map<String, dynamic>>().toList();

    return MockExamSection(
      type: type,
      timeLimitMinutes: json['time_limit_minutes'] as int? ?? 30,
      questions: questions,
      maxScore: json['max_score'] as int? ?? 100,
    );
  }

  @override
  Future<entity.ExamResult> saveResult(entity.ExamResult result) async {
    final id = await _db
        .into(_db.examResults)
        .insert(
          db.ExamResultsCompanion.insert(
            level: result.level.name,
            product: Value(result.product.id),
            takenAt: Value(result.takenAt),
            readingScore: Value(result.readingScore),
            listeningScore: Value(result.listeningScore),
            writingScore: Value(result.writingScore),
            speakingScore: Value(result.speakingScore),
            totalScore: Value(result.totalScore),
            passed: Value(result.passed),
            details: Value(
              result.details != null ? jsonEncode(result.details) : null,
            ),
          ),
        );

    return entity.ExamResult(
      id: id,
      level: result.level,
      product: result.product,
      takenAt: result.takenAt,
      readingScore: result.readingScore,
      listeningScore: result.listeningScore,
      writingScore: result.writingScore,
      speakingScore: result.speakingScore,
      totalScore: result.totalScore,
      passed: result.passed,
      details: result.details,
    );
  }

  @override
  Future<List<entity.ExamResult>> getResults(
    ExamLevel level, {
    ExamProduct? product,
  }) async {
    final rows =
        await (_db.select(_db.examResults)
              ..where((r) => r.level.equals(level.name))
              ..where(
                (r) =>
                    product == null
                        ? const Constant(true)
                        : r.product.equals(product.id),
              )
              ..orderBy([(r) => OrderingTerm.desc(r.takenAt)]))
            .get();

    return rows
        .map(
          (r) => entity.ExamResult(
            id: r.id,
            level: r.level == 'a2' ? ExamLevel.a2 : ExamLevel.a1,
            product: ExamProductAsset.fromId(r.product),
            takenAt: r.takenAt,
            readingScore: r.readingScore,
            listeningScore: r.listeningScore,
            writingScore: r.writingScore,
            speakingScore: r.speakingScore,
            totalScore: r.totalScore,
            passed: r.passed,
            details:
                r.details != null
                    ? jsonDecode(r.details!) as Map<String, dynamic>
                    : null,
          ),
        )
        .toList();
  }
}

/// Fallback sample exam used when the JSON bank is unavailable.
///
/// Listening questions carry `audio_text` (spoken via TTS, never shown);
/// reading questions carry an optional `passage`.
MockExam buildSampleExam(
  ExamLevel level, {
  ExamProduct product = ExamProduct.permanentResidence,
}) {
  final isA1 = level == ExamLevel.a1;

  final readingQuestions = [
    {
      'passage':
          isA1
              ? 'Ahoj, jmenuji se Petra. Bydlím v Praze. Ráda čtu knihy a poslouchám hudbu. Každé ráno piju kávu a jím rohlík.'
              : 'Dobrý den, jmenuji se Tomáš a pracuji v bance v centru Prahy. Každý den vstávám v šest hodin a jedu metrem do práce. V práci jsem od osmi do čtyř hodin odpoledne.',
      'prompt':
          isA1
              ? 'What does Petra do every morning?'
              : 'How does Tomáš get to work?',
      'options':
          isA1
              ? [
                'Drinks coffee and eats bread',
                'Goes to work by car',
                'Reads books in the park',
                'Listens to music',
              ]
              : ['By metro', 'By car', 'By bus', 'On foot'],
      'correct_answer': 0,
      'points': 12,
    },
    {
      'prompt': 'Where does the person live/work?',
      'options': ['Brno', 'Praha', 'Ostrava', 'Plzeň'],
      'correct_answer': 1,
      'points': 13,
    },
  ];

  final listeningQuestions = [
    {
      'audio_text': 'Dobré ráno, jak se máte?',
      'prompt': 'What does the speaker say?',
      'options': [
        'Good morning, how are you?',
        'Good evening, see you later',
        'Good night, sleep well',
        'Goodbye, take care',
      ],
      'correct_answer': 0,
      'points': 12,
    },
    {
      'audio_text': 'Mám hlad.',
      'prompt': 'What does the speaker want?',
      'options': ['A drink', 'Food', 'Sleep', 'Help'],
      'correct_answer': 1,
      'points': 13,
    },
  ];

  final writingQuestion = {
    'prompt':
        isA1
            ? 'Write about yourself: your name, where you live, and what you like to do. (30+ words)'
            : 'Write about your typical day: when you wake up, what you do at work/school, and your evening routine. (50+ words)',
    'min_words': isA1 ? 30 : 50,
    'points': 20,
  };

  final speakingQuestion = {
    'prompt': 'Read the following Czech text aloud:',
    'target_text':
        isA1
            ? 'Ahoj, jmenuji se Student. Bydlím v Praze a učím se česky.'
            : 'Dobrý den, pracuji v kanceláři a každý den dojíždím metrem. Ve volném čase rád čtu a cestuji.',
    'points': 40,
  };

  return MockExam(
    level: level,
    blueprint: ExamBlueprint(
      product: product,
      version: 'sample',
      effectiveDate: 'unknown',
      scoringRule: ExamScoringRule.rawPointsWrittenSpeakingGate,
    ),
    totalTimeMinutes: isA1 ? 30 : 45,
    sections: [
      MockExamSection(
        type: ExamSectionType.reading,
        timeLimitMinutes: 8,
        questions: readingQuestions,
        maxScore: 25,
      ),
      MockExamSection(
        type: ExamSectionType.listening,
        timeLimitMinutes: 8,
        questions: listeningQuestions,
        maxScore: 25,
      ),
      MockExamSection(
        type: ExamSectionType.writing,
        timeLimitMinutes: 10,
        questions: [writingQuestion],
        maxScore: 20,
      ),
      MockExamSection(
        type: ExamSectionType.speaking,
        timeLimitMinutes: 5,
        questions: [speakingQuestion],
        maxScore: 40,
      ),
    ],
  );
}
