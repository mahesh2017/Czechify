import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'lesson_ui.dart';

/// Builds block [index] of a packed deck. [leadsSlide] is false when the block
/// shares a slide with the one before it, so it can drop a heading that block
/// already shows.
typedef SlideBlockBuilder =
    Widget Function(BuildContext context, int index, bool leadsSlide);

/// Learning content on a phone never asks the learner to scroll: what does
/// not fit one screen is split into slides, turned with Back/Next or a swipe.
///
/// Every screen that teaches or asks something is built from this, so the
/// no-scroll fit test (`test/no_scroll_fit_test.dart`) can find each slide and
/// measure it on a small phone.
///
/// A slide is never scaled down to fit — shrinking text defeats the point of
/// splitting. If a slide is still too tall, which the fit test prevents at
/// default text size, it scrolls: someone reading at 200% text needs the words
/// at the size they chose more than they need the rule.
class SlideDeck extends StatefulWidget {
  /// Slides decided by the caller: one question per slide, say.
  const SlideDeck({
    super.key,
    required List<Widget> this.slides,
    required this.doneLabel,
    required this.onDone,
    this.finished = false,
    this.returnKeyAdvances = false,
    this.canAdvance,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 8),
    this.onSlideChanged,
  }) : blockCount = 0,
       blockBuilder = null,
       gap = 0,
       gapBefore = null,
       breakBefore = null,
       chromeOnlyWhenSeveral = false;

  /// Blocks laid on as few slides as they fit, in order: each block is
  /// measured at the phone's width and text size, and a slide takes blocks
  /// until the next would not fit. A block taller than a slide gets one to
  /// itself.
  const SlideDeck.packed({
    super.key,
    required this.blockCount,
    required SlideBlockBuilder this.blockBuilder,
    required this.doneLabel,
    required this.onDone,
    this.finished = false,
    this.returnKeyAdvances = false,
    this.gap = 12,
    this.canAdvance,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 8),
    this.onSlideChanged,
    this.chromeOnlyWhenSeveral = false,
    this.gapBefore,
    this.breakBefore,
  }) : slides = null;

  final List<Widget>? slides;

  final int blockCount;
  final SlideBlockBuilder? blockBuilder;

  /// Between blocks that share a slide.
  final double gap;

  /// The gap above block `index` when it shares a slide with the one before,
  /// where blocks differ: rows of one table sit closer than the parts around
  /// them. [gap] when null.
  final double Function(int index)? gapBefore;

  /// Whether block `index` starts a new slide even when it would fit on the
  /// one before: each question of a reading on its own slide, say.
  final bool Function(int index)? breakBefore;

  /// The last slide's button, which leaves the deck.
  final String doneLabel;

  /// Null when the last slide finishes the step itself — a record button,
  /// say — and needs only Back.
  final VoidCallback? onDone;

  /// True once the deck has done its job — a question answered, say: the
  /// buttons go, so the lesson's own Continue is the one way on, and the
  /// slides can still be swiped to look back over.
  final bool finished;

  /// The slides' text fields move on (or finish) with Return, so while the
  /// keyboard is up the dots and buttons give their room to the slide. On a
  /// small phone a dialogue reply needs it: the keyboard leaves about 200 pt.
  final bool returnKeyAdvances;

  /// Whether the learner may go on from slide `index` — false disables Next
  /// (or the last slide's button) until a question there is answered.
  final bool Function(int index)? canAdvance;

  /// Around each slide's content.
  final EdgeInsets padding;

  /// No dots or buttons while the blocks fit on one slide: for a screen
  /// whose last block carries its own buttons, and which should look like a
  /// plain page whenever it fits. With `onDone: null`.
  final bool chromeOnlyWhenSeveral;
  final ValueChanged<int>? onSlideChanged;

  static const nextKey = ValueKey('slide-deck-next');
  static const backKey = ValueKey('slide-deck-back');
  static const doneKey = ValueKey('slide-deck-done');

  /// Height of the dots row, kept even when there are no dots so a slide's
  /// height does not depend on how many slides there are.
  static const _dotsHeight = 17.0;

  @override
  State<SlideDeck> createState() => SlideDeckState();
}

