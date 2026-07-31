import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot of an in-progress mock exam, durable across process death.
///
/// Only device-local — an interrupted exam resumes on the same device; it is
/// deliberately not synced (a half-finished timed exam on another device
/// would make no sense).
class ExamCheckpoint {
  final String level;
  final int sectionIndex;
  final int questionIndex;
  final int secondsLeft;

  /// Answers keyed by section index, then question index (JSON-safe copy of
  /// the screen's answer map; values are strings/ints/lists as entered).
  final Map<int, Map<int, dynamic>> answers;

  /// Speaking transcriptions and scores keyed "section:question".
  final Map<String, String> speakingTranscriptions;
  final Map<String, int> speakingScores;

  /// Completed writing scores keyed "section:question".
  final Map<String, int> writingScores;

  final DateTime savedAt;

  const ExamCheckpoint({
    required this.level,
    required this.sectionIndex,
    required this.questionIndex,
    required this.secondsLeft,
    required this.answers,
    this.speakingTranscriptions = const {},
    this.speakingScores = const {},
    this.writingScores = const {},
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'level': level,
    'section_index': sectionIndex,
    'question_index': questionIndex,
    'seconds_left': secondsLeft,
    'answers': answers.map(
      (section, questions) => MapEntry(
        '$section',
        questions.map((question, value) => MapEntry('$question', value)),
      ),
    ),
    'speaking_transcriptions': speakingTranscriptions,
    'speaking_scores': speakingScores,
    'writing_scores': writingScores,
    'saved_at': savedAt.toIso8601String(),
  };

  static ExamCheckpoint? fromJson(Map<String, dynamic> json) {
    try {
      final answersRaw = json['answers'] as Map<String, dynamic>? ?? {};
      final answers = <int, Map<int, dynamic>>{};
      answersRaw.forEach((sectionKey, questions) {
        final section = int.parse(sectionKey);
        answers[section] = (questions as Map<String, dynamic>).map(
          (questionKey, value) => MapEntry(int.parse(questionKey), value),
        );
      });
      return ExamCheckpoint(
        level: json['level'] as String,
        sectionIndex: json['section_index'] as int,
        questionIndex: json['question_index'] as int,
        secondsLeft: json['seconds_left'] as int,
        answers: answers,
        speakingTranscriptions: Map<String, String>.from(
          json['speaking_transcriptions'] as Map? ?? {},
        ),
        speakingScores: Map<String, int>.from(
          json['speaking_scores'] as Map? ?? {},
        ),
        writingScores: Map<String, int>.from(
          json['writing_scores'] as Map? ?? {},
        ),
        savedAt: DateTime.parse(json['saved_at'] as String),
      );
    } catch (_) {
      return null; // Malformed/older checkpoint — treat as absent.
    }
  }
}

/// Persists at most one [ExamCheckpoint] per exam level.
class ExamSessionStore {
  ExamSessionStore({Future<SharedPreferences>? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferences;

  /// Checkpoints older than this are discarded — resuming a timed exam days
  /// later is not a meaningful attempt.
  static const maxAge = Duration(hours: 24);

  static String _key(String level) => 'exam_checkpoint_$level';

  Future<ExamCheckpoint?> load(String level) async {
    final prefs = await _preferences;
    final raw = prefs.getString(_key(level));
    if (raw == null) return null;
    ExamCheckpoint? checkpoint;
    try {
      checkpoint = ExamCheckpoint.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      checkpoint = null;
    }
    if (checkpoint == null ||
        DateTime.now().difference(checkpoint.savedAt) > maxAge) {
      await prefs.remove(_key(level));
      return null;
    }
    return checkpoint;
  }

  Future<void> save(ExamCheckpoint checkpoint) async {
    final prefs = await _preferences;
    await prefs.setString(
      _key(checkpoint.level),
      jsonEncode(checkpoint.toJson()),
    );
  }

  Future<void> clear(String level) async {
    final prefs = await _preferences;
    await prefs.remove(_key(level));
  }
}
