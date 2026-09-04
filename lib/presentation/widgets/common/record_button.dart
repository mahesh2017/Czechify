import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'motion_widgets.dart';

/// The mic control. Tap to start, tap again to stop.
///
/// While recording it turns coral and throws a slow expanding ring, which is
/// the app's only "live" state and needs to be unmistakable at a glance.
/// Under reduced motion the ring is dropped and the coral fill carries it, so
/// the recording state is never signalled by movement alone.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.onPressed,
    this.isRecording = false,
    this.size = 76,
  });

  final VoidCallback? onPressed;
  final bool isRecording;
  final double size;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didUpdateWidget(covariant RecordButton old) {
    super.didUpdateWidget(old);
    _syncRing();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRing();
  }

  void _syncRing() {
    final shouldRun =
        widget.isRecording && !MediaQuery.disableAnimationsOf(context);
    if (shouldRun && !_ring.isAnimating) {
      _ring.repeat();
    } else if (!shouldRun && _ring.isAnimating) {
      _ring.stop();
      _ring.value = 0;
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hue = widget.isRecording ? t.red : t.priFill;
    // The ring grows outside the button, so the box has to leave room for it.
    final extent = widget.size * 1.9;

    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label:
          widget.isRecording
              ? (l10n?.stopRecording ?? 'Stop recording')
              : (l10n?.startRecording ?? 'Start recording'),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: SizedBox(
          width: extent,
          height: extent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isRecording)
                AnimatedBuilder(
                  animation: _ring,
                  builder: (context, _) {
                    final v = _ring.value;
                    return IgnorePointer(
                      child: Opacity(
                        opacity: (0.55 * (1 - v)).clamp(0.0, 1.0),
                        child: Container(
                          width: widget.size * (0.9 + v),
                          height: widget.size * (0.9 + v),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: t.red, width: 2),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              AnimatedContainer(
                duration: context.motionDuration(AppMotion.selection),
                curve: AppMotion.enter,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hue,
                  boxShadow: [
                    BoxShadow(
                      color: hue.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: MotionSwap(
                  duration: AppMotion.selection,
                  offset: Offset.zero,
                  child: Icon(
                    widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    key: ValueKey(widget.isRecording),
                    color: t.onFill,
                    size: widget.size * 0.44,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
