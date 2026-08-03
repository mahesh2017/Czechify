import 'package:ceskina_pro/data/services/stt/phoneme_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The acoustic recogniser receives raw recordings of the learner's voice to a
/// self-hosted address supplied at build time. A cleartext host would put
/// biometric audio on the wire in the clear, to a destination the privacy
/// notice does not describe, so it is treated as "not configured" — which is
/// the same well-trodden path as shipping no recogniser at all.
void main() {
  test('an https endpoint is configured', () {
    final recognizer = PhonemeRecognizer(
      baseUrl: 'https://recogniser.example.com',
    );
    expect(recognizer.isConfigured, isTrue);
  });

  test('a trailing slash does not defeat the check', () {
    final recognizer = PhonemeRecognizer(
      baseUrl: 'https://recogniser.example.com///',
    );
    expect(recognizer.isConfigured, isTrue);
  });

  test('a cleartext endpoint is ignored', () {
    // The value previously documented as the example for this dart-define.
    final recognizer = PhonemeRecognizer(baseUrl: 'http://10.0.1.11:8080');
    expect(recognizer.isConfigured, isFalse);
  });

  test('an empty or unusable endpoint is ignored', () {
    expect(PhonemeRecognizer(baseUrl: '').isConfigured, isFalse);
    expect(PhonemeRecognizer(baseUrl: '   ').isConfigured, isFalse);
    expect(PhonemeRecognizer(baseUrl: 'recogniser.example.com').isConfigured,
        isFalse);
  });

  test('an unconfigured recogniser never reaches the network', () async {
    final recognizer = PhonemeRecognizer(baseUrl: 'http://10.0.1.11:8080');
    // Returns null (use transcript scoring) rather than attempting a call.
    expect(await recognizer.recognize('/tmp/does-not-exist.wav'), isNull);
  });
}
