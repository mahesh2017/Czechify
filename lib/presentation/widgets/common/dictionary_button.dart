import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'lesson_ui.dart';

/// Opens the dictionary. On Learn it sits beside the Map/List toggle and
/// matches it ([compact]); on Review it is one of the header's round buttons.
class DictionaryButton extends StatelessWidget {
  const DictionaryButton({super.key, this.compact = false});

  final bool compact;

  void _open(BuildContext context) => context.push('/dictionary');

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).dictionaryOpen;
    if (!compact) {
      return RoundIconButton(
        key: const ValueKey('open-dictionary'),
        icon: Icons.search_rounded,
        tooltip: label,
        onTap: () => _open(context),
      );
    }
    final t = context.tokens;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        // Drawn at the toggle's height; the 44pt target comes from the
        // opaque hit region around it.
        child: GestureDetector(
          key: const ValueKey('open-dictionary'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _open(context),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: t.elev,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_rounded, size: 20, color: t.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
