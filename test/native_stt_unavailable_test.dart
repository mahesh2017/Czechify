import 'package:czechify/domain/repositories/speech_ports.dart';
import 'package:czechify/presentation/providers/stt_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

/// What happens when the recogniser will not start at all.
///
/// Every other speaking test in this suite substitutes a fake
/// [LiveTranscriber], so the real [NativeSttService] and the order of its own
/// guards were never exercised. That is how the empty-string return survived
/// the fix that was supposed to remove it: a Czech-locale refusal was added
/// *after* the `if (!_initialized) return ''` it was meant to replace, so a
/// denied microphone still produced a transcript of nothing, which the lesson
/// task scored as a wrong answer and the exam recorded as a zero.
///
/// These drive the actual service and fake only the platform beneath it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => SpeechToTextPlatform.instance = _RefusingPlatform());

  test('a denied microphone is a failure, not an empty answer', () async {
    SpeechToTextPlatform.instance = _RefusingPlatform(
      error: 'error_permission',
    );

    await expectLater(
      NativeSttService().listenFor(),
      throwsA(
        isA<SpeechServiceException>()
            .having((e) => e.message, 'message', contains('permission'))
            // Cloud speech needs the microphone too, so offering it here
            // would send the learner round a loop that cannot help.
            .having((e) => e.cloudSpeechWouldFix, 'cloudSpeechWouldFix', false),
      ),
    );
  });

  test('a phone with no recogniser says so, and points somewhere', () async {
    SpeechToTextPlatform.instance = _RefusingPlatform();

    await expectLater(
      NativeSttService().listenFor(),
      throwsA(
        isA<SpeechServiceException>()
            .having((e) => e.message, 'message', contains('not available'))
            .having((e) => e.cloudSpeechWouldFix, 'cloudSpeechWouldFix', true),
      ),
    );
  });

  test('dictation refuses too, rather than returning silence', () async {
    // `requireCzech: false` opts out of the *language* check so chat dictation
    // keeps working on a phone with no Czech pack. It does not mean a
    // recogniser that cannot run should quietly hand back nothing.
    SpeechToTextPlatform.instance = _RefusingPlatform();

    await expectLater(
      NativeSttService().listenFor(requireCzech: false),
      throwsA(isA<SpeechServiceException>()),
    );
  });

  test('an unavailable recogniser still reports itself unavailable', () async {
    SpeechToTextPlatform.instance = _RefusingPlatform();
    final service = NativeSttService();

    expect(await service.isAvailable(), isFalse);
    expect(await service.supportsCzech(), isFalse);
  });
}

/// The platform layer refusing to initialize — a denied permission, or a
/// device with no speech recogniser installed. `initialize()` reports only
/// false; the reason arrives through the error callback first.
class _RefusingPlatform extends SpeechToTextPlatform {
  _RefusingPlatform({this.error});

  final String? error;

  @override
  Future<bool> initialize({
    dynamic debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async {
    if (error != null) onError?.call(_errorJson(error!));
    return false;
  }

  @override
  Future<bool> hasPermission() async => false;

  /// The plugin hands errors across as JSON, and `SpeechToText` decodes them
  /// before the app's listener sees one.
  String _errorJson(String message) =>
      '{"errorMsg":"$message","permanent":true}';
}
