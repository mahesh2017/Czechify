import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/pronunciation_providers.dart';
import '../../providers/tts_providers.dart';
import '../../widgets/common/lesson_ui.dart';
import '../../widgets/common/record_button.dart';
import '../../../core/utils/score_colors.dart';
import '../../../domain/entities/pronunciation_result.dart';

/// Pronunciation lab — record-and-compare with visual feedback.
class PronunciationScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  final String? expectedText;

  const PronunciationScreen({
    super.key,
    required this.exerciseId,
    this.expectedText,
  });

  @override
  ConsumerState<PronunciationScreen> createState() =>
      _PronunciationScreenState();
}

class _PronunciationScreenState extends ConsumerState<PronunciationScreen> {
  /// Position in the practice deck (deck mode only).
  int _deckIndex = 0;

  /// Single-phrase mode: a caller (lesson, exam) supplied the exact text.
  bool get _singlePhrase => widget.expectedText != null;

  @override
  void initState() {
    super.initState();
    if (_singlePhrase) {
      Future.microtask(() {
        ref
            .read(pronunciationProvider.notifier)
            .setExpectedText(widget.expectedText!);
      });
    }
  }

  void _setPhraseFromDeck(List<String> deck) {
    final phrase = deck[_deckIndex % deck.length];
    if (ref.read(pronunciationProvider).expectedText != phrase) {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(pronunciationProvider.notifier).setExpectedText(phrase);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pronState = ref.watch(pronunciationProvider);
    final deck =
        _singlePhrase
            ? const <String>[]
            : ref.watch(pronunciationDeckProvider).value ??
                starterPronunciationPhrases;
    if (!_singlePhrase && deck.isNotEmpty) {
      _setPhraseFromDeck(deck);
    }

    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, title: Text(l10n.pronunciationLab)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // What to say, on the hero surface — hearing it and saying it are
            // the whole screen.
            TeachingHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: LessonKicker(l10n.sayThis, color: t.pri)),
                  const SizedBox(height: 12),
                  Text(
                    pronState.expectedText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AudioPairButtons(
                    onPlay:
                        () => ref
                            .read(czechTtsProvider)
                            .speak(pronState.expectedText),
                    onSlow:
                        () => ref
                            .read(czechTtsProvider)
                            .speakSlow(pronState.expectedText),
                    slowLabel: 'Slower',
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Recording state / score display
            if (pronState.isRecording)
              _RecordingIndicator()
            else if (pronState.isProcessing)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.analyzingPronunciation),
                ],
              )
            else if (pronState.result != null)
              Column(
                children: [
                  _ScoreDisplay(result: pronState.result!),
                  const SizedBox(height: 12),
                  Text(
                    'Heard: "${pronState.transcribedText ?? ''}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: context.tokens.muted),
                  ),
                  // Learners only see a gentle accuracy note when the cloud
                  // engine was unavailable; raw engine diagnostics (exception
                  // text, URLs, timings) are debug-build only.
                  if (!pronState.usedWhisper)
                    Text(
                      l10n.onDeviceRecognitionNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.tokens.amberInk,
                      ),
                    ),
                  if (kDebugMode && pronState.diagnostic != null)
                    Text(
                      pronState.diagnostic!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            pronState.usedWhisper
                                ? context.tokens.green
                                : context.tokens.amberInk,
                      ),
                    ),
                ],
              )
            else if (pronState.error != null)
              _ErrorDisplay(
                error: pronState.error!,
                suggestsMicrophoneCheck: !pronState.errorIsServiceSide,
              )
            else
              Text(
                l10n.tapMicrophoneHint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.45, color: t.muted),
              ),

            const Spacer(),

            // Record button — the mic ring is the app's only live state.
            RecordButton(
              isRecording: pronState.isRecording,
              onPressed: () {
                if (pronState.isRecording) {
                  ref.read(pronunciationProvider.notifier).stopRecording();
                } else {
                  ref
                      .read(pronunciationProvider.notifier)
                      .startRecording(expectedText: pronState.expectedText);
                }
              },
            ),
            const SizedBox(height: 16),

            // Try again / next phrase
            if (pronState.result != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ref.read(pronunciationProvider.notifier).reset();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.tryAgain),
                  ),
                  if (!_singlePhrase) ...[
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _deckIndex++);
                        ref.read(pronunciationProvider.notifier).reset();
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(l10n.nextPhrase),
                    ),
                  ],
                ],
              )
            else if (!_singlePhrase &&
                !pronState.isRecording &&
                !pronState.isProcessing)
              TextButton.icon(
                onPressed: () => setState(() => _deckIndex++),
                icon: const Icon(Icons.skip_next),
                label: Text(l10n.skip),
              ),
          ],
        ),
      ),
    );
  }
}

