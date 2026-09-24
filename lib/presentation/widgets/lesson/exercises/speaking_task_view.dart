import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/engines/pronunciation_scorer.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/repositories/speech_ports.dart';
import '../../../providers/stt_providers.dart';
import '../../common/lesson_image.dart';
import '../../common/lesson_ui.dart';
import '../../common/record_button.dart';
import '../../common/motion_widgets.dart';
import '../../common/slide_deck.dart';
import '../../common/soft_ui.dart';
import '../slides_pilot.dart';
import '../../../../l10n/app_localizations.dart';
import 'exercise_shared.dart';

/// Speaking task exercise — record yourself speaking Czech in response to
/// a prompt. The recording is transcribed and compared to expected phrases.
class SpeakingTaskView extends ConsumerStatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const SpeakingTaskView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  ConsumerState<SpeakingTaskView> createState() => _SpeakingTaskViewState();
}

class _SpeakingTaskViewState extends ConsumerState<SpeakingTaskView> {
  late final LiveTranscriber _transcriber;
  final PronunciationScorer _scorer = PronunciationScorer();

  @override
  void initState() {
    super.initState();
    _transcriber = ref.read(liveTranscriberProvider);
  }

  @override
  void dispose() {
    // The exercise can be left mid-recording; the microphone should not
    // outlive it.
    if (isRecording) unawaited(_transcriber.stop());
    super.dispose();
  }

  bool isRecording = false;
  bool hasRecorded = false;
  String? transcription;
  String? feedback;

  /// Whether the last recording was good enough. Kept as a flag: the feedback
  /// colour used to test the text for "Good", which the Czech text never has.
  bool? _passed;

  /// The answer has gone to the lesson, by recording or by skipping.
  bool _submitted = false;

  /// Guards against the stale [Future.delayed] callback when the user
  /// taps re-record during the 2-second auto-submit delay.
  bool _autoSubmitPending = false;

  /// Cancellation flag — when true, the current recognition session is
  /// abandoned (stopped) and its results should be discarded.
  bool _sessionCancelled = false;

  String get _prompt {
    return (widget.exercise.data['prompt_en'] ?? widget.exercise.prompt)
        as String;
  }

  String? get _promptCz => widget.exercise.data['prompt_cz'] as String?;

  /// Never falls back to [Exercise.answerKey]. For a speaking task that field
  /// is English authoring metadata ("Full spoken role-play at a government
  /// office."), so the fallback scored Czech speech against an English
  /// sentence and made the exercise unpassable. `expected_phrases` is now a
  /// validated part of the content contract — see
  /// CurriculumContractValidator._validateSpeakingTask — so there is nothing
  /// left to fall back to.
  List<String> get _expectedPhrases {
    final raw = widget.exercise.data['expected_phrases'];
    if (raw is List) return raw.cast<String>();
    return const [];
  }

  Duration get _listenTimeout {
    final configured = widget.exercise.data['max_duration_seconds'];
    final seconds = configured is num ? configured.toInt() : 15;
    return Duration(seconds: seconds.clamp(5, 60));
  }

