import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/learning_evidence.dart';
import '../../../providers/tts_providers.dart';
import '../../common/lesson_image.dart';
import '../../common/lesson_ui.dart';
import '../../common/motion_widgets.dart';
import 'exercise_shared.dart';
import 'question_steps.dart';

/// Listening comprehension exercise — listen to a Czech dialogue/recording,
/// then answer multiple-choice questions.
///
/// Until audio files are generated, the transcript is shown as a fallback
/// with a TTS button to read it aloud.
class ListeningComprehensionView extends ConsumerStatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const ListeningComprehensionView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  ConsumerState<ListeningComprehensionView> createState() =>
      _ListeningComprehensionViewState();
}

class _ListeningComprehensionViewState
    extends ConsumerState<ListeningComprehensionView> {
  /// Plays the learner asked for. Deliberately excludes the automatic first
  /// play, which they did not choose.
  int _playCount = 0;

  /// Whether the learner asked to hear a recording they had already heard.
  ///
  /// This is the evidence [SupportKind.replay] is meant to carry, and the
  /// count alone could not express it. `_playCount > 1` ignored the automatic
  /// play entirely, so a learner who let it play and then asked for it once
  /// more — needing it twice — was recorded as having understood it
  /// unaided, and that fed placement and recommendations.
  bool get _replayedAfterHearing =>
      _autoPlayed ? _playCount >= 1 : _playCount > 1;

  /// Whether the automatic play has happened, so the button can say "Play it
  /// again" truthfully without counting as a replay.
  bool _autoPlayed = false;

  bool _transcriptRevealed = false;

  /// Cancelled on dispose — see [DictationView] for why.
  Timer? _autoPlay;

  @override
  void initState() {
    super.initState();
    // Same reasoning as dictation: the task is to answer what you heard, and
    // until now nothing had been heard unless the learner pressed a button
    // labelled "Play it again".
    _autoPlay = Timer(kListenAutoPlayDelay, () {
      if (!mounted) return;
      final transcript = widget.exercise.data['transcript_cz'] as String? ?? '';
      if (transcript.isEmpty) return;
      setState(() => _autoPlayed = true);
      ref.read(czechTtsProvider).speak(transcript);
    });
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    super.dispose();
  }

  /// The learner played the recording. A play of their own replaces the
  /// automatic one still to come: pressing Listen at once used to be
  /// followed by the autoplay too, twice in a row, and counted as a replay.
  void _played() {
    _autoPlay?.cancel();
    setState(() => _playCount++);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final transcriptCz = data['transcript_cz'] as String? ?? '';
    final promptEn = data['prompt_en'] as String? ?? widget.exercise.prompt;
    final image = (data['image'] as String?)?.trim();
    final imageLabel = (data['image_label'] as String?)?.trim();
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);

    // The first slide: the task, the picture, the recording and its
    // transcript. The questions follow, one to a slide.
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A long brief is reading text, as for writing and speaking: in the
        // heading face 7100's three lines ran the first slide 10 pt over.
        QuestionPrompt(question: promptEn, instruction: true),
        const SizedBox(height: 16),

        if (image != null && image.isNotEmpty) ...[
          LessonImage(
            asset: image,
            height: 140,
            semanticLabel:
                imageLabel == null || imageLabel.isEmpty ? null : imageLabel,
          ),
          const SizedBox(height: 14),
        ],

        // Listen first: the audio is the exercise, so it gets the hero. With
        // a picture, the compact row the question slides use: picture,
        // panel, note and transcript were 60 pt taller than a small phone's
        // slide.
        if (transcriptCz.isNotEmpty && image != null && image.isNotEmpty)
          _ListenAgain(
            label:
                _playCount == 0 && !_autoPlayed
                    ? l10n.listen
                    : l10n.audioPlayAgain,
            onPlay: () {
              _played();
              ref.read(czechTtsProvider).speak(transcriptCz);
            },
            onSlow: () {
              _played();
              ref.read(czechTtsProvider).speakSlow(transcriptCz);
            },
          )
        else if (transcriptCz.isNotEmpty)
          ListenPanel(
            label:
                _playCount == 0 && !_autoPlayed
                    ? l10n.listen
                    : l10n.audioPlayAgain,
            onPlay: () {
              _played();
              ref.read(czechTtsProvider).speak(transcriptCz);
            },
            onSlow: () {
              _played();
              ref.read(czechTtsProvider).speakSlow(transcriptCz);
            },
          ),
        const SizedBox(height: 10),
        Text(
          l10n.exerciseGistFirstNote,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.45, color: t.faint),
        ),
        const SizedBox(height: 16),

        MotionSwap(
          alignment: Alignment.centerLeft,
          child:
              !_transcriptRevealed
                  ? Align(
                    key: const ValueKey('transcript-action'),
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed:
                          transcriptCz.isEmpty
                              ? null
                              : () =>
                                  setState(() => _transcriptRevealed = true),
                      icon: const Icon(Icons.subtitles_outlined, size: 18),
                      label: Text(l10n.exerciseRevealTranscript),
                    ),
                  )
                  : Container(
                    key: const ValueKey('transcript-content'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.elev,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      transcriptCz,
                      style: TextStyle(fontSize: 15, height: 1.6, color: t.ink),
                    ),
                  ),
        ),
      ],
    );

    Set<SupportKind> supports() => {
      if (_replayedAfterHearing) SupportKind.replay,
      if (_transcriptRevealed) SupportKind.transcript,
    };
    final questions =
        (data['questions'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
    return QuestionSteps(
      exerciseId: widget.exercise.id,
      questions: questions,
      intro: [header],
      reminder: _ListenAgain(
        onPlay: () {
          _played();
          ref.read(czechTtsProvider).speak(transcriptCz);
        },
        onSlow: () {
          _played();
          ref.read(czechTtsProvider).speakSlow(transcriptCz);
        },
      ),
      onComplete:
          (isCorrect, explanation, correctAnswer) => widget.onAnswered(
            ExerciseResult(
              isCorrect: isCorrect,
              explanation: explanation,
              correctAnswer: correctAnswer,
              supports: supports(),
            ),
          ),
    );
  }
}

/// Above each question slide: the recording again, at speed or slower, as one
/// compact row rather than the big panel of the first slide.
class _ListenAgain extends StatelessWidget {
  const _ListenAgain({this.label, required this.onPlay, required this.onSlow});

  /// "Play it again" unless given.
  final String? label;
  final VoidCallback onPlay;
  final VoidCallback onSlow;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: Text(label ?? l10n.audioPlayAgain),
            style: FilledButton.styleFrom(
              backgroundColor: t.violetSoft,
              foregroundColor: t.violetInk,
              minimumSize: const Size(0, 48),
              shape: shape,
            ),
          ),
        ),
        const SizedBox(width: 10),
        TextButton.icon(
          onPressed: onSlow,
          icon: const Icon(Icons.schedule, size: 16),
          label: Text(l10n.audioSlower),
          style: TextButton.styleFrom(
            foregroundColor: t.muted,
            minimumSize: const Size(0, 48),
            shape: shape,
          ),
        ),
      ],
    );
  }
}
