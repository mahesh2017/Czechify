import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// One field inside a [TextPromptDialog].
class TextPromptField {
  const TextPromptField({
    required this.label,
    this.initialValue = '',
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final String initialValue;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
}

/// Asks for one or more short strings, returning them in field order, or null
/// if the dialog was cancelled or dismissed.
///
/// Exists because the obvious way to write this is wrong:
///
/// ```dart
/// final controller = TextEditingController();
/// final result = await showDialog(...);
/// controller.dispose();          // ← too early
/// ```
///
/// `showDialog`'s future completes the moment the route is popped, not when
/// its exit animation finishes — the `TextField` is still mounted and still
/// rebuilding for another frame or two. Disposing the controller on the next
/// line means that rebuild re-subscribes to a dead [ChangeNotifier], which
/// throws "A TextEditingController was used after being disposed" and leaves
/// the element tree half torn down (surfacing as a `_dependents.isEmpty`
/// assertion). Letting the dialog own its controllers ties their lifetime to
/// the route instead, so they outlive the animation.
Future<List<String>?> showTextPromptDialog({
  required BuildContext context,
  required String title,
  required List<TextPromptField> fields,
  required String confirmLabel,
  bool barrierDismissible = true,
}) {
  assert(fields.isNotEmpty, 'A prompt needs at least one field');
  return showDialog<List<String>>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder:
        (_) => TextPromptDialog(
          title: title,
          fields: fields,
          confirmLabel: confirmLabel,
        ),
  );
}

/// The dialog behind [showTextPromptDialog]. Stateful so that it, and not the
/// caller, owns the [TextEditingController]s.
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.confirmLabel,
  });

  final String title;
  final List<TextPromptField> fields;
  final String confirmLabel;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final List<TextEditingController> _controllers = [
    for (final field in widget.fields)
      TextEditingController(text: field.initialValue),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() =>
      Navigator.pop(context, [for (final c in _controllers) c.text]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, field) in widget.fields.indexed)
            TextField(
              controller: _controllers[index],
              autofocus: index == 0,
              obscureText: field.obscureText,
              keyboardType: field.keyboardType,
              textCapitalization: field.textCapitalization,
              // The last field submits; earlier ones move on.
              textInputAction:
                  index == widget.fields.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
              onSubmitted:
                  index == widget.fields.length - 1 ? (_) => _submit() : null,
              decoration: InputDecoration(
                labelText: field.label,
                hintText: field.hintText,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
