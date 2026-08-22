import '../entities/pronunciation_result.dart';
import '../../core/utils/text_normalizer.dart';
import '../../core/utils/phoneme_mapper.dart';

/// Custom pronunciation scoring engine for Czech.
///
/// Azure Pronunciation Assessment doesn't support Czech,
/// so we use STT transcription + text comparison + phonetic scoring.
class PronunciationScorer {
  final PhonemeMapper _phonemeMapper = PhonemeMapper();

  /// Score user's pronunciation against expected text.
  ///
  /// Pipeline:
  /// 1. Normalize both texts (lowercase, strip punctuation)
  /// 2. Sequence-align words (Needleman-Wunsch) so insertions, deletions,
  ///    and reordering are handled — not just positional comparison.
  /// 3. Phonetic comparison for Czech-specific sounds
  /// 4. Return per-word and overall scores
  PronunciationResult score({
    required String expectedText,
    required String actualTranscription,
  }) {
    final normalizedExpected = TextNormalizer.normalize(expectedText);
    final normalizedActual = TextNormalizer.normalize(actualTranscription);

    // Sequence-align words — handles extra, missing, and reordered words.
    final alignment = _alignWords(normalizedExpected, normalizedActual);

    // Phonetic scoring for Czech problem sounds
    final problemSounds = _scorePhonemes(alignment.wordScores);

    // Overall accuracy
    final accuracy = _calculateAccuracy(
      alignment.wordScores,
      insertionCount: alignment.insertionCount,
    );

    final tips = _tips(problemSounds);

    return PronunciationResult(
      overallScore: accuracy,
      wordScores: alignment.wordScores,
      problemSounds: problemSounds,
      tips: tips,
      insertionCount: alignment.insertionCount,
    );
  }

  /// Align words between expected and actual using Needleman-Wunsch global
  /// alignment. This handles:
  /// - Extra words spoken (insertions in actual)
  /// - Missing words (deletions — expected but not spoken)
  /// - Reordered words (matched by best similarity, not position)
  ///
  /// A gap in the expected sequence means the user spoke an extra word;
  /// a gap in the actual sequence means the user skipped a word.
  _WordAlignment _alignWords(String expected, String actual) {
    final expectedWords =
        expected.split(' ').where((w) => w.isNotEmpty).toList();
    final actualWords = actual.split(' ').where((w) => w.isNotEmpty).toList();

    if (expectedWords.isEmpty) {
      return _WordAlignment(
        wordScores: const [],
        insertionCount: actualWords.length,
      );
    }
    if (actualWords.isEmpty) {
      // All expected words are missed.
      return _WordAlignment(
        wordScores: [
          for (final w in expectedWords)
            WordScore(word: w, isCorrect: false, score: 0.0),
        ],
        insertionCount: 0,
      );
    }

    final alignment = _needlemanWunsch(expectedWords, actualWords);

    // Build word scores from aligned pairs. Only emit scores for expected
    // words — extra spoken words (gaps in expected) are tracked but don't
    // inflate the score.
    final results = <WordScore>[];
    var insertionCount = 0;
    for (final pair in alignment) {
      if (pair.expected == null) {
        // Extra word spoken — user said something not in the expected text.
        // Keep per-word feedback tied to the expected phrase, but count the
        // insertion in the overall-score denominator below.
        insertionCount++;
        continue;
      }
      if (pair.actual == null) {
        // Expected word was skipped — score 0.
        results.add(
          WordScore(word: pair.expected!, isCorrect: false, score: 0.0),
        );
      } else {
        final isMatch =
            pair.expected!.toLowerCase() == pair.actual!.toLowerCase();
        final similarity = _wordSimilarity(pair.expected!, pair.actual!);
        results.add(
          WordScore(
            word: pair.expected!,
            isCorrect: isMatch,
            score: similarity,
          ),
        );
      }
    }

    return _WordAlignment(wordScores: results, insertionCount: insertionCount);
  }

