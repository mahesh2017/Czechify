import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/audio/offline_audio_prefetch.dart';
import '../../domain/entities/enums.dart';
import 'course_admission_providers.dart';
import 'monetization_providers.dart';
import 'sync_providers.dart';

/// Pre-downloads unit audio into the cache [CzechTts] already plays from.
final offlineAudioPrefetchProvider = Provider<OfflineAudioPrefetch>((ref) {
  // Held open for the read: an unlistened provider pauses rather than
  // rebuilding after invalidation, and a bare read of its future would then
  // never complete, leaving a download stuck before its first clip.
  Future<Set<int>> accessibleNow() async {
    final subscription = ref.listen(
      commerciallyAccessibleUnitIdsProvider.future,
      (_, _) {},
    );
    try {
      return await subscription.read();
    } finally {
      subscription.close();
    }
  }

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
    accountContext: () => (
      ref.read(backendServiceProvider).userId,
      ref.read(lessonAccountTransitionProvider),
    ),
    refreshAccess: () async {
      ref.invalidate(monetizationLoadProvider);
      await accessibleNow();
    },
    accessibleUnits: accessibleNow,
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

/// Units whose audio is downloaded ahead for [level]: the level's first few,
/// less any the account cannot open under the course paywall. Only new
/// downloads are held back; clips already on the device stay and still play.
/// While the paywall is off every unit is accessible, as before.
final offlineAudioUnitsProvider = FutureProvider.family<List<int>, CEFRLevel>((
  ref,
  level,
) async {
  final units = await OfflineAudioPrefetch.unitsForLevel(
    level,
    count: OfflineAudioPrefetch.setupUnitCount,
  );
  final accessible = await ref.watch(
    commerciallyAccessibleUnitIdsProvider.future,
  );
  return [
    for (final id in units)
      if (accessible.contains(id)) id,
  ];
});
