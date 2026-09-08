import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/legal/legal_content.dart';
import '../../data/repositories/consent_repository.dart';
import 'account_providers.dart';
import 'app_info_providers.dart';
import 'database_providers.dart';

/// The consent log, scoped to whoever is signed in.
///
/// Watching the account rather than reading it once is what makes switching
/// account take effect: consent was device-global, so the next learner
/// inherited the previous one's grant, and the cached provider below kept
/// returning it even after the underlying rows changed.
///
/// The app version is passed through too. It used to fall back to the `1.0.0`
/// default, so every consent record — the evidence that has to say which build
/// showed which wording — was stamped with a version no build ever had.
final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  final account = ref.watch(accountUserProvider).asData?.value;
  final version = ref.watch(appVersionProvider).asData?.value;
  return ConsentRepository(
    ref.watch(databaseProvider),
    accountId: account?.id ?? '',
    appVersion: version ?? '1.0.0',
  );
});

final cloudSpeechConsentProvider =
    AsyncNotifierProvider<CloudSpeechConsentNotifier, bool>(
      CloudSpeechConsentNotifier.new,
    );

class CloudSpeechConsentNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref
      .watch(consentRepositoryProvider)
      .isGranted(
        ConsentPurpose.voiceCloudProcessing,
        // The wording the app would show now. A grant against older wording
        // is not agreement to this one.
        noticeVersion: kVoiceCloudConsentVersion,
      );

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
