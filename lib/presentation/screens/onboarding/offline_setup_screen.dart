import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/services/audio/offline_audio_prefetch.dart';
import '../../providers/audio_prefetch_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/common/soft_ui.dart';

/// Downloads the first units' audio so the app works with no network.
///
/// Runs once, straight after onboarding, because that is the first moment the
/// chosen voice is known — only that voice is fetched, halving the download.
///
/// Nothing here is a gate. A learner on a bad connection can continue and the
/// app still works: playback streams each clip on demand, exactly as it did
/// before. This screen buys offline capability, it does not grant access.
class OfflineSetupScreen extends ConsumerStatefulWidget {
  const OfflineSetupScreen({super.key});

  /// How many units a new learner can reach offline immediately.
  ///
  /// Which units those are depends on the level they chose — see
  /// [OfflineAudioPrefetch.unitsForLevel].
  static const prefetchUnitCount = 3;

  @override
  ConsumerState<OfflineSetupScreen> createState() => _OfflineSetupScreenState();
}

class _OfflineSetupScreenState extends ConsumerState<OfflineSetupScreen> {
  PrefetchProgress? _progress;
  bool _failedOffline = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final settings = ref.read(settingsProvider);
    final gender = settings.ttsVoiceGender.name;
    final units = await OfflineAudioPrefetch.unitsForLevel(
      settings.startingLevel,
      count: OfflineSetupScreen.prefetchUnitCount,
    );
    final prefetch = ref.read(offlineAudioPrefetchProvider);
    try {
      await for (final progress in prefetch.download(units, gender)) {
        if (!mounted) return;
        setState(() => _progress = progress);
        if (progress.finished) {
          // Every clip failing means no usable connection, not 250 unlucky
          // downloads — worth saying plainly rather than claiming success.
          _failedOffline =
              progress.total > 0 && progress.failed == progress.total;
          _done = true;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _failedOffline = _done = true);
    }
    if (mounted && _done && !_failedOffline) _finish();
  }

  void _finish() {
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progress = _progress;
    final fraction = progress?.fraction ?? 0;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: _failedOffline ? t.amberSoft : t.priSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _failedOffline
                        ? Icons.wifi_off_rounded
                        : Icons.download_rounded,
                    size: 38,
                    color: _failedOffline ? t.amber : t.pri,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: DisplayText(
                  _failedOffline
                      ? 'No connection right now'
                      : 'Getting your first lessons ready',
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _failedOffline
                    ? 'You can start learning straight away — lessons will load '
                        'as you go. Connect to Wi-Fi later and we\'ll save the '
                        'first units to your device so they work offline.'
                    : 'Saving the audio for your first three units so they work '
                        'without an internet connection. This is a few megabytes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15.5, color: t.muted, height: 1.5),
              ),
              const SizedBox(height: 28),
              if (!_failedOffline) ...[
                SoftProgressBar(value: fraction, height: 8),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    progress == null
                        ? 'Starting…'
                        : '${progress.completed} of ${progress.total} clips',
                    style: TextStyle(fontSize: 14, color: t.faint),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              PrimaryButton(
                label: _failedOffline ? 'Start learning' : 'Skip for now',
                onPressed: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
