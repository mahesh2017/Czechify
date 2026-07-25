import '../../core/utils/ipa.dart';
import 'phoneme_features.dart';

/// Phoneme-level pronunciation scoring (a GOP-style comparison).
///
/// The existing [PronunciationScorer] compares an ASR *transcript* against the
/// target text. That can only ever catch wrong or missing words: ASR is built
/// to produce plausible text, so it silently repairs a learner's accent — say
/// `rzeka` for `řeka` and Whisper still writes `řeka`, which then scores 100%.
///
/// This scorer compares *sounds* instead. Given the phonemes actually produced
/// (from a phoneme recogniser) and the phonemes expected (the `ipa` field
/// already carried by every vocabulary entry), it reports which specific sound
/// went wrong — the difference between "that was incorrect" and "your ř came
/// out as a plain r".
class PhonemeScorer {
  /// Weights by pedagogical importance. Getting `ř` wrong matters more than
  /// getting a schwa slightly off, and Czech vowel length is meaning-bearing
  /// (`byt` = flat, `být` = to be).
  static const double _weightRhacek = 3.0;
  static const double _weightLongVowel = 2.5;
  static const double _weightPalatal = 2.0;
  static const double _weightDefault = 1.0;

  /// Below this, a sound is called out as mispronounced.
  static const double _acceptThreshold = 0.75;

  /// Sounds English speakers routinely flatten: the true palatals plus the
  /// postalveolars behind č/š/ž.
  static const _palatals = {'ɟ', 'c', 'ɲ', 't͡ʃ', 'tʃ', 'ʃ', 'ʒ', 'd͡ʒ', 'dʒ'};

  double weightFor(Ipa phoneme) {
    if (phoneme.base == 'r̝') return _weightRhacek;
    if (phoneme.isLong) return _weightLongVowel;
    if (_palatals.contains(phoneme.base)) return _weightPalatal;
    return _weightDefault;
  }

  PhonemeAssessment score({
    required String expectedIpa,
    required String actualIpa,
  }) {
    final expected = IpaTokenizer.tokenize(expectedIpa);
    final actual = IpaTokenizer.tokenize(actualIpa);

    if (expected.isEmpty) {
      return const PhonemeAssessment(
        overallScore: 0,
        comparisons: [],
        feedback: [],
      );
    }

    final comparisons = _align(expected, actual);

    // Weighted mean over expected sounds. Insertions are counted in the
    // denominator so padding the utterance cannot raise the score.
    var weightedTotal = 0.0;
    var weightSum = 0.0;
    for (final c in comparisons) {
      if (c.expected == null) {
        // Sound the learner added — penalise at default weight.
        weightSum += _weightDefault;
        continue;
      }
      final w = weightFor(c.expected!);
      weightedTotal += c.similarity * w;
      weightSum += w;
    }

    final overall = weightSum == 0 ? 0.0 : (weightedTotal / weightSum);

    // A weighted mean alone is too kind about the sound that defines a word:
    // saying "reka" for "řeka" gets three of four phonemes right and lands in
    // the 80s, which would tell the learner "good" about the one thing they
    // cannot yet do. If a heavily-weighted sound failed, the band is held back
    // regardless of the average.
    final missedCritical = comparisons.any((c) =>
        c.expected != null &&
        weightFor(c.expected!) >= _weightLongVowel &&
        c.similarity < _acceptThreshold);

    return PhonemeAssessment(
      overallScore: overall.clamp(0.0, 1.0),
      comparisons: comparisons,
      feedback: _feedback(comparisons),
      missedCriticalSound: missedCritical,
    );
  }

