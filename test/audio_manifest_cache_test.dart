import 'dart:io';

import 'package:czechify/core/config/release_config.dart';
import 'package:czechify/data/services/audio/audio_pack_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The manifest is ~2 MB and was re-fetched on every cold start, so egress
/// scaled with how much a learner used the app rather than with installs. It
/// is now keyed on disk by the content revision, which is the same value that
/// already cache-busts the URL.
///
/// These tests pin the property that matters — a launch holding the current
/// revision makes no request at all — and the fallbacks that must survive it.
class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.body);

  final String body;
  int calls = 0;
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'test offline',
      );
    }
    return ResponseBody.fromString(body, 200);
  }

  @override
  void close({bool force = false}) {}
}

String manifestJson(String path) =>
    '{"version":3,"locale":"cs-CZ","voices":{"female":{"entries":'
    '{"abc":{"path":"$path","sha256":"d","size":1}}}}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const revision = ReleaseConfig.bundledContentRevision;
  const manifestName = 'manifest.json';
  const currentCacheName = 'manifest.v$revision.json';

  late Directory temp;
  late _CountingAdapter adapter;

  /// Where AudioPackCache actually writes, under the mocked support directory.
  Directory packDir() => Directory('${temp.path}/neural_audio');

  AudioPackCache newCache() {
    final dio = Dio()..httpClientAdapter = adapter;
    return AudioPackCache(
      http: dio,
      manifestFileName: manifestName,
      publicBase: 'https://example.test/audio',
    );
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('audio_pack_cache');
    adapter = _CountingAdapter(manifestJson('female_a.mp3'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => temp.path,
        );
    AudioPackCache.resetSharedState();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    AudioPackCache.resetSharedState();
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  test('the first launch fetches and caches under the current revision', () async {
    final manifest = await newCache().load();

    expect(manifest, isNotNull);
    expect(adapter.calls, 1);
    expect(File('${packDir().path}/$currentCacheName').existsSync(), isTrue);
  });

  test('a later launch holding that revision makes no request', () async {
    await newCache().load();
    expect(adapter.calls, 1);

    // A separate instance, as a fresh process would build.
    final manifest = await newCache().load();

    expect(manifest, isNotNull, reason: 'must still resolve, from disk');
    expect(adapter.calls, 1, reason: 'the network was not touched again');
  });

  test('a superseded revision is refetched, and its file cleaned up', () async {
    await packDir().create(recursive: true);
    final stale = File('${packDir().path}/manifest.v${revision - 1}.json')
      ..writeAsStringSync(manifestJson('female_old.mp3'));

    await newCache().load();

    expect(adapter.calls, 1, reason: 'a different revision is not reusable');
    expect(stale.existsSync(), isFalse, reason: 'old revisions are dropped');
    expect(File('${packDir().path}/$currentCacheName').existsSync(), isTrue);
  });

  test('the pre-revision cache file is cleaned up on upgrade', () async {
    await packDir().create(recursive: true);
    final legacy = File('${packDir().path}/$manifestName')
      ..writeAsStringSync(manifestJson('female_legacy.mp3'));

    await newCache().load();

    expect(legacy.existsSync(), isFalse, reason: '~2 MB should not linger');
  });

  test('offline with only an older revision still speaks', () async {
    await packDir().create(recursive: true);
    File('${packDir().path}/manifest.v${revision - 1}.json')
        .writeAsStringSync(manifestJson('female_old.mp3'));
    adapter.offline = true;

    final manifest = await newCache().load();

    expect(
      manifest?.forGender('female')['abc']?.path,
      'female_old.mp3',
      reason: 'the clips already on the device are described by the old copy',
    );
  });

  test('offline with nothing cached degrades to null rather than throwing', () async {
    adapter.offline = true;

    expect(await newCache().load(), isNull);
  });

  test('a corrupt cache for this revision is discarded and refetched', () async {
    await packDir().create(recursive: true);
    File('${packDir().path}/$currentCacheName').writeAsStringSync('{tru');

    final manifest = await newCache().load();

    expect(manifest, isNotNull);
    expect(adapter.calls, 1, reason: 'corruption must not strand the pack');
    expect(
      File('${packDir().path}/$currentCacheName').readAsStringSync(),
      contains('female_a.mp3'),
      reason: 'the good copy replaced the corrupt one',
    );
  });
}
