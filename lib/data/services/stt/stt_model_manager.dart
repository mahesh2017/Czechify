import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

/// Where the on-device Czech recogniser is downloaded from.
///
/// A build-time value, not a constant, so the model can be moved to a CDN
/// without shipping a new binary. Supabase's free tier allows 5 GB of egress a
/// month and this file is ~340 MB, so roughly fifteen installs exhaust it —
/// object storage with free egress is where this belongs before any real
/// number of users.
const String kSttModelUrl = String.fromEnvironment('STT_MODEL_URL');

/// Expected size in bytes, used to detect a truncated download.
const int kSttModelBytes = int.fromEnvironment('STT_MODEL_BYTES');

class ModelDownloadProgress {
  const ModelDownloadProgress(this.received, this.total);
  final int received;
  final int total;

  double get fraction => total <= 0 ? 0 : received / total;
  int get remainingMb => ((total - received) / 1e6).round();
}

enum SttModelState {
  /// No model on disk and none being fetched.
  absent,
  downloading,

  /// On disk but not yet loaded into memory.
  present,

  /// Loaded and ready to transcribe.
  ready,
}

/// Owns the on-device speech model: download, load, and lifetime.
///
/// The session is loaded once and held. Loading costs about 2.5 seconds and
/// the first inference afterwards is slower than the rest, so doing it lazily
/// would put both delays in front of a learner's first pronunciation attempt —
/// the worst possible moment. Preloading at startup means they only ever meet
/// steady-state latency.
class SttModelManager {
  SttModelManager(this._http);

  final Dio _http;
  static const _fileName = 'czech_stt_int8.onnx';

  OrtSession? _session;
  Future<OrtSession?>? _loading;
  SttModelState _state = SttModelState.absent;

  SttModelState get state => _state;
  OrtSession? get session => _session;
  bool get isReady => _session != null;

  final ValueNotifier<SttModelState> stateListenable = ValueNotifier(
    SttModelState.absent,
  );

  void _setState(SttModelState next) {
    _state = next;
    stateListenable.value = next;
  }

  Future<File> _modelFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// True when a complete model is on disk.
  ///
  /// Size is checked, not just existence: a download interrupted at 90% leaves
  /// a file that looks present and fails to load.
  Future<bool> isDownloaded() async {
    final file = await _modelFile();
    if (!await file.exists()) return false;
    if (kSttModelBytes <= 0) return await file.length() > 0;
    return await file.length() == kSttModelBytes;
  }

  /// Download the model, resuming a partial file where possible.
  Stream<ModelDownloadProgress> download() async* {
    if (kSttModelUrl.isEmpty) {
      throw StateError('STT_MODEL_URL was not supplied at build time');
    }
    if (await isDownloaded()) return;

    _setState(SttModelState.downloading);
    final target = await _modelFile();
    final partial = File('${target.path}.part');
    final already = await partial.exists() ? await partial.length() : 0;

    final controller = StreamController<ModelDownloadProgress>();
    unawaited(
      _http
          .download(
            kSttModelUrl,
            partial.path,
            deleteOnError: false,
            // Resume from where an interrupted attempt stopped. On a 340 MB
            // file over mobile data, restarting from zero is the difference
            // between finishing and giving up.
            options:
                already > 0
                    ? Options(headers: {'Range': 'bytes=$already-'})
                    : null,
            onReceiveProgress: (received, total) {
              if (!controller.isClosed) {
                controller.add(
                  ModelDownloadProgress(already + received, already + total),
                );
              }
            },
          )
          .then((_) async {
            await partial.rename(target.path);
            _setState(SttModelState.present);
          })
          .catchError((Object error) {
            // The partial file is kept deliberately, so the next attempt
            // resumes rather than starting again.
            _setState(SttModelState.absent);
            if (!controller.isClosed) controller.addError(error);
          })
          .whenComplete(() {
            if (!controller.isClosed) controller.close();
          }),
    );

    yield* controller.stream;
  }

  /// Load the model into memory. Safe to call repeatedly and concurrently.
  Future<OrtSession?> preload() async {
    if (_session != null) return _session;
    return _loading ??= _load();
  }

  Future<OrtSession?> _load() async {
    try {
      if (!await isDownloaded()) {
        _setState(SttModelState.absent);
        return null;
      }
      final file = await _modelFile();
      final watch = Stopwatch()..start();
      _session = await OnnxRuntime().createSession(file.path);
      watch.stop();
      debugPrint(
        '[stt] model loaded in ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s',
      );
      _setState(SttModelState.ready);
      return _session;
    } catch (error) {
      // A model that will not load must not break the app — pronunciation
      // falls back, and the learner is told rather than left guessing.
      debugPrint('[stt] model failed to load: $error');
      _setState(SttModelState.absent);
      return null;
    } finally {
      _loading = null;
    }
  }

  Future<void> dispose() async {
    await _session?.close();
    _session = null;
    _setState(SttModelState.absent);
  }

  /// Remove the model from the device, freeing ~340 MB.
  Future<void> delete() async {
    await dispose();
    final file = await _modelFile();
    if (await file.exists()) await file.delete();
    final partial = File('${file.path}.part');
    if (await partial.exists()) await partial.delete();
  }
}
