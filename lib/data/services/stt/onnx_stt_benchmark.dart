import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Result of timing the Czech recogniser on this device.
class SttBenchmarkResult {
  const SttBenchmarkResult({
    required this.loadSeconds,
    required this.runSeconds,
    required this.audioSeconds,
  });

  /// One-off cost of getting the model into memory.
  final double loadSeconds;

  /// Every inference, in order. The first is always slower — caches are cold
  /// and the graph has not been exercised — so it must not be treated as
  /// representative.
  final List<double> runSeconds;

  final double audioSeconds;

  /// Steady-state latency: median of everything after the first run.
  ///
  /// Median rather than mean, because a single scheduling hiccup on a loaded
  /// phone would drag an average somewhere misleading.
  double get medianSteadyState {
    final steady =
        runSeconds.length > 1
            ? (runSeconds.sublist(1)..sort())
            : (List<double>.from(runSeconds)..sort());
    if (steady.isEmpty) return 0;
    final middle = steady.length ~/ 2;
    return steady.length.isOdd
        ? steady[middle]
        : (steady[middle - 1] + steady[middle]) / 2;
  }

  double get firstRunSeconds => runSeconds.isEmpty ? 0 : runSeconds.first;

  /// Seconds of compute per second of audio. Below 1.0 is faster than real
  /// time, which is the bar for this to feel instant on a short recording.
  double get realTimeFactor =>
      audioSeconds == 0 ? 0 : medianSteadyState / audioSeconds;

  @override
  String toString() =>
      'load ${loadSeconds.toStringAsFixed(2)}s · '
      'first ${firstRunSeconds.toStringAsFixed(2)}s · '
      'steady ${medianSteadyState.toStringAsFixed(2)}s · '
      'RTF ${realTimeFactor.toStringAsFixed(2)}';
}

/// Times the Czech wav2vec2 model on the device it is actually running on.
///
/// This exists to answer one question before any download or consent machinery
/// is built around it: is a 300M-parameter CTC model fast enough on mid-range
/// hardware to feel instant? Desktop numbers do not transfer — a Dimensity 700
/// is not an M-series Mac — and the answer changes the architecture, not just
/// a constant.
class OnnxSttBenchmark {
  /// [modelPath] is a file on disk; the model is far too large to bundle.
  Future<SttBenchmarkResult> run({
    required String modelPath,
    double audioSeconds = 3.0,
    int iterations = 5,
  }) async {
    final ort = OnnxRuntime();

    final loadWatch = Stopwatch()..start();
    final session = await ort.createSession(modelPath);
    loadWatch.stop();

    // Silence is fine for timing: wav2vec2 does a fixed amount of work per
    // sample regardless of content, so the numbers hold for real speech.
    // Accuracy is measured separately, against real recordings.
    final sampleCount = (16000 * audioSeconds).round();
    final samples = Float32List(sampleCount);

    final runs = <double>[];
    try {
      for (var i = 0; i < iterations; i++) {
        final input = await OrtValue.fromList(samples, [1, sampleCount]);
        final watch = Stopwatch()..start();
        final outputs = await session.run({'input_values': input});
        watch.stop();
        runs.add(watch.elapsedMicroseconds / 1e6);
        for (final value in outputs.values) {
          await value.dispose();
        }
        await input.dispose();
      }
    } finally {
      await session.close();
    }

    final result = SttBenchmarkResult(
      loadSeconds: loadWatch.elapsedMicroseconds / 1e6,
      runSeconds: runs,
      audioSeconds: audioSeconds,
    );
    debugPrint('[stt_bench] $result');
    return result;
  }

  /// Whether this device should be offered server-side recognition.
  ///
  /// Judged on the steady-state median, never the first run: that one includes
  /// cold caches and would tell every user their device is too slow. The model
  /// is loaded at app start precisely so learners never meet that first run.
  static bool isTooSlow(SttBenchmarkResult result, {double threshold = 5.0}) =>
      result.medianSteadyState >= threshold;

  static double percentile(List<double> values, double fraction) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final index = ((sorted.length - 1) * fraction).round();
    return sorted[math.max(0, math.min(index, sorted.length - 1))];
  }
}
