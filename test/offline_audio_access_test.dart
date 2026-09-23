import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:czechify/data/services/audio/offline_audio_prefetch.dart';

class _Clips implements HttpClientAdapter {
  final void Function() onRequest;
  int requests = 0;
  _Clips(this.onRequest);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    onRequest();
    return ResponseBody.fromBytes([1, 2, 3], 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('audio-access');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => temp.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await temp.delete(recursive: true);
  });

  test('queued batch rechecks access when listening starts', () async {
    var allowed = <int>{3};
    final adapter = _Clips(() {});
    final service = OfflineAudioPrefetch(
      Dio()..httpClientAdapter = adapter,
      storageBaseUrl: 'https://audio.invalid',
      accessibleUnits: () async => allowed,
    );
    final batch = service.download([3], 'male');
    allowed = {};
    final result = await batch.last;
    expect(adapter.requests, 0);
    expect(result.total, 0);
  });

  for (final switchAccount in [false, true]) {
    test(
      'queued clips stop after ${switchAccount ? "account switch" : "access expiry"}',
      () async {
        var allowed = <int>{3};
        var account = 'a';
        final adapter = _Clips(() {
          if (switchAccount) {
            account = 'b';
          } else {
            allowed = {};
          }
        });
        final service = OfflineAudioPrefetch(
          Dio()..httpClientAdapter = adapter,
          storageBaseUrl: 'https://audio.invalid',
          accessibleUnits: () async => allowed,
          accountContext: () => account,
        );
        final result = await service.download([3], 'male', concurrency: 1).last;
        expect(result.total, greaterThan(1));
        expect(adapter.requests, 1);
        expect(result.failed, result.total - 1);
        expect(
          Directory('${temp.path}/neural_audio').listSync().whereType<File>(),
          hasLength(1),
          reason: 'already downloaded audio is preserved',
        );
      },
    );
  }

  test('access lookup error downloads nothing and surfaces failure', () async {
    final adapter = _Clips(() {});
    final service = OfflineAudioPrefetch(
      Dio()..httpClientAdapter = adapter,
      storageBaseUrl: 'https://audio.invalid',
      accessibleUnits: () async => throw StateError('unavailable'),
    );
    final result = await service.download([3], 'male').last;
    expect(adapter.requests, 0);
    expect(result.complete, false);
  });
  test(
    'account change during initial refresh finishes without downloading',
    () async {
      var account = 'a';
      final adapter = _Clips(() {});
      final service = OfflineAudioPrefetch(
        Dio()..httpClientAdapter = adapter,
        storageBaseUrl: 'https://audio.invalid',
        accessibleUnits: () async => {3},
        accountContext: () => account,
        refreshAccess: () async {
          account = 'b';
        },
      );
      final result = await service.download([3], 'male').last;
      expect(adapter.requests, 0);
      expect(result.finished, true);
      expect(result.complete, false);
    },
  );
}
