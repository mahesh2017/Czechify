/// A single piece of coaching, as a code the presentation layer renders.
///
/// The scorers used to hand back finished English sentences — "Practice the
/// ř sound — roll the tongue slightly further back." — straight out of the
/// domain. A learner running the app in Czech was coached in English, and
/// there was no way to translate a word of it without editing an engine.
enum PronunciationTipCode {
  /// Nothing to fix.
  excellent,

  /// The attempt did not resemble the phrase at all, so per-sound tips would
  /// be noise; the useful message is that it wasn't recognisable.
  unrecognisable,

  /// ř came out as a plain r.
  rolledRAsPlainR,

  /// ř in general.
  rolledR,

  /// ě softens the consonant before it.
  softeningE,

  /// Czech vowel length in general.
  vowelLength,

  /// A long vowel said short. Carries [PronunciationTip.sound].
  vowelTooShort,

  /// A short vowel said long. Carries [PronunciationTip.sound].
  vowelTooLong,

  /// A palatal consonant. Carries [PronunciationTip.sound].
  palatal,

  /// The sound was missing entirely. Carries [PronunciationTip.sound].
  soundDropped,

  /// One sound came out as another. Carries [PronunciationTip.sound] and
  /// [PronunciationTip.heard].
  soundSubstituted,

  /// No specific sound to name. Carries [PronunciationTip.word].
  repeatWord,

  /// A named sound inside a named word. Carries both.
  checkSound,
}

/// One coaching tip: what went wrong, plus the sounds and words to name.
class PronunciationTip {
  const PronunciationTip(this.code, {this.sound, this.word, this.heard});

  final PronunciationTipCode code;

  /// The sound the tip is about, as the learner would recognise it.
  final String? sound;

  /// The word it occurred in.
  final String? word;

  /// What came out instead of [sound].
  final String? heard;
}

/// Result of pronunciation assessment.
class PronunciationResult {
  final double overallScore; // 0.0 - 1.0
  final List<WordScore> wordScores;
  final List<ProblemSound> problemSounds;

  /// Coaching to show, as codes. Rendered by the presentation layer so it can
  /// be said in the learner's language.
  final List<PronunciationTip> tips;

  /// Words the learner said that aren't in the target phrase. Carried on the
  /// result so anything that recomputes the overall score keeps penalising
  /// padding — dropping it silently made extra speech free.
  final int insertionCount;

  const PronunciationResult({
    required this.overallScore,
    required this.wordScores,
    required this.problemSounds,
    this.tips = const [],
    this.insertionCount = 0,
  });

  bool get isPassing => overallScore >= 0.65;
}

/// Per-word pronunciation score.
class WordScore {
  final String word;
  final bool isCorrect;
  final double score; // 0.0 - 1.0

  const WordScore({
    required this.word,
    required this.isCorrect,
    required this.score,
  });
}

/// A sound the learner struggled with.
class ProblemSound {
  final String phoneme;
  final String word;
  final double score; // 0.0 - 1.0

  const ProblemSound({
    required this.phoneme,
    required this.word,
    required this.score,
  });
}
