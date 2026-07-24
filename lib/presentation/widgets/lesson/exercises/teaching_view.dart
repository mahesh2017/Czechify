import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/exercise.dart';
import '../../../providers/tts_providers.dart';
import 'exercise_shared.dart';

/// A non-graded teaching card: presents a concept (heading + text + an
/// interactive audio list) BEFORE the practice exercises. The learner reads,
/// listens, then taps Continue — no answer, no heart, no XP.
///
/// For Unit 1 the list is the Czech alphabet: every letter with its NAME (how
/// the letter is called — tap the row to hear it) and an example word showing
/// the sound inside a word (tap the speaker). "Play the whole alphabet"
/// recites the letter names with a pause between each. The media block is
/// deliberately generic so it can later be swapped for a video.
class TeachingView extends ConsumerStatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const TeachingView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  ConsumerState<TeachingView> createState() => _TeachingViewState();
}

class _TeachingViewState extends ConsumerState<TeachingView> {
  /// Index currently being spoken during "play all", or -1 when idle.
  int _playingIndex = -1;
  bool _playingAll = false;

  List<_TeachingItem> get _items {
    final raw = widget.exercise.data['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => _TeachingItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> _say(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await ref.read(czechTtsProvider).speak(text);
    } catch (_) {
      // Speech is best-effort — a missing voice must not break the lesson.
    }
  }

  Future<void> _playAll(List<_TeachingItem> items) async {
    if (_playingAll) {
      setState(() {
        _playingAll = false;
        _playingIndex = -1;
      });
      return;
    }
    setState(() => _playingAll = true);
    for (var i = 0; i < items.length; i++) {
      if (!_playingAll || !mounted) break;
      setState(() => _playingIndex = i);
      await _say(items[i].nameSay);
      // TTS returns before playback finishes; a fixed pace gives a clear gap
      // between letters.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }
    if (mounted) {
      setState(() {
        _playingAll = false;
        _playingIndex = -1;
      });
    }
  }

  @override
  void dispose() {
    _playingAll = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = widget.exercise.data;
    final heading = data['heading'] as String? ?? widget.exercise.prompt;
    final body = data['body'] as String?;
    final items = _items;
    final playAllLabel =
        data['play_all_label'] as String? ?? 'Play the whole set';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Learn',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            heading,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(
                fontSize: 14.5,
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _playAll(items),
                icon: Icon(_playingAll ? Icons.stop : Icons.play_arrow),
                label: Text(_playingAll ? 'Stop' : playAllLabel),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LetterRow(
                  item: items[i],
                  active: _playingIndex == i,
                  onTapName: () => _say(items[i].nameSay),
                  onTapWord: () => _say(items[i].say),
                ),
              ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                // A teaching card is never graded — advance straight to
                // practice.
                widget.onAnswered(const ExerciseResult.skipped());
              },
              icon: const Icon(Icons.check),
              label: const Text('Got it — start practising'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One full-width alphabet row: tap the row to hear the letter's NAME, tap the
/// speaker to hear the example WORD.
class _LetterRow extends StatelessWidget {
  final _TeachingItem item;
  final bool active;
  final VoidCallback onTapName;
  final VoidCallback onTapWord;

  const _LetterRow({
    required this.item,
    required this.active,
    required this.onTapName,
    required this.onTapWord,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: active ? cs.primaryContainer : cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTapName,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? cs.primary : cs.outlineVariant,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Letter + its name, in a tinted box.
              Container(
                width: 62,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      item.symbol,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        height: 1.0,
                      ),
                    ),
                    if (item.name.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: cs.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Sound + example.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.sound.isNotEmpty)
                      Text(
                        item.sound,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    if (item.example.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.exampleEn.isEmpty
                            ? item.example
                            : '${item.example} — ${item.exampleEn}',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Play the example word.
              if (item.example.isNotEmpty)
                IconButton(
                  onPressed: onTapWord,
                  icon: const Icon(Icons.volume_up),
                  color: cs.primary,
                  tooltip: 'Hear the word',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeachingItem {
  final String symbol;
  final String name;
  final String nameSay;
  final String sound;
  final String example;
  final String exampleEn;
  final String say;

  const _TeachingItem({
    required this.symbol,
    required this.name,
    required this.nameSay,
    required this.sound,
    required this.example,
    required this.exampleEn,
    required this.say,
  });

  factory _TeachingItem.fromJson(Map<String, dynamic> json) {
    final symbol = (json['symbol'] as String? ?? '').trim();
    final example = (json['example'] as String? ?? '').trim();
    final nameSay = (json['name_say'] as String? ?? '').trim();
    return _TeachingItem(
      symbol: symbol,
      name: (json['name'] as String? ?? '').trim(),
      // Fall back to the symbol when no explicit name audio is given.
      nameSay: nameSay.isEmpty ? symbol : nameSay,
      sound: (json['sound'] as String? ?? '').trim(),
      example: example,
      exampleEn: (json['example_en'] as String? ?? '').trim(),
      say: (json['say'] as String? ?? '').trim().isEmpty
          ? example
          : (json['say'] as String).trim(),
    );
  }
}
