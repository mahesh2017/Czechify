import 'package:ceskina_pro/domain/repositories/speech_ports.dart';
import 'package:ceskina_pro/presentation/providers/pronunciation_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone with no Czech language pack cannot check pronunciation on device.
/// That is a dead end unless the app says what to do about it — and the thing
/// to do is a switch it owns, not a trip into the phone's system settings.
void main() {
  group('an error the app can fix carries that fact', () {
    test('a missing Czech recogniser is flagged as cloud-fixable', () {
      const failure = SpeechServiceException(
        'Your phone cannot recognise Czech speech, so this cannot be checked '
        'on the device.',
        cloudSpeechWouldFix: true,
      );
      expect(failure.cloudSpeechWouldFix, isTrue);
    });

    test('an ordinary service failure is not', () {
      // A spent allowance or an unreachable proxy is not fixed by consenting
      // to something already consented to; offering it would be noise.
      const failure = SpeechServiceException('Out of transcriptions today.',
          isQuotaExhausted: true);
      expect(failure.cloudSpeechWouldFix, isFalse);
    });
  });

  group('the offer lives and dies with the error', () {
    test('state carries the offer alongside the message', () {
      const state = PronunciationState(
        expectedText: 'To je káva',
        error: 'Your phone cannot recognise Czech speech.',
        errorIsServiceSide: true,
        errorCloudSpeechWouldFix: true,
      );
      expect(state.errorCloudSpeechWouldFix, isTrue);
    });

    test('recording again clears the offer with the error', () {
      const failed = PronunciationState(
        expectedText: 'To je káva',
        error: 'Your phone cannot recognise Czech speech.',
        errorIsServiceSide: true,
        errorCloudSpeechWouldFix: true,
      );

      final retrying = failed.copyWith(isRecording: true);

      // An offer belonging to a failure the learner has moved past would sit
      // under a live recording suggesting they fix something that is not
      // currently wrong.
      expect(retrying.error, isNull);
      expect(retrying.errorCloudSpeechWouldFix, isFalse);
      expect(retrying.errorIsServiceSide, isFalse);
    });

    test('a default state offers nothing', () {
      const state = PronunciationState(expectedText: 'To je káva');
      expect(state.errorCloudSpeechWouldFix, isFalse);
      expect(state.error, isNull);
    });
  });
}
