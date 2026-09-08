import 'dart:convert';

import 'package:czechify/domain/repositories/speech_ports.dart';
import 'package:czechify/presentation/providers/stt_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _RecordingPlatform platform;
  late NativeSttService service;
  setUp(() {
    platform = _RecordingPlatform();
    SpeechToTextPlatform.instance = platform;
    service = NativeSttService(speech: SpeechToText.withMethodChannel());
  });

  for (final partial in [false, true]) {
    test(
      'network failure does not grade ${partial ? "partial words" : "silence"}',
      () async {
        platform.onListen = () {
          if (partial) platform.words('Dobrý');
          platform.fail('error_network');
        };
        await expectLater(
          service.listenFor(),
          throwsA(isA<SpeechServiceException>()),
        );
        expect(platform.cancels, 1);
      },
    );
  }

  test('permission revoked during recording gives actionable copy', () async {
    platform.onListen = () => platform.fail('error_permission');
    await expectLater(
      service.listenFor(),
      throwsA(
        isA<SpeechServiceException>()
            .having((e) => e.message, 'message', contains('permission'))
            .having((e) => e.cloudSpeechWouldFix, 'cloudSpeechWouldFix', false),
      ),
    );
  });

  test('recording can succeed after an error', () async {
    platform.onListen = () => platform.fail('error_network');
    await expectLater(
      service.listenFor(),
      throwsA(isA<SpeechServiceException>()),
    );
    platform.onListen = () => platform.words('Dobrý den', finalResult: true);
    expect(await service.listenFor(), 'Dobrý den');
    expect(platform.cancels, 2);
  });

  test('successful partial transcription survives a normal timeout', () async {
    platform.onListen = () => platform.words('Dobrý den');
    expect(
      await service.listenFor(timeout: const Duration(milliseconds: 20)),
      'Dobrý den',
    );
    expect(platform.cancels, 1);
  });

  test(
    'no recognition result is retriable, not a scored empty answer',
    () async {
      platform.onListen = () {};
      await expectLater(
        service.listenFor(timeout: const Duration(milliseconds: 20)),
        throwsA(
          isA<SpeechServiceException>().having(
            (e) => e.message,
            'message',
            contains('No speech'),
          ),
        ),
      );
    },
  );
}

class _RecordingPlatform extends SpeechToTextPlatform {
  late void Function() onListen;
  int cancels = 0;
  @override
  Future<bool> initialize({
    dynamic debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async => true;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<List<dynamic>> locales() async => ['cs_CZ:Czech'];
  @override
  Future<bool> listen({
    String? localeId,
    dynamic partialResults = true,
    dynamic onDevice = false,
    int listenMode = 0,
    dynamic sampleRate = 0,
    SpeechListenOptions? options,
  }) async {
    onListen();
    return true;
  }

  void fail(String message) =>
      onError?.call(jsonEncode({'errorMsg': message, 'permanent': true}));
  void words(String text, {bool finalResult = false}) =>
      onTextRecognition?.call(
        jsonEncode({
          'alternates': [
            {'recognizedWords': text, 'confidence': 1.0},
          ],
          'resultType': finalResult ? 2 : 0,
        }),
      );
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {
    cancels++;
  }
}
