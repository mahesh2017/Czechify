import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/pronunciation_providers.dart';
import '../../providers/tts_providers.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pronunciationLab)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Expected text display
            Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      l10n.sayThis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: context.tokens.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pronState.expectedText,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // TTS button to hear correct pronunciation
                    IconButton(
                      onPressed: () {
                        ref
                            .read(czechTtsProvider)
                            .speak(pronState.expectedText);
                      },
                      icon: const Icon(Icons.volume_up, size: 28),
                      color: Theme.of(context).colorScheme.primary,
                      tooltip: 'Listen to correct pronunciation',
                    ),
                  ],
                ),
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
                        color: context.tokens.amber,
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
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                      ),
                    ),
                ],
              )
            else if (pronState.error != null)
              _ErrorDisplay(error: pronState.error!)
            else
              Text(
                l10n.tapMicrophoneHint,
                style: TextStyle(color: context.tokens.muted),
              ),

            const Spacer(),

            // Record button
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
              color: Colors.red.shade400,
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Listening...',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
    final color = _scoreColor(result.overallScore);
    final label = _scoreLabel(result.overallScore);

    return Column(
      children: [
        // Circular score
        Semantics(
          label: 'Score $scorePercent percent. $label',
          child: SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fill the 120px box — an unconstrained child of a Stack would
                // render at the indicator's tiny intrinsic size, drawing a small
                // ring on top of the score text instead of around it.
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: result.overallScore,
                    strokeWidth: 8,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                // Keep the number + label inside the ring regardless of the
                // device's system font scale: pad in from the stroke, then let
                // FittedBox shrink the text to fit rather than overflow/overlap.
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$scorePercent%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          label,
                          style: TextStyle(fontSize: 14, color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Word-by-word breakdown
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children:
              result.wordScores.map((ws) {
                final wordColor = _scoreColor(ws.score);
                // Icon + color so correctness never relies on color alone.
                return Semantics(
                  label:
                      '${ws.word}: '
                      '${ws.isCorrect ? 'pronounced well' : 'needs practice'}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: wordColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: wordColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ws.isCorrect ? Icons.check : Icons.priority_high,
                          size: 13,
                          color: wordColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ws.word,
                          style: TextStyle(
                            color: wordColor,
                            fontWeight:
                                ws.isCorrect
                                    ? FontWeight.bold
                                    : FontWeight.normal,
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
            color: Colors.orange.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sounds to practice:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
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
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
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
                                color: Colors.grey.shade700,
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
            color: Colors.grey.shade700,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Color _scoreColor(double score) => ScoreColors.of(score);

  String _scoreLabel(double score) {
    if (score >= 0.8) return 'Skvělé!';
    if (score >= 0.65) return 'Dobré';
    return 'Zkuste znovu';
  }
}

/// Error display.
class _ErrorDisplay extends StatelessWidget {
  final String error;
  const _ErrorDisplay({required this.error});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(
          error,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red.shade700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Make sure microphone permissions are granted.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
