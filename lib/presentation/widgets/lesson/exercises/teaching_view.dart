import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../../domain/entities/exercise.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/tts_providers.dart';
import 'exercise_shared.dart';

/// A non-graded teaching card: presents a concept (an optional spoken intro,
/// then a heading + text + an interactive audio list) BEFORE the practice
/// exercises. The learner reads, listens, then taps Continue — no answer, no
/// heart, no XP.
///
/// Two row layouts are supported:
///  - **alphabet / numbers** (`style: "alphabet"`, or items carrying a
///    `symbol`): a big tinted symbol box + example word (Units 1 and 9).
///  - **list** (`style: "list"`, items carrying `cz` + `en`): a phrase/form on
///    the left with its English meaning, and a speaker to hear the Czech — used
///    for the grammar tables and vocabulary sets that open every other unit.
///
/// When the card carries an `intro` string, a friendly teacher character plays
/// above it and narrates the intro in English (swappable for a recorded voice
/// later). The character loops an idle animation and switches to a talking one
/// while the narration plays.
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

  /// Captured in initState so it can be stopped safely from dispose().
  EnglishTts? _english;

  @override
  void initState() {
    super.initState();
    _english = ref.read(englishTtsProvider);
  }

  /// Parsed once per exercise rather than on every build.
  ///
  /// This is decoded JSON feeding a list that rebuilds on each TTS tick —
  /// "play all" walks the items and calls setState per word, so the naive
  /// getter re-parsed the whole lesson's teaching payload for every frame of
  /// the playthrough.
  List<_TeachingItem>? _cachedItems;

  List<_TeachingItem> get _items => _cachedItems ??= _parseItems();

  List<_TeachingItem> _parseItems() {
    final raw = widget.exercise.data['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => _TeachingItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  void didUpdateWidget(covariant TeachingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The State outlives a swap to a different exercise, so a stale cache
    // would keep showing the previous lesson's words.
    if (!identical(oldWidget.exercise, widget.exercise)) _cachedItems = null;
  }

  /// "alphabet" (big symbol box) or "list" (phrase + meaning). Falls back to
  /// alphabet when items carry a symbol, otherwise list.
  String _styleFor(List<_TeachingItem> items) {
    final explicit = widget.exercise.data['style'] as String?;
    if (explicit == 'alphabet' || explicit == 'list') return explicit!;
    final hasSymbol = items.any((i) => i.symbol.isNotEmpty);
    return hasSymbol ? 'alphabet' : 'list';
  }

  Future<void> _say(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await ref.read(czechTtsProvider).speak(text);
    } catch (_) {
      // Speech is best-effort — a missing voice must not break the lesson.
    }
  }

  Future<void> _toggleIntro(String text) async {
    final tts = _english;
    if (tts == null) return;
    if (tts.speaking.value) {
      await tts.stop();
    } else {
      await tts.speak(text);
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
    // On an alphabet card "play all" recites the letter NAMES ("a, á, bé…"),
    // not the example words — the button says "Hear the alphabet (letter
    // names)". List cards have no separate name, so they play the phrase.
    final alphabet = _styleFor(items) == 'alphabet';
    setState(() => _playingAll = true);
    for (var i = 0; i < items.length; i++) {
      if (!_playingAll || !mounted) break;
      setState(() => _playingIndex = i);
      await _say(alphabet ? items[i].nameSay : items[i].playText);
      // TTS returns before playback finishes; a fixed pace gives a clear gap
      // between items.
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
    _english?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = widget.exercise.data;
    final heading = data['heading'] as String? ?? widget.exercise.prompt;
    final body = data['body'] as String?;
    final intro = (data['intro'] as String?)?.trim();
    final items = _items;
    final style = _styleFor(items);
    final playAllLabel =
        data['play_all_label'] as String? ?? 'Play the whole set';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (intro != null && intro.isNotEmpty) ...[
            _IntroBlock(
              text: intro,
              english: _english,
              onToggle: () => _toggleIntro(intro),
              // "v3" opts into the illustrated teacher art; other cards still
              // use the original Lottie until they're migrated.
              useIllustratedCharacter: (data['character'] as String?) == 'v3',
            ),
            const SizedBox(height: 18),
          ],
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
                child:
                    style == 'alphabet'
                        ? _LetterRow(
                          item: items[i],
                          active: _playingIndex == i,
                          onTapName: () => _say(items[i].nameSay),
                          onTapWord: () => _say(items[i].say),
                        )
                        : _PhraseRow(
                          item: items[i],
                          active: _playingIndex == i,
                          onTap: () => _say(items[i].playText),
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

/// The spoken intro: a looping teacher character beside the narration text and
/// a play/stop control. English TTS now; a recorded `.mp3` voice can replace it
/// later without changing this widget.
class _IntroBlock extends ConsumerWidget {
  final String text;
  final EnglishTts? english;
  final VoidCallback onToggle;

  /// Whether to show the illustrated teacher art instead of the older
  /// procedural Lottie character.
  final bool useIllustratedCharacter;

  const _IntroBlock({
    required this.text,
    required this.english,
    required this.onToggle,
    this.useIllustratedCharacter = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final gender = ref.watch(settingsProvider.select((s) => s.ttsVoiceGender));
    final genderKey = gender == TtsVoiceGender.male ? 'male' : 'female';
    final speaking = english?.speaking ?? ValueNotifier<bool>(false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: useIllustratedCharacter ? 112 : 92,
            height: useIllustratedCharacter ? 140 : 108,
            child:
                useIllustratedCharacter
                    ? _TeacherCharacter(
                      genderKey: genderKey,
                      speaking: speaking,
                    )
                    : ValueListenableBuilder<bool>(
                      valueListenable: speaking,
                      builder: (context, isSpeaking, _) {
                        final anim = isSpeaking ? 'talk' : 'idle';
                        return Lottie.asset(
                          'assets/animations/teacher_${genderKey}_$anim.json',
                          repeat: true,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (context, error, stack) => Icon(
                                Icons.person_outline,
                                size: 64,
                                color: cs.primary,
                              ),
                        );
                      },
                    ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<bool>(
                  valueListenable: speaking,
                  builder: (context, isSpeaking, _) {
                    return OutlinedButton.icon(
                      onPressed: onToggle,
                      icon: Icon(
                        isSpeaking ? Icons.stop : Icons.play_arrow,
                        size: 18,
                      ),
                      label: Text(isSpeaking ? 'Stop' : 'Intro'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The illustrated teacher. The artwork is a single still per gender, so the
/// life comes from motion rather than frames: a slow idle bob that becomes a
/// livelier bob-and-sway while the intro is being narrated.
class _TeacherCharacter extends StatefulWidget {
  final String genderKey; // 'female' | 'male'
  final ValueNotifier<bool> speaking;

  const _TeacherCharacter({required this.genderKey, required this.speaking});

  @override
  State<_TeacherCharacter> createState() => _TeacherCharacterState();
}

class _TeacherCharacterState extends State<_TeacherCharacter>
    with SingleTickerProviderStateMixin {
  static const _idleDuration = Duration(milliseconds: 2600);
  static const _talkDuration = Duration(milliseconds: 1100);

  late final AnimationController _bob;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _speaking = widget.speaking.value;
    _bob = AnimationController(
      vsync: this,
      duration: _speaking ? _talkDuration : _idleDuration,
    )..repeat(reverse: true);
    widget.speaking.addListener(_onSpeakingChanged);
  }

  void _onSpeakingChanged() {
    final speaking = widget.speaking.value;
    if (speaking == _speaking || !mounted) return;
    setState(() => _speaking = speaking);
    _bob
      ..duration = speaking ? _talkDuration : _idleDuration
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    widget.speaking.removeListener(_onSpeakingChanged);
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) {
        final t = _bob.value; // ping-pongs 0 → 1 → 0
        final amplitude = _speaking ? 5.0 : 2.5;
        final dy = -amplitude / 2 + amplitude * t;
        // A touch of sway only while talking, so idle stays calm.
        final angle = _speaking ? (t - 0.5) * 0.04 : 0.0;
        return Transform.rotate(
          angle: angle,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: Image.asset(
        'assets/images/teacher_${widget.genderKey}.png',
        fit: BoxFit.contain,
        // The art ships at ~3x the rendered size; cap the decode to match.
        cacheWidth: 400,
        filterQuality: FilterQuality.medium,
        errorBuilder:
            (context, error, stack) =>
                Icon(Icons.person_outline, size: 64, color: cs.primary),
      ),
    );
  }
}

/// One phrase/grammar row: a Czech form + its English meaning, tap anywhere to
/// hear the Czech. Used by the grammar-table and vocabulary teaching cards.
class _PhraseRow extends StatelessWidget {
  final _TeachingItem item;
  final bool active;
  final VoidCallback onTap;

  const _PhraseRow({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: active ? cs.primaryContainer : cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? cs.primary : cs.outlineVariant,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.cz,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        height: 1.25,
                      ),
                    ),
                    if (item.en.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.en,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.volume_up, color: cs.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// One full-width alphabet/number row: tap the row to hear the letter's NAME,
/// tap the speaker to hear the example WORD.
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
                          style: TextStyle(fontSize: 10.5, color: cs.primary),
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

  // List-style fields.
  final String cz;
  final String en;

  const _TeachingItem({
    required this.symbol,
    required this.name,
    required this.nameSay,
    required this.sound,
    required this.example,
    required this.exampleEn,
    required this.say,
    required this.cz,
    required this.en,
  });

  /// What "play all" and a row tap should speak (Czech).
  String get playText => say.isNotEmpty ? say : (cz.isNotEmpty ? cz : nameSay);

  factory _TeachingItem.fromJson(Map<String, dynamic> json) {
    final symbol = (json['symbol'] as String? ?? '').trim();
    final example = (json['example'] as String? ?? '').trim();
    final nameSay = (json['name_say'] as String? ?? '').trim();
    final cz = (json['cz'] as String? ?? '').trim();
    final rawSay = (json['say'] as String? ?? '').trim();
    return _TeachingItem(
      symbol: symbol,
      name: (json['name'] as String? ?? '').trim(),
      // Fall back to the symbol when no explicit name audio is given.
      nameSay: nameSay.isEmpty ? symbol : nameSay,
      sound: (json['sound'] as String? ?? '').trim(),
      example: example,
      exampleEn: (json['example_en'] as String? ?? '').trim(),
      // Speech source, in order: explicit say → Czech phrase → example word.
      say: rawSay.isNotEmpty ? rawSay : (cz.isNotEmpty ? cz : example),
      cz: cz,
      en: (json['en'] as String? ?? '').trim(),
    );
  }
}
