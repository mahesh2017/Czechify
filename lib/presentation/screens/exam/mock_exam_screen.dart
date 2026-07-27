import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/engines/exam_grader.dart';
import '../../../domain/engines/pronunciation_scorer.dart';
import '../../../domain/engines/writing_word_gate.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/exam_result.dart';
import '../../../domain/entities/exam_speaking_task.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/services/exam_session_store.dart';
import '../../../domain/repositories/exam_repository.dart';
import '../../providers/database_providers.dart';
import '../../providers/stt_providers.dart';
import '../../providers/writing_providers.dart';
import '../../widgets/lesson/exercise_widget.dart' show TtsButton;

/// Mock exam screen — timed sections matching the selected exam product's
/// blueprint (permanent-residence A2 today).
class MockExamScreen extends ConsumerStatefulWidget {
  final ExamLevel level;

  const MockExamScreen({super.key, required this.level});

  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen> {
  MockExam? _exam;
  int _currentSection = 0;
  int _currentQuestion = 0;

  /// Answers keyed by section index, then question index — sections must
  /// never share slots (grading regressed once because they did).
  final Map<int, Map<int, dynamic>> _answers = {};

  Timer? _timer;
  int _secondsLeft = 0;
  bool _examStarted = false;
  bool _examComplete = false;
  bool _finishing = false;
  ExamResult? _result;
  bool _resultFullyScored = false;

  /// Externally produced section scores (0-100).
  final Map<({int section, int question}), int> _writingScores = {};
  final Map<({int section, int question}), WritingEvaluation>
  _writingEvaluations = {};
  final Map<({int section, int question}), String> _writingErrors = {};
  final Set<({int section, int question})> _writingEvaluating = {};
  final Map<({int section, int question}), TextEditingController>
  _writingControllers = {};
  final Map<({int section, int question}), int> _speakingScores = {};

  // Speaking section state
  bool _isRecordingSpeaking = false;
  final Map<({int section, int question}), String> _speakingTranscriptions = {};

  /// Durable mid-exam checkpoint so process death (memory pressure, a phone
  /// call) never discards a 30+ minute attempt.
  final ExamSessionStore _sessionStore = ExamSessionStore();
  ExamCheckpoint? _pendingCheckpoint;

  @override
  void initState() {
    super.initState();
    _loadExam();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _writingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExam() async {
    final exam = await ref
        .read(examRepositoryProvider)
        .getMockExam(widget.level);
    final checkpoint = await _sessionStore.load(widget.level.name);
    if (mounted) {
      setState(() {
        _exam = exam;
        _pendingCheckpoint = checkpoint;
      });
    }
  }

  void _startExam() {
    if (_exam == null) return;
    // Starting fresh abandons any interrupted attempt.
    _pendingCheckpoint = null;
    unawaited(_sessionStore.clear(widget.level.name));
    ref.read(writingEvalProvider.notifier).reset();
    setState(() {
      _examStarted = true;
      _currentSection = 0;
      _currentQuestion = 0;
      _answers.clear();
      _writingScores.clear();
      _writingEvaluations.clear();
      _writingErrors.clear();
      _writingEvaluating.clear();
      for (final controller in _writingControllers.values) {
        controller.dispose();
      }
      _writingControllers.clear();
      _speakingScores.clear();
      _speakingTranscriptions.clear();
      _examComplete = false;
      _result = null;
      _resultFullyScored = false;
    });
    _startSectionTimer();
  }

  /// Restore an interrupted attempt from its checkpoint.
  void _resumeExam() {
    final checkpoint = _pendingCheckpoint;
    if (_exam == null || checkpoint == null) return;
    // A checkpoint from a different exam build could point out of bounds.
    if (checkpoint.sectionIndex >= _exam!.sections.length ||
        checkpoint.questionIndex >=
            _exam!.sections[checkpoint.sectionIndex].questions.length) {
      unawaited(_sessionStore.clear(widget.level.name));
      setState(() => _pendingCheckpoint = null);
      return;
    }

    ({int section, int question}) decodeKey(String key) {
      final parts = key.split(':');
      return (section: int.parse(parts[0]), question: int.parse(parts[1]));
    }

    ref.read(writingEvalProvider.notifier).reset();
    setState(() {
      _examStarted = true;
      _currentSection = checkpoint.sectionIndex;
      _currentQuestion = checkpoint.questionIndex;
      _answers
        ..clear()
        ..addAll(
          checkpoint.answers.map(
            (section, questions) => MapEntry(section, {...questions}),
          ),
        );
      _speakingTranscriptions
        ..clear()
        ..addAll(
          checkpoint.speakingTranscriptions.map(
            (key, value) => MapEntry(decodeKey(key), value),
          ),
        );
      _speakingScores
        ..clear()
        ..addAll(
          checkpoint.speakingScores.map(
            (key, value) => MapEntry(decodeKey(key), value),
          ),
        );
      _writingScores
        ..clear()
        ..addAll(
          checkpoint.writingScores.map(
            (key, value) => MapEntry(decodeKey(key), value),
          ),
        );
      _examComplete = false;
      _result = null;
      _resultFullyScored = false;
      _pendingCheckpoint = null;
    });
    _startSectionTimer(resumeSeconds: checkpoint.secondsLeft);
  }

  void _saveCheckpoint() {
    if (!_examStarted || _examComplete || _finishing || _exam == null) return;
    String encodeKey(({int section, int question}) key) =>
        '${key.section}:${key.question}';
    unawaited(
      _sessionStore.save(
        ExamCheckpoint(
          level: widget.level.name,
          sectionIndex: _currentSection,
          questionIndex: _currentQuestion,
          secondsLeft: _secondsLeft,
          answers: _answers.map(
            (section, questions) => MapEntry(section, {...questions}),
          ),
          speakingTranscriptions: _speakingTranscriptions.map(
            (key, value) => MapEntry(encodeKey(key), value),
          ),
          speakingScores: _speakingScores.map(
            (key, value) => MapEntry(encodeKey(key), value),
          ),
          writingScores: _writingScores.map(
            (key, value) => MapEntry(encodeKey(key), value),
          ),
          savedAt: DateTime.now(),
        ),
      ),
    );
  }

  void _startSectionTimer({int? resumeSeconds}) {
    _timer?.cancel();
    final section = _exam!.sections[_currentSection];
    setState(
      () => _secondsLeft = resumeSeconds ?? section.timeLimitMinutes * 60,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          timer.cancel();
          _nextSection();
        }
      });
      // Persist the clock periodically so a killed app resumes close to
      // where it stopped (answer edits save immediately; this is time-only).
      if (_secondsLeft > 0 && _secondsLeft % 10 == 0) _saveCheckpoint();
    });
  }

  dynamic get _currentAnswer => _answers[_currentSection]?[_currentQuestion];

  void _answer(dynamic answer) {
    setState(() {
      _answers.putIfAbsent(_currentSection, () => {})[_currentQuestion] =
          answer;
    });
    _saveCheckpoint();
  }

  void _nextQuestion() {
    final section = _exam!.sections[_currentSection];
    if (_currentQuestion < section.questions.length - 1) {
      setState(() => _currentQuestion++);
      _saveCheckpoint();
    } else {
      _nextSection();
    }
  }

  void _nextSection() {
    _timer?.cancel();
    if (_currentSection < _exam!.sections.length - 1) {
      setState(() {
        _currentSection++;
        _currentQuestion = 0;
      });
      _startSectionTimer();
      _saveCheckpoint();
    } else {
      _finishExam();
    }
  }

  Future<void> _finishExam() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();
    unawaited(_sessionStore.clear(widget.level.name));

    await _evaluatePendingWritingTasks();

    final scores = ExamGrader().grade(
      exam: _exam!,
      answers: _answers,
      writingScore: _externalSectionScore(
        ExamSectionType.writing,
        _writingScores,
      ),
      speakingScore: _externalSectionScore(
        ExamSectionType.speaking,
        _speakingScores,
      ),
    );

    final result = ExamResult(
      id: 0, // assigned by the database
      level: widget.level,
      product: _exam?.product ?? ExamProduct.permanentResidence,
      takenAt: DateTime.now(),
      readingScore: scores.reading,
      listeningScore: scores.listening,
      writingScore: scores.writing,
      speakingScore: scores.speaking,
      totalScore: scores.total,
      passed: scores.passed,
    );

    // Persist the attempt and record a pass only when every productive task
    // was actually scored. Neither completion nor an unavailable evaluator
    // grants an automatic passing result or XP.
    // should block showing the result screen.
    ExamResult persisted = result;
    try {
      persisted = await ref.read(examRepositoryProvider).saveResult(result);
    } catch (_) {
      // Result still shown; only history is lost — but say so.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this result to your exam history.'),
          ),
        );
      }
    }
    if (result.passed) {
      try {
        await ref
            .read(progressRepositoryProvider)
            .recordExamPassed(widget.level.name);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _examComplete = true;
      _result = persisted;
      _resultFullyScored = scores.fullyScored;
      _finishing = false;
    });
  }

  ({int section, int question}) get _currentResponseKey => (
    section: _currentSection,
    question: _currentQuestion,
  );

  String _describeCheckpointAge(DateTime savedAt) {
    final elapsed = DateTime.now().difference(savedAt);
    if (elapsed.inMinutes < 1) return 'a moment ago';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
    return '${elapsed.inHours} h ago';
  }

  int? _externalSectionScore(
    ExamSectionType type,
    Map<({int section, int question}), int> scores,
  ) {
    for (
      var sectionIndex = 0;
      sectionIndex < _exam!.sections.length;
      sectionIndex++
    ) {
      final section = _exam!.sections[sectionIndex];
      if (section.type != type) continue;
      var earned = 0.0;
      var possible = 0;
      for (
        var questionIndex = 0;
        questionIndex < section.questions.length;
        questionIndex++
      ) {
        final score = scores[(section: sectionIndex, question: questionIndex)];
        if (score == null) return null;
        final points = section.questions[questionIndex]['points'] as int;
        earned += score * points / 100;
        possible += points;
      }
      return possible == 0 ? null : (earned / possible * 100).round();
    }
    return null;
  }

  Future<void> _evaluatePendingWritingTasks() async {
    for (
      var sectionIndex = 0;
      sectionIndex < _exam!.sections.length;
      sectionIndex++
    ) {
      final section = _exam!.sections[sectionIndex];
      if (section.type != ExamSectionType.writing) continue;
      for (
        var questionIndex = 0;
        questionIndex < section.questions.length;
        questionIndex++
      ) {
        final key = (section: sectionIndex, question: questionIndex);
        if (_writingScores.containsKey(key)) continue;
        final question = section.questions[questionIndex];
        final text = _answers[sectionIndex]?[questionIndex] as String?;
        if (text == null || text.trim().isEmpty) continue;
        // Official deterministic rule: a response below the task's minimum word
        // count scores 0 without any content evaluation.
        if (WritingWordGate.belowMinimum(text, question['min_words'] as int?)) {
          setState(() => _writingScores[key] = 0);
          continue;
        }
        await _evaluateWritingTask(key, question, text);
      }
    }
  }

  Future<void> _evaluateWritingTask(
    ({int section, int question}) key,
    Map<String, dynamic> question,
    String text,
  ) async {
    if (_writingEvaluating.contains(key)) return;
    setState(() {
      _writingEvaluating.add(key);
      _writingErrors.remove(key);
    });
    final evaluation = await ref
        .read(writingEvalProvider.notifier)
        .evaluate(
          level: widget.level == ExamLevel.a1 ? CEFRLevel.a1 : CEFRLevel.a2,
          taskDescription: question['prompt'] as String,
          learnerText: text,
        );
    if (!mounted) return;
    setState(() {
      _writingEvaluating.remove(key);
      if (evaluation == null) {
        _writingErrors[key] =
            ref.read(writingEvalProvider).error ??
            'This response could not be scored.';
      } else {
        _writingEvaluations[key] = evaluation;
        _writingScores[key] = evaluation.overall;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_examStarted && !_examComplete) {
      return _buildIntroScreen();
    }
    if (_examComplete && _result != null) {
      return _buildResultScreen();
    }
    return _buildExamScreen();
  }

  Widget _buildIntroScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mock Exam — ${widget.level.name.toUpperCase()}'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment, size: 64, color: context.tokens.pri),
              const SizedBox(height: 24),
              Text(
                '${(_exam?.product ?? ExamProduct.permanentResidence).displayName} '
                '${widget.level.name.toUpperCase()} Practice Exam',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'This exam has 4 timed sections:\n\n'
                '📖 Reading — comprehension questions\n'
                '🎧 Listening — audio + questions\n'
                '✍️ Writing — practice feedback when available\n'
                '🎤 Speaking — transcript-based practice evidence\n\n'
                'This is informal practice, not an official exam result.\n\n'
                'You can answer questions in order. The timer runs per section.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.tokens.muted),
              ),
              const SizedBox(height: 24),
              if (_exam != null) ...[
                Text(
                  'Total time: ${_exam!.totalTimeMinutes} minutes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (_pendingCheckpoint != null) ...[
                  Text(
                    'You have an unfinished attempt from '
                    '${_describeCheckpointAge(_pendingCheckpoint!.savedAt)}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _resumeExam,
                    icon: const Icon(Icons.restore),
                    label: const Text('Resume Exam'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _startExam,
                    child: const Text('Discard and start over'),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: _startExam,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Exam'),
                  ),
              ] else ...[
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamScreen() {
    if (_finishing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grading...')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Evaluating your answers...'),
            ],
          ),
        ),
      );
    }

    final section = _exam!.sections[_currentSection];
    final question = section.questions[_currentQuestion];
    final totalQuestions = section.questions.length;
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final leave = await _confirmExit();
              if (leave && mounted) Navigator.of(context).pop();
            },
          ),
          title: Text(
            '${section.type.name[0].toUpperCase()}${section.type.name.substring(1)} — $minutes:${seconds.toString().padLeft(2, '0')}',
          ),
          actions: [
            Center(
              child: Text(
                'Q${_currentQuestion + 1}/$totalQuestions',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timer bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _secondsLeft / (section.timeLimitMinutes * 60),
                  minHeight: 4,
                  backgroundColor: context.tokens.redSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _secondsLeft < 60 ? context.tokens.red : context.tokens.pri,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Question
              Expanded(child: _buildQuestion(section.type, question)),

              // Navigation.
              //
              // Both buttons override minimumSize. The app theme sets
              // `Size.fromHeight(54)` on every button style, and that is
              // `Size(double.infinity, 54)` — a deliberate full-width look that
              // works anywhere the button gets a bounded width. A Row passes
              // its children *unbounded* width, so the infinite minimum
              // propagates and layout fails: the exam body rendered completely
              // blank and threw on every timer tick. Any themed button placed
              // in a Row needs a finite minimum like this.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentQuestion > 0)
                    TextButton(
                      onPressed: () => setState(() => _currentQuestion--),
                      child: const Text('Previous'),
                    )
                  else
                    const SizedBox(width: 80),
                  FilledButton(
                    onPressed: _nextQuestion,
                    style: FilledButton.styleFrom(
                      minimumSize: kRowButtonMinSize,
                    ),
                    child: Text(
                      _currentQuestion < totalQuestions - 1
                          ? 'Next'
                          : _currentSection < _exam!.sections.length - 1
                          ? 'Next Section'
                          : 'Finish Exam',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirm before abandoning an in-progress exam attempt.
  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Leave exam?'),
            content: const Text(
              'Your exam is in progress and will not be scored if you leave now.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Leave'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  Widget _buildQuestion(ExamSectionType type, Map<String, dynamic> question) {
    switch (type) {
      case ExamSectionType.reading:
        return _buildChoiceQuestion(question);
      case ExamSectionType.listening:
        return _buildListeningQuestion(question);
      case ExamSectionType.writing:
        return _buildWritingQuestion(question);
      case ExamSectionType.speaking:
        return _buildSpeakingQuestion(question);
    }
  }

  Widget _buildChoiceQuestion(Map<String, dynamic> question) {
    final prompt = question['prompt'] as String;
    final options = (question['options'] as List<dynamic>).cast<String>();
    final selected = _currentAnswer;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question['passage'] != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  question['passage'] as String,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(prompt, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...options.asMap().entries.map((entry) {
            final idx = entry.key;
            final option = entry.value;
            final isSelected = selected == idx;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                child: ListTile(
                  leading: Text(
                    String.fromCharCode(65 + idx),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  title: Text(option),
                  onTap: () => _answer(idx),
                  trailing:
                      isSelected
                          ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                          : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildListeningQuestion(Map<String, dynamic> question) {
    final audioText = question['audio_text'] as String? ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audio player — the spoken text is deliberately never displayed.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TtsButton(text: audioText, size: 40),
                  const SizedBox(width: 8),
                  const Text('Tap to play the audio'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildChoiceBody(question),
        ],
      ),
    );
  }

  Widget _buildChoiceBody(Map<String, dynamic> question) {
    final prompt = question['prompt'] as String;
    final options = (question['options'] as List<dynamic>).cast<String>();
    final selected = _currentAnswer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        ...options.asMap().entries.map((entry) {
          final idx = entry.key;
          final option = entry.value;
          final isSelected = selected == idx;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
              child: ListTile(
                leading: Text(
                  String.fromCharCode(65 + idx),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                title: Text(option),
                onTap: () => _answer(idx),
                trailing:
                    isSelected
                        ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                        : null,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWritingQuestion(Map<String, dynamic> question) {
    final key = _currentResponseKey;
    final learnerText = _currentAnswer as String? ?? '';
    final controller = _writingControllers.putIfAbsent(
      key,
      () => TextEditingController(text: learnerText),
    );
    final isEvaluating = _writingEvaluating.contains(key);
    final evaluation = _writingEvaluations[key];
    final error = _writingErrors[key];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question['prompt'] as String,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Write ${question['min_words'] ?? 30}+ words in Czech.',
          style: TextStyle(color: context.tokens.muted, fontSize: 15),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            enabled: !isEvaluating,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Napište svou odpověď v češtině...',
            ),
            onChanged: _answer,
          ),
        ),
        // AI evaluation feedback
        if (isEvaluating) ...[
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('AI evaluating your writing...'),
            ],
          ),
        ],
        if (evaluation != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practice feedback — Score: ${evaluation.overall}/100',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _MiniScoreRow(label: 'Grammar', score: evaluation.grammar),
                  _MiniScoreRow(
                    label: 'Vocabulary',
                    score: evaluation.vocabulary,
                  ),
                  _MiniScoreRow(
                    label: 'Coherence',
                    score: evaluation.coherence,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    evaluation.feedback,
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (!isEvaluating && evaluation == null && learnerText.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await _evaluateWritingTask(key, question, learnerText);
            },
            icon: const Icon(Icons.rate_review),
            label: const Text('Request practice feedback'),
          ),
        ],
      ],
    );
  }

  Widget _buildSpeakingQuestion(Map<String, dynamic> question) {
    final task = ExamSpeakingTask.fromJson(question);
    final score = _speakingScores[_currentResponseKey];
    final transcription = _speakingTranscriptions[_currentResponseKey];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question['prompt'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  switch (task) {
                    ExamReadAloudTask(:final targetText) => Column(
                      children: [
                        Text(
                          targetText,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TtsButton(text: targetText, size: 20),
                      ],
                    ),
                    ExamPromptedResponseTask(:final expectedPhrases) => Column(
                      children: [
                        const Text(
                          'Include ideas such as:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          expectedPhrases.join(' • '),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    ExamOpenResponseTask(:final evaluationCriteria) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Human-review criteria:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...evaluationCriteria.map(
                          (criterion) => Text('• $criterion'),
                        ),
                      ],
                    ),
                  },
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            task is ExamReadAloudTask
                ? 'Read the text aloud. This practice score compares the '
                    'device transcript with the displayed text.'
                : task is ExamPromptedResponseTask
                ? 'Respond freely in Czech. This practice score reports '
                    'coverage of the suggested phrases in the device transcript.'
                : 'Respond freely in Czech. The transcript is saved for '
                    'review, but this task is not automatically scored.',
            style: TextStyle(color: context.tokens.muted, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _isRecordingSpeaking ? null : () => _recordSpeaking(task),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _isRecordingSpeaking
                          ? context.tokens.red
                          : Theme.of(context).colorScheme.primary,
                ),
                child: Icon(
                  _isRecordingSpeaking ? Icons.hearing : Icons.mic,
                  color: context.tokens.onFill,
                  size: 30,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isRecordingSpeaking
                ? 'Listening...'
                : score != null
                ? 'Scored! Tap the mic to try again.'
                : 'Tap to record',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (score != null) ...[
            const SizedBox(height: 16),
            Text(
              '$score / 100',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color:
                    score >= 60 ? context.tokens.green : context.tokens.amber,
              ),
            ),
            if (transcription != null && transcription.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Heard: "$transcription"',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.tokens.muted, fontSize: 14),
                ),
              ),
          ] else if (transcription != null && transcription.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recorded — unscored practice',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.tokens.amber,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Heard: "$transcription"',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.tokens.muted, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _recordSpeaking(ExamSpeakingTask task) async {
    final responseKey = _currentResponseKey;
    setState(() => _isRecordingSpeaking = true);
    try {
      final stt = ref.read(sttServiceProvider) as NativeSttService;
      // Read-aloud is a short fixed text; prompted/open responses need room
      // for a real utterance — a 12 s cap cut CCE-style answers off mid-turn.
      final timeout = switch (task) {
        ExamReadAloudTask() => const Duration(seconds: 15),
        ExamPromptedResponseTask() => const Duration(seconds: 30),
        ExamOpenResponseTask() => const Duration(seconds: 45),
      };
      final transcription = await stt.listenFor(timeout: timeout);

      final int? score = switch (task) {
        ExamReadAloudTask(:final targetText) =>
          (PronunciationScorer()
                      .score(
                        expectedText: targetText,
                        actualTranscription: transcription,
                      )
                      .overallScore *
                  100)
              .round(),
        ExamPromptedResponseTask() =>
          (task.transcriptCoverage(transcription) * 100).round(),
        ExamOpenResponseTask() => null,
      };

      if (!mounted || responseKey != _currentResponseKey) return;
      setState(() {
        _isRecordingSpeaking = false;
        _speakingTranscriptions[responseKey] = transcription;
        if (score != null) _speakingScores[responseKey] = score;
      });
      _answer(score ?? transcription);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRecordingSpeaking = false;
        _speakingTranscriptions.remove(responseKey);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Speech recognition failed. Check microphone permissions.',
          ),
        ),
      );
    }
  }

  Widget _buildResultScreen() {
    final passed = _result!.passed;
    final t = context.tokens;
    final color =
        !_resultFullyScored
            ? t.amber
            : passed
            ? t.green
            : t.red;

    return Scaffold(
      appBar: AppBar(title: const Text('Exam Results')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                !_resultFullyScored
                    ? Icons.pending_actions
                    : passed
                    ? Icons.emoji_events
                    : Icons.cancel,
                size: 80,
                color: color,
              ),
              const SizedBox(height: 24),
              Text(
                !_resultFullyScored
                    ? 'Practice completed — some tasks are unscored'
                    : passed
                    ? 'Practice threshold met'
                    : 'Practice threshold not met',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _ScoreRow(label: 'Reading', score: _result!.readingScore),
                      const Divider(),
                      _ScoreRow(
                        label: 'Listening',
                        score: _result!.listeningScore,
                      ),
                      const Divider(),
                      _ScoreRow(label: 'Writing', score: _result!.writingScore),
                      const Divider(),
                      _ScoreRow(
                        label: 'Speaking',
                        score: _result!.speakingScore,
                      ),
                      const Divider(),
                      _ScoreRow(
                        label: 'Overall',
                        score: _result!.totalScore,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Answer review — what was right and wrong, per question.
              _buildAnswerReview(),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Per-question review of the choice sections (reading + listening),
  /// shown after the exam so mistakes become learning material.
  Widget _buildAnswerReview() {
    final entries = <Widget>[];

    for (var s = 0; s < _exam!.sections.length; s++) {
      final section = _exam!.sections[s];
      if (section.type != ExamSectionType.reading &&
          section.type != ExamSectionType.listening) {
        continue;
      }

      entries.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              section.type == ExamSectionType.reading ? 'Reading' : 'Listening',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );

      for (var q = 0; q < section.questions.length; q++) {
        final question = section.questions[q];
        final options = (question['options'] as List<dynamic>?)?.cast<String>();
        final correctIdx = question['correct_answer'];
        if (options == null || correctIdx is! int) continue;

        final userIdx = _answers[s]?[q];
        final isCorrect = userIdx == correctIdx;
        final audioText = question['audio_text'] as String?;

        entries.add(
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color:
                            isCorrect
                                ? context.tokens.green
                                : context.tokens.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question['prompt'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (audioText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Audio said: "$audioText"',
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (!isCorrect)
                    Text(
                      userIdx is int && userIdx < options.length
                          ? 'Your answer: ${options[userIdx]}'
                          : 'Not answered',
                      style: TextStyle(color: context.tokens.red, fontSize: 15),
                    ),
                  Text(
                    'Correct: ${options[correctIdx]}',
                    style: TextStyle(color: context.tokens.green, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Answer Review',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...entries,
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int score;
  final bool isBold;

  const _ScoreRow({
    required this.label,
    required this.score,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color =
        score >= 80
            ? t.green
            : score >= 60
            ? t.amber
            : t.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '$score / 100',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: isBold ? 18 : 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniScoreRow extends StatelessWidget {
  final String label;
  final int score;

  const _MiniScoreRow({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color =
        score >= 80
            ? t.green
            : score >= 60
            ? t.amber
            : t.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text('$score', style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