/// Animated recording indicator.
class _RecordingIndicator extends StatefulWidget {
  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.3).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
          ),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.tokens.redInk,
            ),
            child: Icon(Icons.mic, color: context.tokens.onFill, size: 36),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Listening...',
          style: TextStyle(
            color: context.tokens.redInk,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Score display with visual feedback.
class _ScoreDisplay extends StatelessWidget {
  final PronunciationResult result;

  const _ScoreDisplay({required this.result});

  @override
  Widget build(BuildContext context) {
    final scorePercent = (result.overallScore * 100).round();
    final color = _scoreColor(context, result.overallScore);
    final label = _scoreLabel(result.overallScore);

    final t = context.tokens;
    return Column(
      children: [
        Semantics(
          label: 'Score $scorePercent percent. $label',
          excludeSemantics: true,
          child: ScoreRing(
            fraction: result.overallScore,
            label: '$scorePercent%',
            caption: 'match',
            color: color,
            showBadge: result.overallScore >= 0.8,
            size: 112,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 14),

        // Word-by-word breakdown
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children:
              result.wordScores.map((ws) {
                final wordColor = _scoreColor(context, ws.score);
                // Icon + color so correctness never relies on color alone.
                return Semantics(
                  label:
                      '${ws.word}: '
                      '${ws.isCorrect ? 'pronounced well' : 'needs practice'}',
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ws.isCorrect ? t.greenSoft : t.elev,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ws.isCorrect ? Icons.check : Icons.priority_high,
                          size: 13,
                          color: wordColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          ws.word,
                          style: TextStyle(
                            fontSize: 14,
                            color: wordColor,
                            fontWeight:
                                ws.isCorrect
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        ),

        // Problem sounds feedback
        if (result.problemSounds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: context.tokens.amberSoft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: context.tokens.amberInk,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sounds to practice:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.tokens.amberInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...result.problemSounds.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.tokens.amberSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              switch (p.phoneme) {
                                'long_vowel' => 'á/é/í/ó/ú',
                                // Internal bucket name — show the word instead.
                                'other' => p.word,
                                _ => p.phoneme,
                              },
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'in "${p.word}"',
                              style: TextStyle(
                                fontSize: 15,
                                color: context.tokens.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],

        // Overall feedback
        const SizedBox(height: 12),
        Text(
          result.feedback,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: context.tokens.muted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Color _scoreColor(BuildContext context, double score) =>
      ScoreColors.of(context, score);

  String _scoreLabel(double score) {
    if (score >= 0.8) return 'Skvělé!';
    if (score >= 0.65) return 'Dobré';
    return 'Zkuste znovu';
  }
}

/// Error display.
class _ErrorDisplay extends StatelessWidget {
  final String error;
  const _ErrorDisplay({required this.error, this.suggestsMicrophoneCheck = true});

  /// Whether the failure could plausibly be a microphone or permission problem.
  final bool suggestsMicrophoneCheck;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.error_outline, size: 48, color: context.tokens.redInk),
        const SizedBox(height: 16),
        Text(
          error,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.tokens.redInk),
        ),
        // The microphone hint is only shown when the microphone is plausibly
        // the problem. A spent daily allowance or an unreachable service has
        // nothing to do with permissions, and saying so sends the learner to
        // settings to fix something that is not broken.
        if (suggestsMicrophoneCheck) ...[
          const SizedBox(height: 8),
          Text(
            'Make sure microphone permissions are granted.',
            style: TextStyle(fontSize: 14, color: context.tokens.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
