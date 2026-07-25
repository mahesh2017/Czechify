/// A precise curriculum contract failure tied to its source pack and JSON path.
class CurriculumContractIssue {
  const CurriculumContractIssue({
    required this.packKey,
    required this.path,
    required this.message,
    this.exerciseId,
  });

  final String packKey;
  final String path;
  final String message;
  final int? exerciseId;

  @override
  String toString() {
    final id = exerciseId == null ? '' : ' exercise $exerciseId';
    return '$packKey$id $path: $message';
  }
}

/// Raised before a bundled or remote curriculum snapshot can be installed.
class CurriculumContractException implements Exception {
  CurriculumContractException(this.issues);

  final List<CurriculumContractIssue> issues;

  @override
  String toString() {
    final preview = issues.take(10).map((issue) => '  - $issue').join('\n');
    final remaining = issues.length > 10
        ? '\n  ... and ${issues.length - 10} more issue(s)'
        : '';
    return 'Curriculum contract validation failed with ${issues.length} '
        'issue(s):\n$preview$remaining';
  }
}

/// Validates executable curriculum contracts before content reaches Drift or
/// presentation widgets.
///
/// This starts with common exercise metadata and the contracts that caused
/// deterministic runtime failures. Additional exercise-specific contracts are
/// added here as their schemas are normalized.
class CurriculumContractValidator {
  const CurriculumContractValidator._();

  static const supportedTypes = <String>{
    'multiple_choice',
    'fill_blank',
    'translation',
    'word_order',
    'dictation',
    'pronunciation',
    'declension_table',
    'dialogue',
    'matching',
    'error_correction',
    'reading_comprehension',
    'listening_comprehension',
    'writing_task',
    'speaking_task',
    'teaching',
  };

  static void validateSnapshot(Map<String, Object?> packs) {
    final issues = collectSnapshotIssues(packs);
    if (issues.isNotEmpty) throw CurriculumContractException(issues);
  }

