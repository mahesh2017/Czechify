import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

/// Record button — hold to record audio.
class RecordButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isRecording;

  const RecordButton({
    super.key,
    required this.onPressed,
    this.isRecording = false,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.isRecording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        onTapDown: (_) => widget.onPressed(),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                widget.isRecording
                    ? context.tokens.red
                    : Theme.of(context).colorScheme.primary,
          ),
          child: Icon(
            widget.isRecording ? Icons.stop : Icons.mic,
            color: context.tokens.onFill,
            size: 28,
          ),
        ),
      ),
    );
  }
}