class SlideDeckState extends State<SlideDeck> {
  final _controller = PageController();
  int _index = 0;

  bool get _packed => widget.slides == null;

  /// Packed mode: which blocks each slide shows, once measured.
  List<List<int>>? _groups;

  /// What [_groups] was measured for; a different width, height or text size
  /// packs again.
  Object? _packedFor;
  Object? _measuring;
  List<GlobalKey> _keys = const [];

  int get index => _index;
  int get length =>
      _packed ? (_groups?.length ?? 0) : widget.slides!.length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Turns to [page]; without the slide when the platform asks for less
  /// motion.
  void goTo(int page) {
    if (!_controller.hasClients) return;
    if (context.motionDisabled) {
      _controller.jumpToPage(page);
      return;
    }
    _controller.animateToPage(
      page,
      duration: AppMotion.content,
      curve: AppMotion.enter,
    );
  }

  /// Turns to the slide showing block [block] (packed decks).
  void showBlock(int block) {
    final page = _slideOf(block);
    if (page != null && page != _index) goTo(page);
  }

  /// The blocks slide [slide] shows (packed decks), once measured.
  List<int> blocksOn(int slide) {
    final groups = _groups;
    if (groups == null || slide < 0 || slide >= groups.length) return const [];
    return groups[slide];
  }

  int? _slideOf(int block) {
    final groups = _groups;
    if (groups == null) return null;
    for (var i = 0; i < groups.length; i++) {
      if (groups[i].contains(block)) return i;
    }
    return null;
  }

  double _gapBefore(int block) => widget.gapBefore?.call(block) ?? widget.gap;