  /// Needleman-Wunsch over phonemes, so an inserted or dropped sound shifts
  /// the alignment instead of corrupting every comparison after it.
  List<PhonemeComparison> _align(List<Ipa> expected, List<Ipa> actual) {
    final m = expected.length;
    final n = actual.length;
    const gap = -0.5;

    final score = List.generate(m + 1, (_) => List<double>.filled(n + 1, 0));
    final trace = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (var i = 1; i <= m; i++) {
      score[i][0] = score[i - 1][0] + gap;
      trace[i][0] = 1;
    }
    for (var j = 1; j <= n; j++) {
      score[0][j] = score[0][j - 1] + gap;
      trace[0][j] = 2;
    }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final diag = score[i - 1][j - 1] +
            CzechPhonemes.similarity(expected[i - 1].symbol, actual[j - 1].symbol);
        final up = score[i - 1][j] + gap;
        final left = score[i][j - 1] + gap;

        if (diag >= up && diag >= left) {
          score[i][j] = diag;
          trace[i][j] = 0;
        } else if (up >= left) {
          score[i][j] = up;
          trace[i][j] = 1;
        } else {
          score[i][j] = left;
          trace[i][j] = 2;
        }
      }
    }

    final out = <PhonemeComparison>[];
    var i = m;
    var j = n;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && trace[i][j] == 0) {
        final e = expected[i - 1];
        final a = actual[j - 1];
        out.add(PhonemeComparison(
          expected: e,
          actual: a,
          similarity: CzechPhonemes.similarity(e.symbol, a.symbol),
        ));
        i--;
        j--;
      } else if (i > 0 && (j == 0 || trace[i][j] == 1)) {
        out.add(PhonemeComparison(
          expected: expected[i - 1],
          actual: null,
          similarity: 0,
        ));
        i--;
      } else {
        out.add(PhonemeComparison(
          expected: null,
          actual: actual[j - 1],
          similarity: 0,
        ));
        j--;
      }
    }

    return out.reversed.toList();
  }

  /// Targeted, teachable feedback — at most a few points, worst first.
  List<String> _feedback(List<PhonemeComparison> comparisons) {
    final problems = comparisons
        .where((c) => c.expected != null && c.similarity < _acceptThreshold)
        .toList()
      ..sort((a, b) {
        final byWeight = weightFor(b.expected!).compareTo(weightFor(a.expected!));
        return byWeight != 0 ? byWeight : a.similarity.compareTo(b.similarity);
      });

    final tips = <String>[];
    final seen = <String>{};

    for (final p in problems) {
      final e = p.expected!;
      if (!seen.add(e.symbol)) continue;

      if (e.base == 'r̝') {
        tips.add(p.actual?.base == 'r'
            ? 'Your "ř" came out as a plain "r". Keep the tongue trilling but '
                'press it closer to the ridge so it buzzes.'
            : 'Work on "ř" — trill the tongue and add a buzz at the same time.');
      } else if (e.isLong && p.actual != null && !p.actual!.isLong) {
        tips.add('"${e.symbol}" is a long vowel — hold it about twice as long. '
            'Czech uses length to change meaning (byt vs být).');
      } else if (!e.isLong && p.actual != null && p.actual!.isLong) {
        tips.add('"${e.symbol}" is short here — you lengthened it.');
      } else if (_palatals.contains(e.base)) {
        tips.add('"${e.symbol}" is palatal — press the middle of the tongue '
            'against the hard palate.');
      } else if (p.actual == null) {
        tips.add('You dropped the "${e.symbol}" sound.');
      } else {
        tips.add('"${e.symbol}" came out closer to "${p.actual!.symbol}".');
      }

      if (tips.length == 3) break;
    }

    return tips;
  }
}

class PhonemeComparison {
  /// Null when the learner produced a sound that isn't in the target.
  final Ipa? expected;

  /// Null when the learner omitted an expected sound.
  final Ipa? actual;

  /// 0.0–1.0 articulatory closeness.
  final double similarity;

  const PhonemeComparison({
    required this.expected,
    required this.actual,
    required this.similarity,
  });

  bool get isCorrect => similarity >= PhonemeScorer._acceptThreshold;
}

class PhonemeAssessment {
  final double overallScore;
  final List<PhonemeComparison> comparisons;
  final List<String> feedback;

  /// True when a sound this scorer treats as critical (ř, vowel length, the
  /// palatals) was missed. Holds the band back so a high average can't paper
  /// over the sound the learner most needs to hear about.
  final bool missedCriticalSound;

  const PhonemeAssessment({
    required this.overallScore,
    required this.comparisons,
    required this.feedback,
    this.missedCriticalSound = false,
  });

  /// Deliberately a band, not a percentage. The method does not support the
  /// precision a number like "93%" implies, and a band is more useful to a
  /// learner than false precision.
  PronunciationBand get band {
    var result = switch (overallScore) {
      >= 0.85 => PronunciationBand.excellent,
      >= 0.65 => PronunciationBand.good,
      >= 0.4 => PronunciationBand.needsWork,
      _ => PronunciationBand.tryAgain,
    };
    // "Excellent" alongside a correction is self-contradictory: excellent has
    // to mean there is nothing to fix.
    if (feedback.isNotEmpty && result == PronunciationBand.excellent) {
      result = PronunciationBand.good;
    }
    if (missedCriticalSound && result.index < PronunciationBand.needsWork.index) {
      result = PronunciationBand.needsWork;
    }
    return result;
  }

  /// What to actually show. When nothing matched, per-sound tips are noise —
  /// the useful message is that the attempt wasn't recognisable at all.
  List<String> get displayFeedback => band == PronunciationBand.tryAgain
      ? const ["That didn't match the phrase — listen again and try once more."]
      : feedback;
}

/// Ordered best to worst, so `index` comparisons above read naturally.
enum PronunciationBand { excellent, good, needsWork, tryAgain }