  static List<CurriculumContractIssue> collectSnapshotIssues(
    Map<String, Object?> packs,
  ) {
    final issues = <CurriculumContractIssue>[];
    final exerciseIds = <int, String>{};

    final lessonEntries =
        packs.entries.where((entry) => entry.key.contains('/lessons/')).toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in lessonEntries) {
      issues.addAll(
        _validateLessonPack(entry.key, entry.value, exerciseIds: exerciseIds),
      );
    }
    return issues;
  }

  static List<CurriculumContractIssue> _validateLessonPack(
    String packKey,
    Object? payload, {
    required Map<int, String> exerciseIds,
  }) {
    final issues = <CurriculumContractIssue>[];

    if (payload is! Map) {
      return [
        CurriculumContractIssue(
          packKey: packKey,
          path: r'$',
          message: 'lesson pack must be a JSON object',
        ),
      ];
    }

    final lesson = Map<String, Object?>.from(payload);
    final lessonId = lesson['id'];
    if (lessonId is! int) {
      issues.add(
        CurriculumContractIssue(
          packKey: packKey,
          path: r'$.id',
          message: 'must be an integer',
        ),
      );
    }

    final rawExercises = lesson['exercises'];
    if (rawExercises is! List) {
      issues.add(
        CurriculumContractIssue(
          packKey: packKey,
          path: r'$.exercises',
          message: 'must be an array',
        ),
      );
      return issues;
    }

    for (var index = 0; index < rawExercises.length; index++) {
      final raw = rawExercises[index];
      final basePath =
          r'$.exercises['
          '$index]';
      if (raw is! Map) {
        issues.add(
          CurriculumContractIssue(
            packKey: packKey,
            path: basePath,
            message: 'must be an object',
          ),
        );
        continue;
      }

      final exercise = Map<String, Object?>.from(raw);
      final exerciseId = exercise['id'];
      final typedId = exerciseId is int ? exerciseId : null;
      if (typedId == null) {
        issues.add(
          CurriculumContractIssue(
            packKey: packKey,
            path: '$basePath.id',
            message: 'must be an integer',
          ),
        );
      } else {
        final previousPack = exerciseIds[typedId];
        if (previousPack != null) {
          issues.add(
            CurriculumContractIssue(
              packKey: packKey,
              exerciseId: typedId,
              path: '$basePath.id',
              message: 'duplicates an exercise ID from $previousPack',
            ),
          );
        } else {
          exerciseIds[typedId] = packKey;
        }
      }

      if (lessonId is int && exercise['lesson_id'] != lessonId) {
        issues.add(
          CurriculumContractIssue(
            packKey: packKey,
            exerciseId: typedId,
            path: '$basePath.lesson_id',
            message: 'must equal containing lesson ID $lessonId',
          ),
        );
      }

      final type = exercise['type'];
      if (type is! String || !supportedTypes.contains(type)) {
        issues.add(
          CurriculumContractIssue(
            packKey: packKey,
            exerciseId: typedId,
            path: '$basePath.type',
            message: 'must be a supported exercise type',
          ),
        );
        continue;
      }

      final prompt = exercise['prompt'];
      if (prompt is! String || prompt.trim().isEmpty) {
        issues.add(
          CurriculumContractIssue(
            packKey: packKey,
            exerciseId: typedId,
            path: '$basePath.prompt',
            message: 'must be a non-empty string',
          ),
        );
      }

      final rawData = exercise['data'];
      if (rawData is! Map) {
        issues.add(
          CurriculumContractIssue(
            packKey: packKey,
            exerciseId: typedId,
            path: '$basePath.data',
            message: 'must be an object',
          ),
        );
        continue;
      }
      final data = Map<String, Object?>.from(rawData);
      if (data['type'] != type) {
        issues.add(
          CurriculumContractIssue(
            packKey: packKey,
            exerciseId: typedId,
            path: '$basePath.data.type',
            message: 'must match exercise type $type',
          ),
        );
      }

      switch (type) {
        case 'declension_table':
          _validateDeclensionTable(issues, packKey, basePath, typedId, data);
        case 'word_order':
          _validateWordOrder(
            issues,
            packKey,
            basePath,
            typedId,
            data,
            exercise['answer_key'],
          );
        case 'dialogue':
          _validateDialogue(issues, packKey, basePath, typedId, data);
        case 'multiple_choice':
          _validateMultipleChoice(issues, packKey, basePath, typedId, data);
        case 'translation':
          _validateTranslation(issues, packKey, basePath, typedId, data);
        case 'fill_blank':
          _validateFillBlank(issues, packKey, basePath, typedId, data);
        case 'dictation':
          _requireNonEmptyString(
            issues,
            packKey,
            basePath,
            typedId,
            data,
            'expected_text',
          );
        case 'pronunciation':
          _validatePronunciation(issues, packKey, basePath, typedId, data);
        case 'matching':
          _validateMatching(issues, packKey, basePath, typedId, data);
        case 'error_correction':
          _validateErrorCorrection(issues, packKey, basePath, typedId, data);
        case 'reading_comprehension':
          _validateComprehension(
            issues,
            packKey,
            basePath,
            typedId,
            data,
            textField: 'text_cz',
          );
        case 'listening_comprehension':
          _validateComprehension(
            issues,
            packKey,
            basePath,
            typedId,
            data,
            textField: 'transcript_cz',
          );
        case 'writing_task':
          _validateWritingTask(issues, packKey, basePath, typedId, data);
        case 'speaking_task':
          _validateSpeakingTask(issues, packKey, basePath, typedId, data);
        case 'teaching':
          _validateTeaching(issues, packKey, basePath, typedId, data);
      }
    }

    return issues;
  }

  static void _validateDeclensionTable(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    final word = data['word'];
    final cases = _stringList(data['cases']);
    final rawAnswers = data['answer_key'];
    final answers = rawAnswers is Map
        ? Map<String, Object?>.from(rawAnswers)
        : null;

    void add(String field, String message) {
      issues.add(
        CurriculumContractIssue(
          packKey: packKey,
          exerciseId: exerciseId,
          path: '$basePath.data.$field',
          message: message,
        ),
      );
    }

    if (word is! String || word.trim().isEmpty) {
      add('word', 'must be a non-empty string');
    }
    if (cases == null || cases.isEmpty) {
      add('cases', 'must be a non-empty string array');
    }
    if (answers == null) {
      add('answer_key', 'must be an object keyed by case');
      return;
    }
    if (cases != null) {
      for (final caseName in cases) {
        final answer = answers[caseName];
        if (answer is! String || answer.trim().isEmpty) {
          add('answer_key.$caseName', 'must be a non-empty string');
        }
      }
      final extras = answers.keys.toSet().difference(cases.toSet());
      if (extras.isNotEmpty) {
        add(
          'answer_key',
          'contains answers for unknown cases: ${extras.join(', ')}',
        );
      }
    }
  }

  static void _validateWordOrder(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
    Object? answerKey,
  ) {
    final words = _stringList(data['words']);
    final order = _intList(data['correct_order']);

    void add(String field, String message) {
      issues.add(
        CurriculumContractIssue(
          packKey: packKey,
          exerciseId: exerciseId,
          path: '$basePath.data.$field',
          message: message,
        ),
      );
    }

    if (words == null || words.isEmpty) {
      add('words', 'must be a non-empty string array');
      return;
    }
    if (words.contains('—')) {
      add(
        'words',
        'must contain Czech task tokens only, without an em-dash separator',
      );
    }
    if (order == null || order.isEmpty) {
      add('correct_order', 'must be a non-empty integer array');
      return;
    }
    final invalid = order.where((index) => index < 0 || index >= words.length);
    if (invalid.isNotEmpty) {
      add(
        'correct_order',
        'contains out-of-range indices: ${invalid.toSet().join(', ')}',
      );
    }
    if (order.toSet().length != order.length) {
      add('correct_order', 'must not reuse a token index');
    }
    if (answerKey is String &&
        invalid.isEmpty &&
        _canonicalSentence(order.map((index) => words[index]).join(' ')) !=
            _canonicalSentence(answerKey)) {
      add(
        'correct_order',
        'does not construct the declared answer_key "$answerKey"',
      );
    }
  }

  static void _validateDialogue(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    void add(String field, String message) {
      issues.add(
        CurriculumContractIssue(
          packKey: packKey,
          exerciseId: exerciseId,
          path: '$basePath.data.$field',
          message: message,
        ),
      );
    }

    if (data.containsKey('accepted_answers')) {
      add(
        'accepted_answers',
        'is a legacy ambiguous field; use blank_answers instead',
      );
    }

    final rawLines = data['lines'];
    if (rawLines is! List || rawLines.isEmpty) {
      add('lines', 'must be a non-empty array');
      return;
    }

    var blankCount = 0;
    for (var index = 0; index < rawLines.length; index++) {
      final rawLine = rawLines[index];
      if (rawLine is! Map) {
        add('lines[$index]', 'must be an object');
        continue;
      }
      final line = Map<String, Object?>.from(rawLine);
      if (line.containsKey('text_cz') || line.containsKey('accepted_answers')) {
        add(
          'lines[$index]',
          'contains legacy fields; use text and data.blank_answers',
        );
      }
      final speaker = line['speaker'];
      if (speaker is! String || speaker.trim().isEmpty) {
        add('lines[$index].speaker', 'must be a non-empty string');
      }
      final text = line['text'];
      if (text is! String || text.trim().isEmpty) {
        add('lines[$index].text', 'must be a non-empty string');
        continue;
      }
      if (RegExp(r'_{4,}').hasMatch(text)) {
        add(
          'lines[$index].text',
          'must use exactly three underscores per blank',
        );
      }
      blankCount += '___'.allMatches(text).length;
    }

    if (blankCount == 0) {
      add('lines', 'must contain at least one ___ answer blank');
    }

    final rawAnswers = data['blank_answers'];
    if (rawAnswers is! List) {
      add(
        'blank_answers',
        'must be an array with one alternatives array per blank',
      );
      return;
    }
    if (rawAnswers.length != blankCount) {
      add(
        'blank_answers',
        'has ${rawAnswers.length} entries for $blankCount dialogue blank(s)',
      );
    }
    for (var index = 0; index < rawAnswers.length; index++) {
      final alternatives = _stringList(rawAnswers[index]);
      if (alternatives == null ||
          alternatives.isEmpty ||
          alternatives.any((answer) => answer.trim().isEmpty)) {
        add(
          'blank_answers[$index]',
          'must be a non-empty array of non-empty answer strings',
        );
      }
    }
  }

  static void _validateMultipleChoice(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    final options = _requiredStringList(
      issues,
      packKey,
      basePath,
      exerciseId,
      data,
      'options',
    );
    final correctIndex = data['correct_index'];
    if (correctIndex is! num ||
        correctIndex.toInt() != correctIndex ||
        options == null ||
        correctIndex < 0 ||
        correctIndex >= options.length) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'correct_index',
        'must be an integer index into options',
      );
    }
  }

  static void _validateTranslation(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    _requireNonEmptyString(
      issues,
      packKey,
      basePath,
      exerciseId,
      data,
      'source',
    );
    _requiredStringList(
      issues,
      packKey,
      basePath,
      exerciseId,
      data,
      'accepted_answers',
    );
    final direction = data['direction'];
    if (direction != null &&
        direction != 'en_to_cz' &&
        direction != 'cz_to_en') {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'direction',
        'must be en_to_cz or cz_to_en',
      );
    }
  }

  static void _validateFillBlank(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    final sentence = data['sentence'];
    if (sentence is! String || sentence.trim().isEmpty) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'sentence',
        'must be a non-empty string',
      );
      return;
    }
    final blankCount = RegExp(r'_+').allMatches(sentence).length;
    if (blankCount == 0) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'sentence',
        'must contain at least one underscore blank',
      );
    }
    if (data['blank_count'] != null && data['blank_count'] != blankCount) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'blank_count',
        'must equal the $blankCount blank(s) in sentence',
      );
    }
    if (data.containsKey('accepted_answers')) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'accepted_answers',
        'is a legacy ambiguous field; use blank_answers instead',
      );
    }
    final rawAnswers = data['blank_answers'];
    if (rawAnswers is! List || rawAnswers.length != blankCount) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'blank_answers',
        'must contain one alternatives array per blank',
      );
    } else {
      for (var index = 0; index < rawAnswers.length; index++) {
        final alternatives = _stringList(rawAnswers[index]);
        if (alternatives == null ||
            alternatives.isEmpty ||
            alternatives.any((answer) => answer.trim().isEmpty)) {
          _addDataIssue(
            issues,
            packKey,
            basePath,
            exerciseId,
            'blank_answers[$index]',
            'must be a non-empty array of non-empty answer strings',
          );
        }
      }
    }
  }

  static void _validatePronunciation(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    _requireNonEmptyString(
      issues,
      packKey,
      basePath,
      exerciseId,
      data,
      'target_text',
    );
    final score = data['min_score'];
    if (score != null && (score is! num || score < 0 || score > 100)) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'min_score',
        'must be a number from 0 through 100',
      );
    }
  }

  static void _validateMatching(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    final pairs = data['pairs'];
    if (pairs is! List || pairs.isEmpty) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'pairs',
        'must be a non-empty array',
      );
      return;
    }
    for (var index = 0; index < pairs.length; index++) {
      final pair = pairs[index];
      if (pair is! Map) {
        _addDataIssue(
          issues,
          packKey,
          basePath,
          exerciseId,
          'pairs[$index]',
          'must be an object',
        );
        continue;
      }
      final left = pair['left'] ?? pair['cz'];
      final right = pair['right'] ?? pair['en'];
      if (left is! String ||
          left.trim().isEmpty ||
          right is! String ||
          right.trim().isEmpty) {
        _addDataIssue(
          issues,
          packKey,
          basePath,
          exerciseId,
          'pairs[$index]',
          'must contain non-empty left/right or cz/en strings',
        );
      }
    }
  }

  static void _validateTeaching(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    final heading = data['heading'];
    final body = data['body'];
    final hasHeading = heading is String && heading.trim().isNotEmpty;
    final hasBody = body is String && body.trim().isNotEmpty;
    if (!hasHeading && !hasBody) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'heading',
        'a teaching card must have a heading or body',
      );
    }
    // items are optional (a card can be pure text/video), but when present
    // each row must be renderable and have something to speak. Two shapes are
    // accepted:
    //  - alphabet/number rows: a non-empty `symbol` + a speakable `example`/`say`
    //  - list rows (grammar/vocab): a non-empty Czech `cz` (spoken as-is)
    final items = data['items'];
    if (items != null) {
      if (items is! List) {
        _addDataIssue(
          issues, packKey, basePath, exerciseId, 'items', 'must be an array',
        );
        return;
      }
      bool nonEmpty(Object? v) => v is String && v.trim().isNotEmpty;
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final symbol = item is Map ? item['symbol'] : null;
        final example = item is Map ? item['example'] : null;
        final say = item is Map ? item['say'] : null;
        final cz = item is Map ? item['cz'] : null;

        final alphabetRow =
            nonEmpty(symbol) && (nonEmpty(example) || nonEmpty(say));
        final listRow = nonEmpty(cz);
        if (!alphabetRow && !listRow) {
          _addDataIssue(
            issues,
            packKey,
            basePath,
            exerciseId,
            'items[$index]',
            'must be either a symbol row (symbol + example/say) or a list row '
                '(a non-empty "cz")',
          );
        }
      }
    }
  }

  static void _validateErrorCorrection(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    final sentence = data['sentence_cz'] ?? data['sentence_with_error'];
    if (sentence is! String || sentence.trim().isEmpty) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'sentence_cz',
        'must provide sentence_cz or sentence_with_error',
      );
    }
    _requireNonEmptyString(
      issues,
      packKey,
      basePath,
      exerciseId,
      data,
      'correct_sentence_cz',
    );
    final answers = data['accepted_answers'];
    if (answers != null) {
      _requiredStringList(
        issues,
        packKey,
        basePath,
        exerciseId,
        data,
        'accepted_answers',
      );
    }
  }

  static void _validateComprehension(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data, {
    required String textField,
  }) {
    _requireNonEmptyString(
      issues,
      packKey,
      basePath,
      exerciseId,
      data,
      textField,
    );
    final questions = data['questions'];
    if (questions is! List || questions.isEmpty) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'questions',
        'must be a non-empty array',
      );
      return;
    }
    for (var index = 0; index < questions.length; index++) {
      final question = questions[index];
      if (question is! Map) {
        _addDataIssue(
          issues,
          packKey,
          basePath,
          exerciseId,
          'questions[$index]',
          'must be an object',
        );
        continue;
      }
      final options = _stringList(question['options']);
      final correctIndex = question['correct_index'];
      final prompt = question['question_cz'] ?? question['question_en'];
      if (prompt is! String || prompt.trim().isEmpty) {
        _addDataIssue(
          issues,
          packKey,
          basePath,
          exerciseId,
          'questions[$index]',
          'must provide a non-empty question',
        );
      }
      if (options == null ||
          options.isEmpty ||
          options.any((option) => option.trim().isEmpty)) {
        _addDataIssue(
          issues,
          packKey,
          basePath,
          exerciseId,
          'questions[$index].options',
          'must be a non-empty string array',
        );
      }
      if (correctIndex is! num ||
          correctIndex.toInt() != correctIndex ||
          options == null ||
          correctIndex < 0 ||
          correctIndex >= options.length) {
        _addDataIssue(
          issues,
          packKey,
          basePath,
          exerciseId,
          'questions[$index].correct_index',
          'must be an integer index into options',
        );
      }
    }
  }

  static void _validateWritingTask(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    _requireAtLeastOnePrompt(issues, packKey, basePath, exerciseId, data);
    final minWords = data['min_words'];
    final maxWords = data['max_words'];
    if (minWords is! int || minWords < 1) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'min_words',
        'must be a positive integer',
      );
    }
    if (maxWords is! int ||
        maxWords < 1 ||
        (minWords is int && maxWords < minWords)) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'max_words',
        'must be an integer greater than or equal to min_words',
      );
    }
  }

  static void _validateSpeakingTask(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    _requireAtLeastOnePrompt(issues, packKey, basePath, exerciseId, data);
    final duration = data['min_duration_seconds'];
    if (duration is! int || duration < 1) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'min_duration_seconds',
        'must be a positive integer',
      );
    }
  }

  static void _requireAtLeastOnePrompt(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
  ) {
    final promptCz = data['prompt_cz'];
    final promptEn = data['prompt_en'];
    if ((promptCz is! String || promptCz.trim().isEmpty) &&
        (promptEn is! String || promptEn.trim().isEmpty)) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        'prompt_en',
        'must provide a non-empty prompt_en or prompt_cz',
      );
    }
  }

  static void _requireNonEmptyString(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
    String field,
  ) {
    final value = data[field];
    if (value is! String || value.trim().isEmpty) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        field,
        'must be a non-empty string',
      );
    }
  }

  static List<String>? _requiredStringList(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    Map<String, Object?> data,
    String field,
  ) {
    final values = _stringList(data[field]);
    if (values == null ||
        values.isEmpty ||
        values.any((value) => value.trim().isEmpty)) {
      _addDataIssue(
        issues,
        packKey,
        basePath,
        exerciseId,
        field,
        'must be a non-empty array of non-empty strings',
      );
      return null;
    }
    return values;
  }

  static void _addDataIssue(
    List<CurriculumContractIssue> issues,
    String packKey,
    String basePath,
    int? exerciseId,
    String field,
    String message,
  ) {
    issues.add(
      CurriculumContractIssue(
        packKey: packKey,
        exerciseId: exerciseId,
        path: '$basePath.data.$field',
        message: message,
      ),
    );
  }

  static List<String>? _stringList(Object? value) {
    if (value is! List || value.any((item) => item is! String)) return null;
    return value.cast<String>();
  }

  static List<int>? _intList(Object? value) {
    if (value is! List || value.any((item) => item is! int)) return null;
    return value.cast<int>();
  }

  static String _canonicalSentence(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-záčďéěíňóřšťúůýž0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
