import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../common/soft_ui.dart';

Future<void> showStreakStateSheet(
  BuildContext context, {
  required int streak,
  required bool freezeAvailable,
}) {
  final active = streak > 0;
  final protected = active && !freezeAvailable;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final t = context.tokens;
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                protected
                    ? Icons.ac_unit
                    : active
                    ? Icons.local_fire_department
                    : Icons.local_fire_department_outlined,
                size: 52,
                color: protected ? t.priInk : (active ? t.amberInk : t.faint),
              ),
              const SizedBox(height: 12),
              DisplayText(
                protected
                    ? l10n.streakProtected
                    : active
                    ? l10n.streakDays(streak)
                    : l10n.streakStartNew,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                protected
                    ? l10n.streakProtectedBody(streak)
                    : active
                    ? l10n.streakActiveBody
                    : l10n.streakEndedBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.45, color: t.muted),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    active ? l10n.streakKeepLearning : l10n.streakBeginAgain,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
