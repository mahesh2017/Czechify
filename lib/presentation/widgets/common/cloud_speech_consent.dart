import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/consent_providers.dart';
import 'app_dialog.dart';

/// Ask for cloud speech consent, and record it if given.
///
/// Lives in one place because it is a consent record, not a prompt. The same
/// words have to appear wherever it is asked — Settings, or the moment a
/// learner finds their phone cannot recognise Czech — or two people have
/// agreed to two different things and the record says they agreed to the same
/// one.
///
/// Returns true when consent was granted just now.
Future<bool> requestCloudSpeechConsent(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final accepted = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AppDialog(
          icon: Icons.cloud_outlined,
          title: l10n.cloudSpeechTitle,
          message: l10n.cloudSpeechBody,
          confirmLabel: l10n.cloudSpeechAllow,
          onConfirm: () => Navigator.pop(ctx, true),
          dismissLabel: l10n.settingsNotNow,
          onDismiss: () => Navigator.pop(ctx, false),
        ),
  );

  if (accepted != true) return false;

  await ref.read(cloudSpeechConsentProvider.notifier).setGranted(true);
  return true;
}
