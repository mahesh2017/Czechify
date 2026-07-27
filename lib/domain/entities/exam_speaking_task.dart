/// Typed speaking task variants used by mock-exam banks.
sealed class ExamSpeakingTask {
  const ExamSpeakingTask({required this.prompt, required this.points});

  final String prompt;
  final int points;

  factory ExamSpeakingTask.fromJson(Map<String, dynamic> json) {
    final prompt = json['prompt'];
    final points = json['points'];
    if (prompt is! String || prompt.trim().isEmpty || points is! int) {
      throw const FormatException(
        'Speaking task requires a prompt and integer points',
      );
    }
    final targetText = json['target_text'];
    if (targetText is String && targetText.trim().isNotEmpty) {
      return ExamReadAloudTask(
        prompt: prompt,
        points: points,
        targetText: targetText,
      );
    }
    final expectedPhrases = json['expected_phrases'];
    if (expectedPhrases is List &&
        expectedPhrases.isNotEmpty &&
        expectedPhrases.every(
          (phrase) => phrase is String && phrase.trim().isNotEmpty,
        )) {
      return ExamPromptedResponseTask(
        prompt: prompt,
        points: points,
        expectedPhrases: expectedPhrases.cast<String>(),
      );
    }
    final evaluationCriteria = json['evaluation_criteria'];
    if (evaluationCriteria is List &&
        evaluationCriteria.isNotEmpty &&
        evaluationCriteria.every(
          (criterion) => criterion is String && criterion.trim().isNotEmpty,
        )) {
      return ExamOpenResponseTask(
        prompt: prompt,
        points: points,
        evaluationCriteria: evaluationCriteria.cast<String>(),
      );
    }
    throw const FormatException(
      'Speaking task requires target_text, expected_phrases, or '
      'evaluation_criteria',
    );
  }
}

class ExamOpenResponseTask extends ExamSpeakingTask {
  const ExamOpenResponseTask({
    required super.prompt,
    required super.points,
    required this.evaluationCriteria,
  });

  final List<String> evaluationCriteria;
}

class ExamReadAloudTask extends ExamSpeakingTask {
  const ExamReadAloudTask({
    required super.prompt,
    required super.points,
    required this.targetText,
  });

  final String targetText;
}

class ExamPromptedResponseTask extends ExamSpeakingTask {
  const ExamPromptedResponseTask({
    required super.prompt,
    required super.points,
    required this.expectedPhrases,
  });

  final List<String> expectedPhrases;

  /// Returns transparent keyword/phrase coverage, not a pronunciation score.
  double transcriptCoverage(String transcription) {
    final heard = _canonical(transcription);
    if (heard.isEmpty) return 0;
    final covered =
        expectedPhrases.where((phrase) {
          final expected = _canonical(phrase);
          return expected.isNotEmpty && heard.contains(expected);
        }).length;
    return covered / expectedPhrases.length;
  }
}

String _canonical(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-záčďéěíňóřšťúůýž0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');