  /// Needleman-Wunsch global sequence alignment for word lists.
  ///
  /// Returns aligned pairs where either side may be null (gap).
  /// Match score = word similarity (0.0–1.0), mismatch penalty = 0,
  /// gap penalty = -0.1 (small, so near-matches are preferred over gaps).
  List<_AlignPair> _needlemanWunsch(
    List<String> expected,
    List<String> actual,
  ) {
    final m = expected.length;
    final n = actual.length;

    // Score matrix.
    final score = List.generate(m + 1, (i) => List<double>.filled(n + 1, 0));
    // Traceback matrix: 0 = diagonal (match/mismatch), 1 = up (gap in actual),
    // 2 = left (gap in expected).
    final trace = List.generate(m + 1, (i) => List<int>.filled(n + 1, 0));

    const gapPenalty = -0.1;

    // Initialize first row/column.
    for (var i = 1; i <= m; i++) {
      score[i][0] = score[i - 1][0] + gapPenalty;
      trace[i][0] = 1;
    }
    for (var j = 1; j <= n; j++) {
      score[0][j] = score[0][j - 1] + gapPenalty;
      trace[0][j] = 2;
    }

    // Fill matrix.
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final matchScore =
            score[i - 1][j - 1] +
            _wordSimilarity(expected[i - 1], actual[j - 1]);
        final upScore = score[i - 1][j] + gapPenalty;
        final leftScore = score[i][j - 1] + gapPenalty;

        if (matchScore >= upScore && matchScore >= leftScore) {
          score[i][j] = matchScore;
          trace[i][j] = 0;
        } else if (upScore >= leftScore) {
          score[i][j] = upScore;
          trace[i][j] = 1;
        } else {
          score[i][j] = leftScore;
          trace[i][j] = 2;
        }
      }
    }

    // Traceback.
    final alignment = <_AlignPair>[];
    var i = m;
    var j = n;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && trace[i][j] == 0) {
        alignment.add(_AlignPair(expected[i - 1], actual[j - 1]));
        i--;
        j--;
      } else if (i > 0 && (j == 0 || trace[i][j] == 1)) {
        alignment.add(_AlignPair(expected[i - 1], null));
        i--;
      } else {
        alignment.add(_AlignPair(null, actual[j - 1]));
        j--;
      }
    }

    return alignment.reversed.toList();
  }

  /// Calculate word similarity using character-level comparison.
  double _wordSimilarity(String a, String b) {
    if (a.toLowerCase() == b.toLowerCase()) return 1.0;
    final distance = _levenshtein(a.toLowerCase(), b.toLowerCase());
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
    return 1.0 - (distance / maxLen);
  }

  /// Levenshtein distance between two strings.
  int _levenshtein(String s1, String s2) {
    // Use two rolling rows for O(min(m,n)) space instead of full matrix.
    final short = s1.length <= s2.length ? s1 : s2;
    final long = s1.length <= s2.length ? s2 : s1;
    final m = short.length;
    final n = long.length;

    var prev = List<int>.generate(m + 1, (i) => i);
    var curr = List<int>.filled(m + 1, 0);

    for (var j = 1; j <= n; j++) {
      curr[0] = j;
      for (var i = 1; i <= m; i++) {
        final cost =
            short[i - 1].toLowerCase() == long[j - 1].toLowerCase() ? 0 : 1;
        curr[i] = [
          prev[i] + 1,
          curr[i - 1] + 1,
          prev[i - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }

    return prev[m];
  }

  /// Score Czech-specific phonemes.
  List<ProblemSound> _scorePhonemes(List<WordScore> wordScores) {
    final problems = <ProblemSound>[];

    for (final word in wordScores) {
      if (word.score < 0.7) {
        // Check for Czech-specific problem sounds in the expected word
        final phonemes = _phonemeMapper.getProblemPhonemes(word.word);
        for (final phoneme in phonemes) {
          problems.add(
            ProblemSound(phoneme: phoneme, word: word.word, score: word.score),
          );
        }
      }
    }

    return problems;
  }

  /// Calculate overall accuracy from word scores.
  double _calculateAccuracy(
    List<WordScore> wordScores, {
    required int insertionCount,
  }) {
    final denominator = wordScores.length + insertionCount;
    if (denominator == 0) return 0.0;
    final totalScore = wordScores.fold<double>(0.0, (sum, w) => sum + w.score);
    return totalScore / denominator;
  }

  /// Turn problem sounds into coaching codes.
  ///
  /// Codes, not sentences: this is a pure engine and the learner may not be
  /// reading English. The presentation layer says these out loud.
  List<PronunciationTip> _tips(List<ProblemSound> problems) {
    if (problems.isEmpty) {
      return const [PronunciationTip(PronunciationTipCode.excellent)];
    }

    return problems.map((p) {
      return switch (p.phoneme) {
        'ř' => const PronunciationTip(PronunciationTipCode.rolledR),
        'ě' => const PronunciationTip(PronunciationTipCode.softeningE),
        'long_vowel' => const PronunciationTip(
          PronunciationTipCode.vowelLength,
        ),
        // "other" is the mapper's internal bucket for "no specific Czech
        // problem sound", so naming it back to the learner is meaningless —
        // "Check pronunciation of 'other' in 'vltava'" tells them nothing.
        'other' => PronunciationTip(
          PronunciationTipCode.repeatWord,
          word: p.word,
        ),
        _ => PronunciationTip(
          PronunciationTipCode.checkSound,
          sound: p.phoneme,
          word: p.word,
        ),
      };
    }).toList();
  }
}

/// A pair in a sequence alignment — either side may be null (gap).
class _AlignPair {
  final String? expected;
  final String? actual;

  const _AlignPair(this.expected, this.actual);
}

class _WordAlignment {
  final List<WordScore> wordScores;
  final int insertionCount;

  const _WordAlignment({
    required this.wordScores,
    required this.insertionCount,
  });
}
