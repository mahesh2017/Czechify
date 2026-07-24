import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/exercise.dart';
import '../../../providers/tts_providers.dart';
import 'exercise_shared.dart';

/// A non-graded teaching card: presents a concept (heading + text + an
/// interactive audio grid) BEFORE the practice exercises. The learner reads,
/// listens, then taps Continue — no answer, no heart, no XP.
///
/// For Unit 1 the grid is the Czech alphabet: every letter with its sound and
/// an example word, each tappable to hear, plus a "play the whole alphabet"
/// button that speaks each item with a pause. The media block is deliberately
/// generic so it can later be swapped for a video.
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
      await _say(items[i].say);
      // TTS returns before playback finishes; pace by word length with a
      // floor so short letters still get a clear pause between them.
      final ms = 700 + items[i].say.length * 90;
      await Future<void>.delayed(Duration(milliseconds: ms.clamp(900, 2200)));
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A quiet "Learn" marker so it's clearly teaching, not a question.
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
              style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant, height: 1.45),
            ),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _playAll(items),
              icon: Icon(_playingAll ? Icons.stop : Icons.play_arrow),
              label: Text(_playingAll ? 'Stop' : playAllLabel),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < items.length; i++)
                  _LetterCard(
                    item: items[i],
                    active: _playingIndex == i,
                    onTap: () => _say(items[i].say),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // A teaching card is never graded — advance straight to practice.
              widget.onAnswered(const ExerciseResult.skipped());
            },
            icon: const Icon(Icons.check),
            label: const Text('Got it — start practising'),
          ),
        ],
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  final _TeachingItem item;
  final bool active;
  final VoidCallback onTap;

  const _LetterCard({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: active ? cs.primaryContainer : cs.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? cs.primary : cs.outlineVariant,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  item.symbol,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.sound.isNotEmpty)
                      Text(
                        item.sound,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    if (item.example.isNotEmpty)
                      Text(
                        item.exampleEn.isEmpty
                            ? item.example
                            : '${item.example} — ${item.exampleEn}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.volume_up, size: 15, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeachingItem {
  final String symbol;
  final String sound;
  final String example;
  final String exampleEn;
  final String say;

  const _TeachingItem({
    required this.symbol,
    required this.sound,
    required this.example,
    required this.exampleEn,
    required this.say,
  });

  factory _TeachingItem.fromJson(Map<String, dynamic> json) {
    final example = (json['example'] as String? ?? '').trim();
    return _TeachingItem(
      symbol: (json['symbol'] as String? ?? '').trim(),
      sound: (json['sound'] as String? ?? '').trim(),
      example: example,
      exampleEn: (json['example_en'] as String? ?? '').trim(),
      // Speak the example word (a clear, reliable sound) unless an explicit
      // `say` is provided.
      say: (json['say'] as String? ?? '').trim().isEmpty
          ? example
          : (json['say'] as String).trim(),
    );
  }
}
