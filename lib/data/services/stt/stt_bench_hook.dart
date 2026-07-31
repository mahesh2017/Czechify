import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'onnx_stt_benchmark.dart';

/// Runs the speech benchmark at startup when a model has been side-loaded.
///
/// Measuring on real hardware is the one thing that decides whether on-device
/// recognition is viable, and desktop numbers do not transfer. Rather than
/// build a settings screen for a question asked once per device, the benchmark
/// triggers on the presence of a file that only ever gets there deliberately:
///
///     adb push model_int8.onnx \
///       /sdcard/Android/data/com.ceskinapro.ceskina_pro/files/
///
/// Never runs in a release build, and never when the file is absent — so a
/// shipped app cannot spend a learner's battery on a benchmark.
class SttBenchHook {
  static const _fileName = 'model_int8.onnx';

  static Future<void> maybeRun() async {
    if (kReleaseMode) return;
    try {
      final dir =
          Platform.isAndroid
              ? await getExternalStorageDirectory()
              : await getApplicationSupportDirectory();
      if (dir == null) return;
      final model = File('${dir.path}/$_fileName');
      if (!await model.exists()) return;

      final size = await model.length();
      debugPrint(
        '[stt_bench] found model: ${(size / 1e6).toStringAsFixed(1)} MB '
        'at ${model.path}',
      );
      // 3 seconds is a realistic pronunciation attempt; a learner saying one
      // phrase rarely exceeds it.
      final result = await OnnxSttBenchmark().run(
        modelPath: model.path,
        audioSeconds: 3.0,
        iterations: 6,
      );
      debugPrint(
        '[stt_bench] runs: '
        '${result.runSeconds.map((s) => s.toStringAsFixed(2)).join(', ')}',
      );
      debugPrint(
        '[stt_bench] verdict: '
        '${OnnxSttBenchmark.isTooSlow(result) ? "TOO SLOW — would offer server" : "fast enough for on-device"}',
      );
    } catch (error, stack) {
      // A benchmark must never take the app down with it.
      debugPrint('[stt_bench] failed: $error\n$stack');
    }
  }
}
