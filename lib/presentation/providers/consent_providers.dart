import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/legal/legal_content.dart';
import '../../data/repositories/consent_repository.dart';
import 'database_providers.dart';

final consentRepositoryProvider = Provider<ConsentRepository>(
  (ref) => ConsentRepository(ref.watch(databaseProvider)),
);

final cloudSpeechConsentProvider =
    AsyncNotifierProvider<CloudSpeechConsentNotifier, bool>(
      CloudSpeechConsentNotifier.new,
    );

class CloudSpeechConsentNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref
      .watch(consentRepositoryProvider)
      .isGranted(ConsentPurpose.voiceCloudProcessing);

  Future<void> setGranted(bool granted) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(consentRepositoryProvider)
          .record(
            purpose: ConsentPurpose.voiceCloudProcessing,
            granted: granted,
            noticeVersion: kVoiceCloudConsentVersion,
          );
      return granted;
    });
  }
}
