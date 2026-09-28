import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/tts_providers.dart';
import '../../common/lesson_image.dart';
import '../../common/lesson_ui.dart';
import '../../common/motion_widgets.dart';
import '../../common/slide_deck.dart';
import '../../common/soft_ui.dart';
import '../exercise_slides.dart';
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

  /// The last button's label, when the step is shown outside the lesson's
  /// flow (the lesson's Recap sheet): "Back to the lesson" rather than
  /// "Start practising".
  final String? doneLabel;

  const TeachingView({
    super.key,
    required this.exercise,
    required this.onAnswered,
    this.doneLabel,
  });

  @override
  ConsumerState<TeachingView> createState() => _TeachingViewState();
}

class _TeachingViewState extends ConsumerState<TeachingView> {
  /// Index currently being spoken during "play all", or -1 when idle.
  int _playingIndex = -1;
  bool _playingAll = false;
  int _imageTeachingPage = 0;
  bool _translationRevealed = false;

  /// The word list as slides, and the block its first line is.
  final _deck = GlobalKey<SlideDeckState>();
  int _firstRowBlock = 0;

  /// Items on one slide block: a row of four in the letter grid, else one.
  int _itemsPerBlock = 1;

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
    if (!identical(oldWidget.exercise, widget.exercise)) {
      _imageTeachingPage = 0;
      _translationRevealed = false;
    }
  }

  /// "alphabet" (big symbol box) or "list" (phrase + meaning). Falls back to
  /// alphabet when items carry a symbol, otherwise list.
  String _styleFor(List<_TeachingItem> items) {
    final explicit = widget.exercise.data['style'] as String?;
    if (explicit == 'alphabet' ||
        explicit == 'list' ||
        explicit == 'image_cards') {
      return explicit!;
    }
    final hasSymbol = items.any((i) => i.symbol.isNotEmpty);
    return hasSymbol ? 'alphabet' : 'list';
  }

  Future<void> _say(String text) async {
    if (text.trim().isEmpty) return;
    try {
      // No rate argument: speak() reads the learner's stored speed, which the
      // selector under the play button writes. Passing one here would pin the
      // pace and ignore what they chose.
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
      // On slides, turn to the line being played.
      _deck.currentState?.showBlock(_firstRowBlock + i ~/ _itemsPerBlock);
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

  /// Whether the set is a plain roster of characters — symbols with no
  /// respelling and no example word.
  ///
  /// Those are the sets the handoff lays out as a four-up "tap to hear" grid.
  /// Anything carrying a sound or an example needs the full-width row to have
  /// somewhere to put it.
  bool _isBareSymbolSet(List<_TeachingItem> items) =>
      items.isNotEmpty &&
      items.every(
        (i) => i.symbol.isNotEmpty && i.sound.isEmpty && i.example.isEmpty,
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final data = widget.exercise.data;
    final heading = data['heading'] as String? ?? widget.exercise.prompt;
    final body = data['body'] as String?;
    final intro = (data['intro'] as String?)?.trim();
    final items = _items;
    if (data['style'] == 'lecture') return _buildLecture(context);
    final style = _styleFor(items);
    if (style == 'image_cards' && items.isNotEmpty) {
      return _buildImageTeachingSequence(context, items);
    }
    // Content may name the set it plays; otherwise the generic label.
    final playAllLabel =
        data['play_all_label'] as String? ?? l10n.teachingPlayWholeSet;
    final grid = style == 'alphabet' && _isBareSymbolSet(items);
    if (showsAsSlides(widget.exercise) &&
        (style == 'list' || style == 'alphabet')) {
      return _buildListSlides(
        context,
        heading: heading,
        body: body,
        intro: intro,
        playAllLabel: playAllLabel,
        style: style,
        grid: grid,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (intro != null && intro.isNotEmpty) ...[
            _IntroBlock(
              text: intro,
              english: _english,
              onToggle: () => _toggleIntro(intro),
            ),
            const SizedBox(height: 16),
          ],

          // The concept itself, on the hero surface. The watermark is the
          // letter being taught, bled off the corner — only meaningful when
          // the whole card is about one character.
          TeachingHeroCard(
            watermark: grid && items.length == 1 ? items.first.symbol : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LessonKicker(l10n.teachingKicker, color: t.pri),
                const SizedBox(height: 12),
                DisplayText(
                  heading,
                  size: 26,
                  weight: FontWeight.w800,
                  height: 1.1,
                ),
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: TextStyle(fontSize: 15, color: t.muted, height: 1.5),
                  ),
                ],
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AudioPairButtons(
                    playing: _playingAll,
                    playLabel: playAllLabel,
                    onPlay: () => _playAll(items),
                  ),
                ],
              ],
            ),
          ),

          if (items.isNotEmpty) ...[
            const SizedBox(height: 22),
            LessonKicker(
              grid
                  ? l10n.teachingTapAnyLetter
                  : style == 'alphabet'
                  ? l10n.teachingLetterByLetter
                  : l10n.teachingTapLineToHear,
            ),
            const SizedBox(height: 10),
            if (grid)
              _LetterGrid(
                items: items,
                playingIndex: _playingIndex,
                onTap: (i) => _say(items[i].nameSay),
              )
            else
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
          const SizedBox(height: 22),
          KeyCta(
            label: widget.doneLabel ?? l10n.lessonGotItStartPractising,
            // A teaching card is never graded — advance straight to practice.
            onPressed: () => widget.onAnswered(const ExerciseResult.skipped()),
          ),
        ],
      ),
    );
  }

  /// A word list on slides: the teacher's intro, the card with "play all",
  /// then the lines, as many to a slide as fit.
  Widget _buildListSlides(
    BuildContext context, {
    required String heading,
    required String? body,
    required String? intro,
    required String playAllLabel,
    String style = 'list',
    bool grid = false,
  }) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final items = _items;
    final hasIntro = intro != null && intro.isNotEmpty;
    _firstRowBlock = (hasIntro ? 1 : 0) + 1;
    // The letter grid goes on slides a row of four at a time.
    _itemsPerBlock = grid ? 4 : 1;
    final rows = (items.length / _itemsPerBlock).ceil();
    final blocks = <Widget Function()>[
      if (hasIntro)
        () => _IntroBlock(
          text: intro,
          english: _english,
          onToggle: () => _toggleIntro(intro),
        ),
      () => TeachingHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LessonKicker(l10n.teachingKicker, color: t.pri),
            const SizedBox(height: 12),
            DisplayText(heading, size: 26, weight: FontWeight.w800, height: 1.1),
            if (body != null && body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: TextStyle(fontSize: 15, color: t.muted, height: 1.5),
              ),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 16),
              AudioPairButtons(
                playing: _playingAll,
                playLabel: playAllLabel,
                onPlay: () => _playAll(items),
              ),
            ],
          ],
        ),
      ),
      for (var i = 0; i < rows; i++)
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (i == 0) ...[
              LessonKicker(
                grid
                    ? l10n.teachingTapAnyLetter
                    : style == 'alphabet'
                    ? l10n.teachingLetterByLetter
                    : l10n.teachingTapLineToHear,
              ),
              const SizedBox(height: 10),
            ],
            if (grid)
              _LetterGrid(
                items: items.sublist(i * 4, math.min(items.length, i * 4 + 4)),
                playingIndex: _playingIndex - i * 4,
                onTap: (k) => _say(items[i * 4 + k].nameSay),
              )
            else if (style == 'alphabet')
              _LetterRow(
                item: items[i],
                active: _playingIndex == i,
                onTapName: () => _say(items[i].nameSay),
                onTapWord: () => _say(items[i].say),
              )
            else
              _PhraseRow(
                item: items[i],
                active: _playingIndex == i,
                onTap: () => _say(items[i].playText),
              ),
          ],
        ),
    ];
    return SlideDeck.packed(
      key: _deck,
      blockCount: blocks.length,
      blockBuilder: (context, index, _) => blocks[index](),
      gap: 10,
      doneLabel: widget.doneLabel ?? l10n.lessonGotItStartPractising,
      // A teaching card is never graded — advance straight to practice.
      onDone: () => widget.onAnswered(const ExerciseResult.skipped()),
    );
  }

  /// One lecture step (plan v1.2, §3.2): what it means, a small table of the
  /// forms in scope, examples to hear and the mistake learners make most.
  /// A check question follows it in the lesson, so it ends on "check me"
  /// rather than "start practising".
  ///
  /// The step's text is generated from the grammar rule's `lecture` entry
  /// (`tool/sync_lecture_cards.py`), so the lesson and the Grammar reference
  /// never teach two versions of it. The card also carries plain `items`, which
  /// is what an app that predates this layout shows instead.
  Widget _buildLecture(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final intro = (widget.exercise.data['intro'] as String?)?.trim();
    final lead =
        intro != null && intro.isNotEmpty
            ? _IntroBlock(
              text: intro,
              english: _english,
              onToggle: () => _toggleIntro(intro),
            )
            : null;
    return LectureSlides(
      exercise: widget.exercise,
      lead: lead,
      doneLabel: l10n.lectureContinue,
      onDone: () => widget.onAnswered(const ExerciseResult.skipped()),
    );
  }

  /// The last page of a picture-card step: its phrases without a picture, as
  /// a word list.
  Widget _buildPhrasePage(BuildContext context, List<_TeachingItem> phrases) {
    final l10n = AppLocalizations.of(context);
    return MotionEntrance(
      key: ValueKey('teaching-page-$_imageTeachingPage'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LessonKicker(l10n.teachingTapLineToHear),
            const SizedBox(height: 10),
            for (final phrase in phrases) ...[
              _PhraseRow(
                item: phrase,
                active: false,
                onTap: () => _say(phrase.playText),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            KeyCta(
              label: widget.doneLabel ?? l10n.teachingStartExercises,
              onPressed:
                  () => widget.onAnswered(const ExerciseResult.skipped()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageTeachingSequence(
    BuildContext context,
    List<_TeachingItem> items,
  ) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    // Phrases without a picture are not given an empty picture box twice
    // each; they close the step together on one word-list page.
    final phrases =
        items.any((i) => i.image.isNotEmpty)
            ? items.where((i) => i.image.isEmpty).toList()
            : const <_TeachingItem>[];
    if (phrases.isNotEmpty) {
      items = items.where((i) => i.image.isNotEmpty).toList();
    }
    if (_imageTeachingPage == items.length * 2) {
      return _buildPhrasePage(context, phrases);
    }
    final wordIndex = _imageTeachingPage ~/ 2;
    final sentencePage = _imageTeachingPage.isOdd;
    final item = items[wordIndex];
    final lastPage =
        phrases.isEmpty && _imageTeachingPage == items.length * 2 - 1;

    void advance() {
      if (lastPage) {
        widget.onAnswered(const ExerciseResult.skipped());
        return;
      }
      setState(() {
        _imageTeachingPage++;
        _translationRevealed = false;
      });
      if (!sentencePage) {
        unawaited(_say(item.sentence));
      }
    }

    return MotionEntrance(
      key: ValueKey('teaching-page-$_imageTeachingPage'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LessonKicker(
                    sentencePage
                        ? l10n.teachingInSentence
                        : l10n.teachingLookAndGuess,
                    color: t.pri,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.teachingWordProgress(wordIndex + 1, items.length),
                  style: TextStyle(
                    color: t.faint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LessonImage(
              asset: item.image,
              aspectRatio: 1.25,
              semanticLabel: item.imageLabel,
            ),
            const SizedBox(height: 14),
            if (!sentencePage) ...[
              Semantics(
                button: true,
                child: InkWell(
                  onTap: () {
                    _say(item.cz);
                    setState(() => _translationRevealed = true);
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: SoftCard(
                    shadow: false,
                    border: Border.all(color: t.line),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: DisplayText(
                                item.cz,
                                size: 30,
                                weight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.volume_up_outlined, color: t.pri),
                          ],
                        ),
                        const SizedBox(height: 6),
                        MotionSwap(
                          child:
                              _translationRevealed
                                  ? Column(
                                    key: const ValueKey('meaning'),
                                    children: [
                                      Text(
                                        l10n.teachingMeaning.toUpperCase(),
                                        style: TextStyle(
                                          color: t.faint,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item.en,
                                        style: TextStyle(
                                          color: t.muted,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                  : Text(
                                    l10n.teachingTapWordMeaning,
                                    key: const ValueKey('hint'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: t.faint,
                                      fontSize: 13,
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      button: true,
                      label: AppLocalizations.of(context).a11yTapToHearSentence,
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () {
                          _say(item.sentence);
                          setState(() => _translationRevealed = true);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Text(
                                  item.sentence,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: t.ink,
                                    fontFamily: AppFonts.display,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.volume_up_outlined,
                                  color: t.pri,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    MotionSwap(
                      child:
                          _translationRevealed
                              ? Text(
                                item.sentenceEn,
                                key: const ValueKey('sentence-meaning'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: t.muted,
                                  fontSize: 15,
                                  height: 1.45,
                                ),
                              )
                              : Text(
                                l10n.teachingTapSentenceTranslation,
                                key: const ValueKey('sentence-hint'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: t.faint, fontSize: 13),
                              ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            KeyCta(
              label:
                  lastPage
                      ? widget.doneLabel ?? l10n.teachingStartExercises
                      : sentencePage
                      ? l10n.teachingNextWord
                      : l10n.teachingSeeExample,
              onPressed: advance,
            ),
          ],
        ),
      ),
    );
  }
}

/// The four-up character grid: one tile per letter, tap to hear its name.
///
/// Used instead of full-width rows when the set is nothing but characters —
/// forty-two rows of a single glyph each is a scroll with no shape to it.
/// A lecture step's parts, parsed once: the explanation card, the table (its
/// right-hand cell is spoken, so lecture tables put the Czech there), the
/// examples and the common mistake. [LectureContent] lays them out on one
/// page; [LectureSlides] one part per slide.
class _LectureParts {
  _LectureParts(this.exercise)
    : heading = exercise.data['heading'] as String? ?? exercise.prompt,
      say = (exercise.data['say'] as String?) ?? (exercise.data['body'] as String?),
      step = (exercise.data['step'] as num?)?.toInt(),
      steps = (exercise.data['steps'] as num?)?.toInt(),
      table = [
        for (final row in (exercise.data['table'] as List? ?? const []))
          if (row is List && row.length >= 2) ('${row[0]}', '${row[1]}'),
      ],
      examples = [
        for (final example in (exercise.data['examples'] as List? ?? const []))
          if (example is Map)
            _TeachingItem.fromJson(Map<String, dynamic>.from(example)),
      ],
      wrong = _mistake(exercise.data, 'wrong'),
      right = _mistake(exercise.data, 'right');

  final Exercise exercise;
  final String heading;
  final String? say;
  final int? step;
  final int? steps;
  final List<(String, String)> table;
  final List<_TeachingItem> examples;
  final String wrong;
  final String right;

  static String _mistake(Map<String, dynamic> data, String key) {
    final mistake = data['common_mistake'];
    return mistake is Map ? '${mistake[key] ?? ''}'.trim() : '';
  }

  bool get hasMistake => wrong.isNotEmpty && right.isNotEmpty;

  Widget hero(
    BuildContext context, {
    String? kicker,
    bool showHeading = true,
  }) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return TeachingHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeading) ...[
            LessonKicker(
              kicker ??
                  (step != null && steps != null
                      ? l10n.lectureKicker(step!, steps!)
                      : l10n.teachingKicker),
              color: t.pri,
            ),
            const SizedBox(height: 12),
            DisplayText(heading, size: 26, weight: FontWeight.w800, height: 1.1),
          ],
          if (say != null && say!.trim().isNotEmpty) ...[
            if (showHeading) const SizedBox(height: 10),
            Text(
              say!,
              style: TextStyle(fontSize: 17, height: 1.5, color: t.ink),
            ),
          ],
        ],
      ),
    );
  }

  Widget tableCard(
    BuildContext context,
    List<(String, String)> rows,
    void Function(String) speak, {
    bool slim = false,
  }) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return SoftCard(
      shadow: false,
      border: Border.all(color: t.line),
      padding:
          slim
              ? const EdgeInsets.fromLTRB(16, 2, 4, 2)
              : const EdgeInsets.all(18),
      radius: slim ? 16 : 24,
      child: Column(
        children: [
          // The right-hand cell is the one spoken, so lecture tables put the
          // Czech there: cue → Czech.
          for (final (from, to) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      from,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: t.ink,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 16, color: t.faint),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Text(
                      to,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: t.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => speak(to),
                    tooltip: l10n.listen,
                    icon: Icon(Icons.volume_up_outlined, size: 20, color: t.pri),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> exampleRows(
    BuildContext context,
    List<_TeachingItem> items,
    void Function(String) speak,
  ) => [
    LessonKicker(AppLocalizations.of(context).lectureExamples),
    const SizedBox(height: 8),
    for (final example in items)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _PhraseRow(
          item: example,
          active: false,
          onTap: () => speak(example.playText),
        ),
      ),
  ];

  List<Widget> mistakeCard(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return [
      LessonKicker(l10n.lectureCommonMistake),
      const SizedBox(height: 8),
      SoftCard(
        shadow: false,
        color: t.elev,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MistakeLine(
              label: l10n.lectureWrongLabel,
              text: wrong,
              color: t.redInk,
              struck: true,
            ),
            const SizedBox(height: 6),
            _MistakeLine(label: l10n.lectureRightLabel, text: right, color: t.greenInk),
          ],
        ),
      ),
    ];
  }
}

Future<void> _speakCzech(WidgetRef ref, String text) async {
  if (text.trim().isEmpty) return;
  try {
    await ref.read(czechTtsProvider).speak(text);
  } catch (_) {
    // Speech is best-effort — a missing voice must not break the card.
  }
}

/// One lecture step on one page: explanation, table, examples and the common
/// mistake.
class LectureContent extends ConsumerWidget {
  final Exercise exercise;

  /// Replaces the "step 1 of 2" kicker, e.g. with the lesson it came from.
  final String? kicker;

  /// False where the card sits under its own heading already (a unit guide
  /// tile): the kicker and heading would only repeat it.
  final bool showHeading;

  const LectureContent({
    super.key,
    required this.exercise,
    this.kicker,
    this.showHeading = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = _LectureParts(exercise);
    void speak(String text) => _speakCzech(ref, text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        parts.hero(context, kicker: kicker, showHeading: showHeading),
        if (parts.table.isNotEmpty) ...[
          const SizedBox(height: 16),
          parts.tableCard(context, parts.table, speak),
        ],
        if (parts.examples.isNotEmpty) ...[
          const SizedBox(height: 18),
          ...parts.exampleRows(context, parts.examples, speak),
        ],
        if (parts.hasMistake) ...[
          const SizedBox(height: 10),
          ...parts.mistakeCard(context),
        ],
      ],
    );
  }
}

/// One lecture step as slides, so nothing has to be scrolled: the
/// explanation, the table a row at a time, the examples and the common
/// mistake, packed onto as few slides as fit ([SlideDeck.packed]). The last
/// slide's button finishes ([onDone]).
///
/// Needs bounded height: the lesson gives it the exercise area, the unit guide
/// and the Rule screen a whole screen.
class LectureSlides extends ConsumerWidget {
  final Exercise exercise;
  final String? kicker;

  /// Shown above the explanation on the first slide (the teacher's intro).
  final Widget? lead;
  final String doneLabel;
  final VoidCallback onDone;

  const LectureSlides({
    super.key,
    required this.exercise,
    required this.doneLabel,
    required this.onDone,
    this.kicker,
    this.lead,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = _LectureParts(exercise);
    void speak(String text) => _speakCzech(ref, text);
    final examples = parts.examples.take(3).toList();
    // In order: the explanation, the table a row at a time, the examples,
    // the common mistake. The deck puts together whatever fits.
    final blocks = <Widget Function(bool leadsSlide)>[
      (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lead != null) ...[lead!, const SizedBox(height: 16)],
          parts.hero(context, kicker: kicker),
        ],
      ),
      // The table a row at a time, each a slim card, so the deck turns the
      // page where the rows really run out of room: five long rows were
      // taller than a slide (7301, 24301, 26301), and in the Rule sheet,
      // which has less room than the lesson, seven short ones were (4301).
      for (final row in parts.table)
        (leadsSlide) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Under the explanation the heading is already on screen.
            if (leadsSlide) ...[
              Text(
                parts.heading,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.tokens.ink,
                ),
              ),
              const SizedBox(height: 12),
            ],
            parts.tableCard(context, [row], speak, slim: true),
          ],
        ),
      if (examples.isNotEmpty)
        (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: parts.exampleRows(context, examples, speak),
        ),
      if (parts.hasMistake)
        (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: parts.mistakeCard(context),
        ),
    ];
    const firstRow = 1;
    final lastRow = parts.table.length;
    return SlideDeck.packed(
      blockCount: blocks.length,
      blockBuilder: (context, index, leadsSlide) => blocks[index](leadsSlide),
      gap: 16,
      gapBefore: (i) => i > firstRow && i <= lastRow ? 6 : 16,
      doneLabel: doneLabel,
      onDone: onDone,
    );
  }
}

class _LetterGrid extends StatelessWidget {
  const _LetterGrid({
    required this.items,
    required this.playingIndex,
    required this.onTap,
  });

  final List<_TeachingItem> items;
  final int playingIndex;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        // 44pt minimum with room for the letter name underneath.
        mainAxisExtent: 62,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final active = playingIndex == i;
        return Semantics(
          button: true,
          label:
              item.name.isEmpty ? item.symbol : '${item.symbol}, ${item.name}',
          excludeSemantics: true,
          child: Material(
            color: active ? t.priSoft : t.card,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: active ? t.pri : t.line),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.symbol,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 24,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: t.pri,
                      ),
                    ),
                    if (item.name.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: t.faint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The spoken intro: the teacher beside the narration text and a play/stop
/// control. English TTS now; a recorded `.mp3` voice can replace it later
/// without changing this widget.
class _IntroBlock extends ConsumerWidget {
  final String text;
  final EnglishTts? english;
  final VoidCallback onToggle;

  const _IntroBlock({
    required this.text,
    required this.english,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final gender = ref.watch(settingsProvider.select((s) => s.ttsVoiceGender));
    final genderKey = gender == TtsVoiceGender.male ? 'male' : 'female';
    final speaking = english?.speaking ?? ValueNotifier<bool>(false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        // Notched toward the tutor, the same shape TutorBubble uses — this is
        // the same character speaking, just with their portrait instead of an
        // initial tile.
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
          bottomLeft: Radius.circular(6),
        ),
        border: Border.all(color: t.line),
        boxShadow: t.shadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            height: 140,
            child: _TeacherCharacter(genderKey: genderKey, speaking: speaking),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(fontSize: 15, height: 1.5, color: t.ink),
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
                      label: Text(
                        isSpeaking
                            ? AppLocalizations.of(context).audioStop
                            : AppLocalizations.of(context).teachingIntro,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.pri,
                        side: BorderSide(color: t.line),
                        // 44pt even though the pill is drawn smaller.
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        shape: const StadiumBorder(),
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
  bool? _motionDisabled;

  @override
  void initState() {
    super.initState();
    _speaking = widget.speaking.value;
    _bob = AnimationController(
      vsync: this,
      duration: _speaking ? _talkDuration : _idleDuration,
    );
    widget.speaking.addListener(_onSpeakingChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled == _motionDisabled) return;
    _motionDisabled = disabled;
    if (disabled) {
      _bob
        ..stop()
        ..value = 0.5;
    } else {
      _bob.repeat(reverse: true);
    }
  }

  void _onSpeakingChanged() {
    final speaking = widget.speaking.value;
    if (speaking == _speaking || !mounted) return;
    setState(() => _speaking = speaking);
    _bob.duration = speaking ? _talkDuration : _idleDuration;
    if (_motionDisabled == false) _bob.repeat(reverse: true);
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
    // The bob repeats for as long as the card is on screen, so it gets its own
    // layer: the outer boundary keeps the rest of the card off the per-frame
    // repaint path, and the inner one lets the decoded portrait be composited
    // under a new transform instead of re-rasterised every frame.
    return RepaintBoundary(
      child: AnimatedBuilder(
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
        child: RepaintBoundary(
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
        ),
      ),
    );
  }
}

/// One phrase/grammar row: a Czech form + its English meaning, tap anywhere to
/// hear the Czech. Used by the grammar-table and vocabulary teaching cards.
/// "Not: Dám si káva." / "But: Dám si kávu." — the wrong form is struck
/// through so a glance can't mistake it for the one to learn.
class _MistakeLine extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  final bool struck;

  const _MistakeLine({
    required this.label,
    required this.text,
    required this.color,
    this.struck = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          TextSpan(
            text: text,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: color,
              decoration: struck ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.a11yTapToHear(item.cz),
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: active ? t.violetSoft : t.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: active ? t.violet : t.line),
          boxShadow: active ? null : t.shadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.cz,
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: t.ink,
                            height: 1.25,
                          ),
                        ),
                        if (item.en.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.en,
                            style: TextStyle(
                              fontSize: 14,
                              color: t.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Violet: the phrase surfaces are the review/memory colour,
                  // and the whole row is already the tap target.
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: active ? t.card : t.violetSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.play_arrow, size: 20, color: t.violet),
                  ),
                ],
              ),
            ),
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
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.a11yTapToHear(item.name.isEmpty ? item.symbol : item.name),
      explicitChildNodes: true,
      child: Material(
        color: active ? t.priSoft : t.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTapName,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            // 44pt floor even on the shortest row.
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: active ? t.pri : t.line),
            ),
            child: Row(
              children: [
                // The letter and how it is named, in a tinted tile.
                Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? t.card : t.priSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        item.symbol,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: t.pri,
                          height: 1.0,
                        ),
                      ),
                      if (item.name.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // 12px is the type floor — nothing smaller anywhere.
                            style: TextStyle(fontSize: 12, color: t.priInk),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Respelling, set in mono so it reads as notation rather
                      // than as another Czech word.
                      if (item.sound.isNotEmpty)
                        Text(
                          item.sound,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w700,
                            color: t.muted,
                          ),
                        ),
                      if (item.example.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.exampleEn.isEmpty
                              ? item.example
                              : '${item.example} — ${item.exampleEn}',
                          style: TextStyle(
                            fontSize: 15,
                            color: t.ink,
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
                    icon: const Icon(Icons.volume_up_outlined),
                    color: t.pri,
                    tooltip: AppLocalizations.of(context).audioHearTheWord,
                  ),
              ],
            ),
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
  final String image;
  final String imageLabel;
  final String sentence;
  final String sentenceEn;

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
    required this.image,
    required this.imageLabel,
    required this.sentence,
    required this.sentenceEn,
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
      image: (json['image'] as String? ?? '').trim(),
      imageLabel: (json['image_label'] as String? ?? '').trim(),
      sentence: (json['sentence'] as String? ?? '').trim(),
      sentenceEn: (json['sentence_en'] as String? ?? '').trim(),
    );
  }
}