  Future<void> _toggleRecording() async {
    // If recording, stop and process the result.
    if (isRecording) {
      await _transcriber.stop();
      // listenFor()'s completer will resolve on stop — the awaiting code
      // below continues normally.
      return;
    }

    // If a previous result is showing and we're not in the auto-submit
    // delay, this is a re-record. Cancel any pending auto-submit first.
    if (_autoSubmitPending) {
      _autoSubmitPending = false;
    }

    // Start a fresh session.
    _sessionCancelled = false;
    setState(() {
      isRecording = true;
      hasRecorded = false;
      transcription = null;
      feedback = null;
    });

    try {
      final recorded =
          (await _transcriber.listenFor(timeout: _listenTimeout)).trim();

      // If the user cancelled (re-recorded or stopped without processing),
      // discard the result entirely.
      if (_sessionCancelled) return;

      var score = 0.0;

      // Compare against expected phrases
      for (final phrase in _expectedPhrases) {
        if (matchAnswer([phrase], recorded) != AnswerMatch.none) {
          score = 1.0;
          break;
        }
      }

      // Partial match: how much of the expected Czech actually turned up.
      //
      // This counted how many spoken tokens appeared anywhere in the expected
      // vocabulary and divided by the number of distinct expected words, so
      // repetition paid: saying "dobrý" six times scored 6/5 against "Dobrý
      // den, jmenuji se Jana." and passed a task the learner had not answered.
      // Pooling every alternative phrasing into one bag of words made it worse
      // — the more ways a task could be answered, the more words counted.
      //
      // [PronunciationScorer] aligns the utterance against one phrase instead
      // of counting tokens: each expected word can be satisfied once, and
      // anything extra lands in the denominator as an insertion. The exam's
      // read-aloud tasks already score this way. Alternatives are scored
      // separately and the best one wins, so a learner is credited for the
      // phrasing they actually chose.
      if (score < 1.0 && recorded.isNotEmpty) {
        for (final phrase in _expectedPhrases) {
          final phraseScore =
              _scorer
                  .score(expectedText: phrase, actualTranscription: recorded)
                  .overallScore;
          if (phraseScore > score) score = phraseScore;
        }
        if (score > 1.0) score = 1.0;
      }

      // The widget can be gone by the time the recogniser returns, and reading
      // localisations off a dead context is what the async-gap lint is warning
      // about.
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final currentFeedback =
          score >= 0.5
              ? l10n.speakingFeedbackGood
              : l10n.speakingFeedbackRetry(_expectedPhrases.join(', '));

      setState(() {
        hasRecorded = true;
        isRecording = false;
        transcription = recorded;
        feedback = currentFeedback;
        _passed = score >= 0.5;
      });

      // Auto-submit after a short delay so the user can see their result.
      // Guard with a flag so a re-record tap cancels this stale callback.
      _autoSubmitPending = true;
      Future.delayed(const Duration(seconds: 2), () {
        if (!_autoSubmitPending || !mounted) return;
        _autoSubmitPending = false;
        setState(() => _submitted = true);
        widget.onAnswered(
          ExerciseResult(
            isCorrect: score >= 0.5,
            explanation: currentFeedback,
            correctAnswer: _expectedPhrases.join('; '),
          ),
        );
      });
    } catch (error) {
      if (_sessionCancelled) return;
      setState(() {
        isRecording = false;
        // A recogniser that cannot handle Czech says so in plain language, and
        // saying it beats a generic failure the learner can only read as their
        // own. Nothing is submitted either way, so an unavailable recogniser
        // never becomes a wrong answer on their record.
        feedback =
            error is SpeechServiceException
                ? error.message
                : AppLocalizations.of(context).recordingFailed;
      });
    }
  }

  /// For a learner who cannot speak aloud right now, or has no microphone:
  /// skipping costs no heart and says which phrases to practise, the same as
  /// pronunciation. Without it the only way past a speaking task was to leave
  /// the lesson.
  void _skip() {
    if (_submitted) return;
    _autoSubmitPending = false;
    if (isRecording) {
      _sessionCancelled = true;
      unawaited(_transcriber.stop());
    }
    setState(() {
      isRecording = false;
      _submitted = true;
    });
    widget.onAnswered(
      ExerciseResult.skipped(
        explanation: AppLocalizations.of(context).speakingSkippedNote,
        correctAnswer: _expectedPhrases.join('; '),
      ),
    );
  }

  Widget _skipButton(BuildContext context) => TextButton(
    onPressed: _skip,
    style: TextButton.styleFrom(
      foregroundColor: context.tokens.muted,
      minimumSize: const Size(0, 44),
    ),
    child: Text(AppLocalizations.of(context).speakingCantSpeakSkip),
  );

