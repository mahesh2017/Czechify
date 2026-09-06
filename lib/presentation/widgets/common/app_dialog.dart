import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import 'soft_ui.dart';

/// The house dialog.
///
/// Every dialog in the app was a bare `AlertDialog`, which meant they were the
/// one surface the redesign never reached: stock Material sizing and a stock
/// action bar, sitting inside an app whose own language is soft tinted tiles,
/// display type and full-width keys. Ten of them, each assembled by hand, had
/// drifted apart from one another as well — some carried an icon, most did
/// not; a destructive action was styled as an error `TextButton` in one place
/// and as a primary `FilledButton` in another.
///
/// The layout is not only a matter of looks. `AlertDialog` lays its actions
/// out in an [OverflowBar], which puts them in a row and only wraps once they
/// no longer fit. "Not now" beside "Update" already wrapped at 393dp — the
/// most common Android width — and the wrapped form is worse than either
/// arrangement: a small right-aligned link stranded above a full-bleed button.
/// Czech is longer than English ("Teď ne" / "Aktualizovat", "Otevřít Google
/// Play") and a learner at 200% text has less room again, so the row was never
/// going to hold. Stacking the actions removes the failure mode rather than
/// tuning it: it cannot overflow at any width, in any locale, at any text
/// scale.
enum AppDialogTone {
  primary,
  danger,
  warning;

  Color tint(AppTokens t) => switch (this) {
    AppDialogTone.primary => t.priSoft,
    AppDialogTone.danger => t.redSoft,
    AppDialogTone.warning => t.amberSoft,
  };

  Color ink(AppTokens t) => switch (this) {
    AppDialogTone.primary => t.priInk,
    AppDialogTone.danger => t.redInk,
    AppDialogTone.warning => t.amberInk,
  };

  Color fill(AppTokens t) => switch (this) {
    AppDialogTone.primary => t.priFill,
    AppDialogTone.danger => t.red,
    AppDialogTone.warning => t.priFill,
  };
}

/// A dialog in Czechify's own language: tinted icon tile, display title,
/// centred body, and actions stacked full-width with the primary one on top.
///
/// [confirmLabel]/[onConfirm] render the filled key; [dismissLabel]/[onDismiss]
/// the quieter one below it. Either may be omitted — a progress dialog has no
/// confirm, an acknowledgement has no dismiss. [content] is an optional slot
/// under the message for a progress bar or a set of fields.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.tone = AppDialogTone.primary,
    this.content,
    this.confirmLabel,
    this.onConfirm,
    this.confirmIcon,
    this.dismissLabel,
    this.onDismiss,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final AppDialogTone tone;

  /// Optional slot between the message and the actions.
  final Widget? content;

  final String? confirmLabel;
  final VoidCallback? onConfirm;
  final IconData? confirmIcon;

  final String? dismissLabel;
  final VoidCallback? onDismiss;

  /// Stable handles for the three actions.
  ///
  /// A dialog's title and its confirm label are often the same words — the
  /// sign-in prompt is titled "Sign in" and confirms with "Sign in" — so
  /// `find.text` cannot address one without matching the other, and matching
  /// on the widget type re-couples every test to whatever renders the key.
  static const confirmKey = Key('app-dialog-confirm');
  static const dismissKey = Key('app-dialog-dismiss');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dialog(
      backgroundColor: t.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        // Wide enough for a comfortable measure on a phone, capped so the
        // dialog does not stretch into a banner on a tablet.
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Only the reading matter scrolls. Putting the actions inside the
            // scroll view instead pushed them past the bottom of a short
            // screen whenever the message was long — the cloud-speech consent
            // notice is six lines of GDPR wording — and a learner who cannot
            // reach "Allow" has been handed a dialog with no way out but the
            // barrier. Flexible lets this shrink to whatever is left after the
            // actions have taken their height, and no further.
            Flexible(
              child: _FadingScroll(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (icon != null) ...[
                      Align(
                        child: IconTile(
                          icon: icon!,
                          tint: tone.tint(t),
                          fg: tone.ink(t),
                          size: 60,
                          radius: 20,
                          iconSize: 28,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                        color: t.ink,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: t.muted,
                        ),
                      ),
                    ],
                    if (content != null) ...[
                      const SizedBox(height: 18),
                      content!,
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (confirmLabel != null)
                    _DialogKey(
                      key: confirmKey,
                      label: confirmLabel!,
                      icon: confirmIcon,
                      onPressed: onConfirm,
                      background: tone.fill(t),
                      foreground: t.onFill,
                    ),
                  if (confirmLabel != null && dismissLabel != null)
                    const SizedBox(height: 8),
                  if (dismissLabel != null)
                    _DialogKey(
                      key: dismissKey,
                      label: dismissLabel!,
                      onPressed: onDismiss,
                      background: Colors.transparent,
                      foreground: t.muted,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One full-width action row.
///
/// A plain [FilledButton]/[TextButton] pair would inherit the app's global
/// button theme, which is tuned for the 58dp key on a lesson screen. These sit
/// inside a dialog, so they are a size down and share one silhouette.
class _DialogKey extends StatelessWidget {
  const _DialogKey({
    super.key,
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final filled = background != Colors.transparent;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 19, color: foreground),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A scroll view that fades its bottom edge while there is more to read.
///
/// Pinning the actions fixed reachability but not discoverability: at 200%
/// text the message ends on a half-height line flush against the buttons,
/// which reads as text the dialog has cut off rather than text the learner can
/// scroll to. A learner who has turned the type size up is exactly the one who
/// cannot afford to guess. The fade appears only when the content actually
/// overflows and disappears once the end is reached, so a dialog that fits —
/// which is nearly all of them — is pixel-identical to one without it.
class _FadingScroll extends StatefulWidget {
  const _FadingScroll({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  State<_FadingScroll> createState() => _FadingScrollState();
}

class _FadingScrollState extends State<_FadingScroll> {
  static const _fadeExtent = 28.0;

  bool _more = false;

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
    final scroller = NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) => _update(notification.metrics),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) => _update(notification.metrics),
        child: SingleChildScrollView(
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
    if (!_more) return scroller;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback:
          (bounds) => LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: const [Colors.transparent, Colors.white],
            stops: [0, _fadeExtent / bounds.height],
          ).createShader(bounds),
      child: scroller,
    );
  }
}