  void _measure(Object key, double height) {
    if (!mounted || _measuring != key) return;
    final heights = [
      for (final k in _keys) k.currentContext?.size?.height ?? 0.0,
    ];
    final room = height - widget.padding.vertical;
    List<List<int>> fill(double capacity) {
      final groups = <List<int>>[];
      var current = <int>[];
      var used = 0.0;
      for (var i = 0; i < heights.length; i++) {
        final need =
            current.isEmpty ? heights[i] : used + _gapBefore(i) + heights[i];
        final breaks = widget.breakBefore?.call(i) ?? false;
        if (current.isNotEmpty && (breaks || need > capacity)) {
          groups.add(current);
          current = [i];
          used = heights[i];
        } else {
          current.add(i);
          used = need;
        }
      }
      if (current.isNotEmpty) groups.add(current);
      return groups;
    }

    // As few slides as fit, then as even as those slides allow: filling
    // each to the brim can leave one line alone on the last.
    // A block taller than a slide already has one to itself; balancing
    // around it would let the others run past the bottom.
    final fewest = fill(room).length;
    var low = heights.fold(0.0, (a, b) => a > b ? a : b);
    var high = room;
    for (var i = 0; i < 24 && low <= room && high - low > 1; i++) {
      final mid = (low + high) / 2;
      if (fill(mid).length <= fewest) {
        high = mid;
      } else {
        low = mid;
      }
    }
    final groups = fill(high);

    // Stay with what the learner was reading when the deck packs again.
    final firstShown = _groups?[_index].first ?? 0;
    setState(() {
      _groups = groups;
      _packedFor = key;
      _measuring = null;
      _keys = const [];
    });
    final page = _slideOf(firstShown) ?? 0;
    if (page != _index) {
      _index = page;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) _controller.jumpToPage(page);
      });
    }
  }

  Widget _measurer(BoxConstraints box, Object key) {
    if (_measuring != key) {
      _measuring = key;
      _keys = List.generate(widget.blockCount, (_) => GlobalKey());
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _measure(key, box.maxHeight),
      );
    }
    final width = box.maxWidth - widget.padding.horizontal;
    return Offstage(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minWidth: width,
        maxWidth: width,
        minHeight: 0,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.blockCount; i++)
              KeyedSubtree(
                key: _keys[i],
                child: widget.blockBuilder!(context, i, true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _packedSlide(BuildContext context, List<int> blocks) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (n, block) in blocks.indexed) ...[
        if (n > 0) SizedBox(height: _gapBefore(block)),
        widget.blockBuilder!(context, block, n == 0),
      ],
    ],
  );

  Widget _pages(BuildContext context) {
    final slides =
        _packed
            ? [for (final g in _groups!) _packedSlide(context, g)]
            : widget.slides!;
    return PageView(
      controller: _controller,
      onPageChanged: (i) {
        setState(() => _index = i);
        widget.onSlideChanged?.call(i);
      },
      children: [
        for (final slide in slides)
          slide is FillSlide
              ? Padding(padding: widget.padding, child: slide.child)
              : SingleChildScrollView(padding: widget.padding, child: slide),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = length;
    final last = _index >= count - 1;
    final canGo = widget.canAdvance?.call(_index) ?? true;
    final textScaler = MediaQuery.textScalerOf(context);
    return KeyboardUpBuilder(
      builder: (context, keyboardUp) => _layout(
        context,
        keyboardHidesButtons: widget.returnKeyAdvances && keyboardUp,
        count: count,
        last: last,
        canGo: canGo,
        textScaler: textScaler,
      ),
    );
  }

  Widget _layout(
    BuildContext context, {
    required bool keyboardHidesButtons,
    required int count,
    required bool last,
    required bool canGo,
    required TextScaler textScaler,
  }) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final chrome = !(widget.chromeOnlyWhenSeveral && count <= 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child:
              _packed
                  ? LayoutBuilder(
                    builder: (context, box) {
                      final key = (
                        box.maxWidth,
                        box.maxHeight,
                        textScaler,
                        widget.blockCount,
                      );
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_groups != null) _pages(context),
                          if (_packedFor != key) _measurer(box, key),
                        ],
                      );
                    },
                  )
                  : _pages(context),
        ),
        if (chrome && !keyboardHidesButtons)
        SizedBox(
          height: SlideDeck._dotsHeight,
          child:
              count > 1
                  ? Semantics(
                    label: l10n.slidePosition(_index + 1, count),
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < count; i++)
                            AnimatedContainer(
                              duration: context.motionDuration(
                                AppMotion.selection,
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _index ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _index ? t.pri : t.line,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                  : null,
        ),
        if (chrome && !widget.finished && !keyboardHidesButtons)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
              children: [
                if (_index > 0) ...[
                  OutlinedButton(
                    key: SlideDeck.backKey,
                    onPressed: () => goTo(_index - 1),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(96, 52),
                    ),
                    child: Text(l10n.slideBack),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child:
                      !last
                          ? KeyCta(
                            key: SlideDeck.nextKey,
                            label: l10n.slideNext,
                            onPressed:
                                canGo ? () => goTo(_index + 1) : null,
                          )
                          : count == 0 || widget.onDone == null
                          // Same height as a button (KeyCta is 58), so the
                          // slide above keeps its size. At 52 a packed deck
                          // measured its first pass with 6 pt that are not
                          // there, and showed a slide 4 pt too tall (28201)
                          // for a frame before packing again.
                          ? const SizedBox(height: 58)
                          : KeyCta(
                            key: SlideDeck.doneKey,
                            label: widget.doneLabel,
                            onPressed: canGo ? widget.onDone : null,
                          ),
                ),
              ],
          ),
        ),
      ],
    );
  }
}

/// A slide that is given the page's exact height instead of scrolling, for a
/// screen with one part that should take whatever room is left — the page a
/// learner writes on, which shrinks when the keyboard comes up. Its content
/// has to lay out in that height (an `Expanded` for the part that gives way);
/// if it cannot, that is an overflow the fit test reports.
class FillSlide extends StatelessWidget {
  const FillSlide({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Builds with whether the on-screen keyboard is up, and again when that
/// changes.
///
/// Inside a `Scaffold` body the keyboard cannot be read from `MediaQuery`: the
/// scaffold shrinks the body to make room and then removes the keyboard from
/// the body's `MediaQuery`, so `viewInsets` there is always zero. This reads
/// the window instead.
class KeyboardUpBuilder extends StatefulWidget {
  const KeyboardUpBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool keyboardUp) builder;

  @override
  State<KeyboardUpBuilder> createState() => _KeyboardUpBuilderState();
}

class _KeyboardUpBuilderState extends State<KeyboardUpBuilder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, View.of(context).viewInsets.bottom > 0);
}
