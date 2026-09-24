import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'lesson_ui.dart';

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
  const SlideDeck({
    super.key,
    required this.slides,
    required this.doneLabel,
    required this.onDone,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 8),
    this.onSlideChanged,
  });

  final List<Widget> slides;

  /// The last slide's button, which leaves the deck.
  final String doneLabel;
  final VoidCallback onDone;

  /// Around each slide's content.
  final EdgeInsets padding;
  final ValueChanged<int>? onSlideChanged;

  static const nextKey = ValueKey('slide-deck-next');
  static const backKey = ValueKey('slide-deck-back');

  @override
  State<SlideDeck> createState() => SlideDeckState();
}

class SlideDeckState extends State<SlideDeck> {
  final _controller = PageController();
  int _index = 0;

  int get index => _index;
  int get length => widget.slides.length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Turns to [page]; without the slide when the platform asks for less
  /// motion.
  void goTo(int page) {
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final count = widget.slides.length;
    final last = _index >= count - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onSlideChanged?.call(i);
            },
            children: [
              for (final slide in widget.slides)
                SingleChildScrollView(padding: widget.padding, child: slide),
            ],
          ),
        ),
        if (count > 1)
          Semantics(
            label: l10n.slidePosition(_index + 1, count),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < count; i++)
                    AnimatedContainer(
                      duration: context.motionDuration(AppMotion.selection),
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
          ),
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
                child: KeyCta(
                  key: last ? null : SlideDeck.nextKey,
                  label: last ? widget.doneLabel : l10n.slideNext,
                  onPressed: last ? widget.onDone : () => goTo(_index + 1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