  /// What was heard and whether it was enough, in the record button's place.
  Widget _result(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (transcription != null && transcription!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.elev,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LessonKicker(l10n.speakingYouSaid),
                const SizedBox(height: 6),
                Text(
                  transcription!,
                  style: TextStyle(fontSize: 16, height: 1.45, color: t.ink),
                ),
              ],
            ),
          ),
        if (feedback != null) ...[
          const SizedBox(height: 10),
          Text(
            feedback!,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: _passed == true ? t.greenInk : t.ink,
            ),
          ),
        ],
      ],
    );
  }

  /// Pilot: the brief on one slide; on the next, the phrases to use and the
  /// microphone. Recording finishes the step, so the last slide has Back and
  /// no button of its own.
  Widget _slides(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final image = (widget.exercise.data['image'] as String?)?.trim();
    final imageLabel = (widget.exercise.data['image_label'] as String?)?.trim();
    final heard = hasRecorded && !isRecording;
    return SlideDeck(
      slides: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuestionPrompt(
              question: _prompt,
              czech: _promptCz,
              instruction: true,
            ),
            if (image != null && image.isNotEmpty) ...[
              const SizedBox(height: 16),
              LessonImage(
                asset: image,
                height: 160,
                semanticLabel:
                    imageLabel == null || imageLabel.isEmpty ? null : imageLabel,
              ),
            ],
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_promptCz != null && _promptCz!.trim().isNotEmpty) ...[
              Text(
                _promptCz!,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: t.muted,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_expectedPhrases.isNotEmpty) ...[
              LessonKicker(l10n.speakingTryToSay),
              const SizedBox(height: 8),
              // Chips rather than a line each: eight phrases took 290 pt as a
              // list and about a third of that wrapped.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final phrase in _expectedPhrases)
                    PillChip(label: phrase, bg: t.card, fg: t.ink),
                ],
              ),
              const SizedBox(height: 18),
            ],
            if (heard && feedback != null) ...[
              _result(context),
              if (!_submitted)
                Center(
                  child: TextButton.icon(
                    onPressed: _toggleRecording,
                    icon: const Icon(Icons.mic_none_rounded, size: 18),
                    label: Text(l10n.speakingTapToRerecord),
                  ),
                ),
            ] else if (!_submitted) ...[
              Center(
                child: RecordButton(
                  isRecording: isRecording,
                  onPressed: _toggleRecording,
                ),
              ),
              Text(
                isRecording
                    ? l10n.speakingRecordingTapToStop
                    : l10n.speakingTapToSpeak,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isRecording ? t.redInk : t.muted,
                ),
              ),
              // A recogniser error, with nothing recorded.
              if (!isRecording && !hasRecorded && feedback != null) ...[
                const SizedBox(height: 8),
                Text(
                  feedback!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.35, color: t.redInk),
                ),
              ],
            ],
            if (!_submitted && !isRecording) Center(child: _skipButton(context)),
          ],
        ),
      ],
      doneLabel: '',
      onDone: null,
      finished: _submitted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final image = (widget.exercise.data['image'] as String?)?.trim();
    final imageLabel = (widget.exercise.data['image_label'] as String?)?.trim();
    if (showsAsSlides(widget.exercise)) return _slides(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: _prompt, czech: _promptCz),
          const SizedBox(height: 16),

          if (image != null && image.isNotEmpty) ...[
            LessonImage(
              asset: image,
              aspectRatio: 5 / 4,
              semanticLabel:
                  imageLabel == null || imageLabel.isEmpty ? null : imageLabel,
            ),
            const SizedBox(height: 16),
          ],

          // What to aim for, stated before they speak.
          if (_expectedPhrases.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(24),
                boxShadow: t.shadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LessonKicker(l10n.speakingTryToSay),
                  const SizedBox(height: 10),
                  for (final (i, p) in _expectedPhrases.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.record_voice_over_outlined,
                            size: 16,
                            color: t.pri,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          Center(
            child: Column(
              children: [
                RecordButton(
                  isRecording: isRecording,
                  onPressed: _toggleRecording,
                ),
                Text(
                  isRecording
                      ? l10n.speakingRecordingTapToStop
                      : hasRecorded
                      ? l10n.speakingTapToRerecord
                      : l10n.speakingTapToSpeak,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isRecording ? t.redInk : t.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // What was heard, then what to make of it.
          MotionDisclosure(
            visible: transcription != null && transcription!.isNotEmpty,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: t.elev,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LessonKicker(l10n.speakingYouSaid),
                      const SizedBox(height: 6),
                      Text(
                        transcription ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.45,
                          color: t.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          MotionDisclosure(
            visible: feedback != null,
            child: Text(
              feedback ?? '',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w600,
                // Amber means streak and XP, never a verdict — a speaking
                // result that is not clearly good is neutral, not a warning.
                color: _passed == true ? t.greenInk : t.ink,
              ),
            ),
          ),
          if (!_submitted && !isRecording) Center(child: _skipButton(context)),
        ],
      ),
    );
  }
}
