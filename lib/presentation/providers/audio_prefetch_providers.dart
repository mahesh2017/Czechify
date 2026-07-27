import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/audio/offline_audio_prefetch.dart';

/// Pre-downloads unit audio into the cache [CzechTts] already plays from.
final offlineAudioPrefetchProvider = Provider<OfflineAudioPrefetch>((ref) {
  return OfflineAudioPrefetch(
    Dio(
      BaseOptions(
        // Short connect timeout: on a dead connection this runs a few hundred
        // times, and waiting 10s each would leave the setup screen apparently
        // frozen for an hour rather than failing fast and saying so.
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 30),
      ),
    ),
  );
});

/// Whether the voice a learner is switching to already has audio on device.
///
/// Only one voice is downloaded at setup, so switching while offline would
/// otherwise produce silence with no explanation.
final voiceAudioReadyProvider =
    FutureProvider.family<bool, ({List<int> units, String gender})>((
      ref,
      args,
    ) async {
      final prefetch = ref.watch(offlineAudioPrefetchProvider);
      final missing = await prefetch.missingFiles(args.units, args.gender);
      return missing.isEmpty;
    });
