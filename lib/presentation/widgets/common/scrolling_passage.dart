import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';

/// A long reading text that scrolls inside its own box, so the page around it
/// never does (Mahesh, 28 Sep 2026: "just that text box where text is … there
/// should be clear indication that text box is scrollable").
///
/// It hugs a text that fits and shows nothing extra. A text that does not
/// fit shows three cues, all gone once the end is reached: a scrollbar that
/// stays visible, a fade over the last lines, and a "scroll for more" label.
///
/// The no-scroll fit test lets this box scroll, but not shrink below
/// [minHeight]: a sliver of text is not a place to read.
class ScrollingPassage extends StatefulWidget {
  const ScrollingPassage({super.key, required this.child});

  final Widget child;

  /// About five lines of reading text.
  static const minHeight = 140.0;

  @override
  State<ScrollingPassage> createState() => _ScrollingPassageState();
}

class _ScrollingPassageState extends State<ScrollingPassage> {
  static const _fadeExtent = 36.0;

  final _controller = ScrollController();
  bool _more = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _update(ScrollMetrics metrics) {
    final more = metrics.maxScrollExtent - metrics.pixels > 1;
    if (more != _more) {
      // Layout is still running when the first metrics arrive, so defer.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _more = more);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // The fade and the label are always in the tree, only shown or hidden:
    // a scroll view whose parent changes loses its position.
    return Stack(
      children: [
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback:
              (bounds) => LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  _more ? Colors.transparent : Colors.white,
                  Colors.white,
                ],
                stops: [0, _fadeExtent / bounds.height.clamp(1, double.infinity)],
              ).createShader(bounds),
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) => _update(notification.metrics),
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (notification) => _update(notification.metrics),
              child: Scrollbar(
                controller: _controller,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _controller,
                  // Room for the scrollbar, and for the last line to clear
                  // the label.
                  padding: EdgeInsets.only(right: 12, bottom: _more ? 36 : 0),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _more ? 1 : 0,
              duration: context.motionDuration(AppMotion.selection),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: t.priSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: t.priInk,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context).readingScrollForMore,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.priInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
