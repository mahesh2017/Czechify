import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../providers/tts_providers.dart';

/// Tells the learner when the app is running on a substitute, and why.
///
/// Three times during testing a perfectly healthy app was reported as broken —
/// "the male voice doesn't work", "pronunciation failed" — because it quietly
/// swapped in a worse path and said nothing. Each was a missing download or a
/// rate limit, not a fault. Someone who can read server logs eventually works
/// that out; a learner just concludes the app is unreliable.
///
/// So this is written as information, never as an error: no red, no warning
/// icon, no apology. It states the situation and what would fix it.
class DegradedModeBanner extends ConsumerWidget {
  const DegradedModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(czechTtsProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: tts.usingFallbackVoice,
      builder: (context, isFallback, _) {
        if (!isFallback) return const SizedBox.shrink();
        return const _Notice(
          icon: Icons.cloud_off_rounded,
          message:
              'Offline — using your device\'s voice. Connect to hear the '
              'recorded Czech voice.',
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        // Amber, not red: nothing has failed, and colouring it like an error
        // would recreate the very impression this exists to prevent.
        color: t.amberSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: t.amber),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, height: 1.35, color: t.amber),
            ),
          ),
        ],
      ),
    );
  }
}
