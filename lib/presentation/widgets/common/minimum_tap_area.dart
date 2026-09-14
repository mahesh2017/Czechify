import 'package:flutter/widgets.dart';

/// Reserves an Android-sized hit area without stretching the painted child.
/// Place inside the gesture handler so the transparent space is tappable too.
class MinimumTapArea extends StatelessWidget {
  const MinimumTapArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    child: Center(widthFactor: 1, heightFactor: 1, child: child),
  );
}

/// Gives a compact input an invisible focus target and one merged semantic node.
class MinimumInputTapArea extends StatefulWidget {
  const MinimumInputTapArea({
    super.key,
    required this.builder,
    this.focusNode,
    this.label,
    this.enabled = true,
  });
  final Widget Function(FocusNode) builder;
  final FocusNode? focusNode;
  final String? label;
  final bool enabled;

  @override
  State<MinimumInputTapArea> createState() => _MinimumInputTapAreaState();
}

class _MinimumInputTapAreaState extends State<MinimumInputTapArea> {
  late final _ownedFocus = FocusNode();
  @override
  void dispose() {
    _ownedFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focus = widget.focusNode ?? _ownedFocus;
    return MergeSemantics(
      child: Semantics(
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? focus.requestFocus : null,
          child: MinimumTapArea(child: widget.builder(focus)),
        ),
      ),
    );
  }
}
