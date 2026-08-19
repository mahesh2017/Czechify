import '../../data/services/stt/whisper_service.dart' show WhisperResult;

/// A cloud speech failure with a message fit to show a learner.
///
/// Exists so the reason a recording could not be scored survives the trip from
/// the transcription client to the UI. It previously did not: the server's
/// carefully worded "Daily pronunciation check limit reached" was swallowed and
/// replaced with a fabricated 0% score, which reads as "you pronounced this
/// badly" rather than "we could not check it".
class SpeechServiceException implements Exception {
  const SpeechServiceException(
    this.message, {
    this.isQuotaExhausted = false,
    this.cloudSpeechWouldFix = false,
  });

  /// Shown to the learner as-is, so it must be plain language.
  final String message;

  /// True when retrying now cannot help — the allowance is spent.
  final bool isQuotaExhausted;

  /// True when turning on cloud speech would resolve this outright.
  ///
  /// Set when the phone has no Czech recogniser. The learner is not being told
  /// about a fault to wait out — there is a switch that fixes it — so the UI
  /// can offer that switch instead of leaving them to work it out from prose.
  final bool cloudSpeechWouldFix;

  @override
  String toString() => message;
}

/// Cloud (server-side) transcription capability.
///
/// [isAvailable] reflects authenticated backend capability — an actual
/// usable session — not merely the presence of a client object. Callers must
/// still treat [transcribe] as fallible: a linked backend without the
/// `whisper-proxy` function deployed will throw, and the caller degrades to a
/// live on-device transcriber rather than hard-failing.
abstract class CloudTranscriber {
  bool get isAvailable;

  Future<WhisperResult> transcribe({
    required String audioPath,
    String language,
    String? prompt,
  });
}

/// Records audio to a file for cloud transcription.
abstract class AudioRecorderPort {
  bool get isRecording;
  Future<String> start();
  Future<String> stop();
  Future<void> cleanup();

  /// Record until the speaker falls silent (voice-activity auto-stop), the
  /// [maxDuration] cap is reached, or [stopSignal] fires (manual stop) —
  /// whichever comes first — then stop and return the recorded file path.
  /// The captured audio is always returned so the caller can transcribe it,
  /// regardless of which condition ended the recording.
  Future<String> recordUntilSilence({
    Duration silenceTimeout,
    Duration maxDuration,
    Future<void>? stopSignal,
  });
}

/// On-device live transcriber used as the degraded fallback.
abstract class LiveTranscriber {
  Future<String> listenFor({Duration timeout});
  Future<void> stop();

  /// Whether this transcriber can recognise Czech at all.
  ///
  /// The OS recogniser only has the languages the phone has installed, and
  /// Czech is not among the defaults on most devices sold outside Czechia.
  /// Asked before listening because the failure is silent otherwise: with no
  /// Czech locale the platform listens in the phone's default language, hands
  /// back an English-shaped transcription of Czech speech, and the scorer
  /// dutifully reports that a correctly said phrase was mispronounced.
  ///
  /// Defaults to true so existing implementations keep working; only the
  /// platform recogniser has a language inventory to be missing from.
  Future<bool> supportsCzech() async => true;
}
