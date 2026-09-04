import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/consent_providers.dart';

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
  final accepted = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          icon: const Icon(Icons.cloud_outlined),
          title: const Text('Allow cloud speech?'),
          content: const Text(
            'Your pronunciation recording will be sent through Czechify to '
            'OpenAI in the United States for transcription. Czechify does not '
            'store the recording after the transcript is returned. OpenAI may '
            'retain API data for abuse monitoring for up to 30 days. This is '
            'optional, can be switched off at any time, and is available only '
            'if you are at least 16.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Allow cloud speech'),
            ),
          ],
        ),
  );
  if (accepted != true) return false;

  await ref.read(cloudSpeechConsentProvider.notifier).setGranted(true);
  return true;
}
