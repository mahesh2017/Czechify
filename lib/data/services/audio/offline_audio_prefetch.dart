import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/backend_config.dart';

/// Progress of a first-run (or on-demand) unit audio download.
class PrefetchProgress {
  const PrefetchProgress({
    required this.completed,
    required this.total,
    this.failed = 0,
    this.finished = false,
  });

  final int completed;
  final int total;
  final int failed;
  final bool finished;

  double get fraction => total == 0 ? 1 : completed / total;

  /// True when every clip landed. A partial pack still works — playback falls
  /// back to streaming for whatever is missing — so this is informational
  /// rather than a failure gate.
  bool get complete => finished && failed == 0;
}

/// Downloads a unit's audio ahead of time so lessons work with no network.
///
/// Clips are written into the same `neural_audio` directory [CzechTts] reads
/// from, keyed by the same content hash, so a pre-fetched lesson simply finds
/// its files already there — no playback changes, and no second cache to keep
/// coherent.
///
/// Audio is small: units 1-3 are about 3 MB in one voice. The expensive part of
/// going offline is the speech model, which is downloaded separately; keeping
/// these apart means a learner can start a lesson in seconds rather than
/// waiting behind a few hundred megabytes.
class OfflineAudioPrefetch {
  OfflineAudioPrefetch(this._http);

  final Dio _http;
  static const _manifestAsset = 'assets/audio/offline_units.json';

  Map<String, List<String>>? _unitKeys;
  String? _cacheDir;

  String get _publicBase =>
      '${BackendConfig.supabaseUrl}/storage/v1/object/public/course-audio';

  Future<String> _dir() async {
    if (_cacheDir != null) return _cacheDir!;
    final support = await getApplicationSupportDirectory();
    final path = '${support.path}/neural_audio';
    await Directory(path).create(recursive: true);
    return _cacheDir = path;
  }

  Future<Map<String, List<String>>> _load() async {
    if (_unitKeys != null) return _unitKeys!;
    final raw = await rootBundle.loadString(_manifestAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final units = json['units'] as Map<String, dynamic>? ?? const {};
    return _unitKeys = {
      for (final entry in units.entries)
        entry.key: (entry.value as List<dynamic>).cast<String>(),
    };
  }

  /// Clips for [unitIds] that are not already on disk, for [gender].
  Future<List<String>> missingFiles(List<int> unitIds, String gender) async {
    final byUnit = await _load();
    final dir = await _dir();
    final keys = <String>{for (final id in unitIds) ...?byUnit['$id']};
    final missing = <String>[];
    for (final key in keys) {
      final name = '${gender}_$key.mp3';
      if (!await File('$dir/$name').exists()) missing.add(name);
    }
    return missing;
  }

  /// Download every missing clip for [unitIds], reporting progress as it goes.
  ///
  /// Failures are counted, not thrown: a learner with one dead clip should
  /// still get the other 250, and playback will stream the straggler when it
  /// is next needed.
  Stream<PrefetchProgress> download(
    List<int> unitIds,
    String gender, {
    int concurrency = 4,
  }) async* {
    if (!BackendConfig.isConfigured) {
      yield const PrefetchProgress(completed: 0, total: 0, finished: true);
      return;
    }

    final files = await missingFiles(unitIds, gender);
    final total = files.length;
    if (total == 0) {
      yield const PrefetchProgress(completed: 0, total: 0, finished: true);
      return;
    }

    final dir = await _dir();
    var completed = 0;
    var failed = 0;
    final controller = StreamController<PrefetchProgress>();
    final queue = List<String>.from(files);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final name = queue.removeLast();
        final target = File('$dir/$name');
        // .part then rename: an interrupted download must never leave a
        // truncated file that looks cached and plays as silence.
        final partial = File('${target.path}.part');
        try {
          await _http.download('$_publicBase/$name', partial.path);
          if (!await partial.exists() || await partial.length() == 0) {
            throw const FileSystemException('empty clip');
          }
          await partial.rename(target.path);
        } catch (_) {
          failed++;
          await partial.delete().catchError((_) => partial);
        } finally {
          completed++;
          if (!controller.isClosed) {
            controller.add(
              PrefetchProgress(
                completed: completed,
                total: total,
                failed: failed,
              ),
            );
          }
        }
      }
    }

    unawaited(
      Future.wait([
        for (var i = 0; i < concurrency; i++) worker(),
      ]).whenComplete(() {
        if (!controller.isClosed) {
          controller.add(
            PrefetchProgress(
              completed: completed,
              total: total,
              failed: failed,
              finished: true,
            ),
          );
          controller.close();
        }
      }),
    );

    yield* controller.stream;
  }
}
