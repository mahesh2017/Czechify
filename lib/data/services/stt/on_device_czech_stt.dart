import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'stt_model_manager.dart';

/// A transcript produced entirely on the learner's device.
class OnDeviceTranscript {
  const OnDeviceTranscript({
    required this.text,
    required this.confidence,
    required this.seconds,
  });

  final String text;

  /// Mean per-frame probability of the chosen tokens, 0..1.
  ///
  /// Not a pronunciation score — it says how sure the model is about what it
  /// heard, which is a different question from how correct the speech was.
  final double confidence;

  /// Wall-clock inference time, used to decide whether this device is fast
  /// enough to keep doing this locally.
  final double seconds;
}

/// Czech speech recognition that never leaves the device.
///
/// This is the point of the whole exercise: a learner's voice is personal data,
/// and sending it to a US service turns an ordinary language app into an
/// international transfer with everything that follows. Running the model
/// locally removes the transfer, so there is nothing to disclose, no processor
/// agreement to hold, and nothing to consent to.
class OnDeviceCzechStt {
  OnDeviceCzechStt(this._models);

  final SttModelManager _models;
  static const _vocabAsset = 'assets/stt/vocab.json';

  Map<int, String>? _tokens;
  int _blankId = 0;

  Future<Map<int, String>> _vocab() async {
    if (_tokens != null) return _tokens!;
    final raw = await rootBundle.loadString(_vocabAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final byId = <int, String>{};
    json.forEach((token, id) => byId[id as int] = token);
    // CTC's blank is the padding token; decoding against the wrong index
    // produces fluent-looking nonsense rather than an obvious failure.
    _blankId = (json['[PAD]'] as int?) ?? 0;
    return _tokens = byId;
  }

  bool get isReady => _models.isReady;

  /// Transcribe 16 kHz mono float samples in the range -1..1.
  ///
  /// Returns null when the model is not loaded — the caller decides what to do
  /// about that, rather than this silently substituting something else.
  Future<OnDeviceTranscript?> transcribe(Float32List samples) async {
    final session = _models.session ?? await _models.preload();
    if (session == null) return null;

    final vocab = await _vocab();
    final input = await OrtValue.fromList(samples, [1, samples.length]);
    final watch = Stopwatch()..start();
    try {
      final outputs = await session.run({'input_values': input});
      watch.stop();
      final logits = outputs.values.first;
      final flat = (await logits.asFlattenedList()).cast<double>();
      final shape = logits.shape;
      await logits.dispose();

      // [batch, frames, vocab]
      final frames = shape.length >= 2 ? shape[shape.length - 2] : 0;
      final classes = shape.isNotEmpty ? shape.last : vocab.length;
      if (frames == 0 || classes == 0) return null;

      final buffer = StringBuffer();
      var previous = -1;
      var probabilitySum = 0.0;
      var counted = 0;

      for (var frame = 0; frame < frames; frame++) {
        final offset = frame * classes;
        var bestId = 0;
        var best = double.negativeInfinity;
        var sumExp = 0.0;
        for (var c = 0; c < classes; c++) {
          final value = flat[offset + c];
          if (value > best) {
            best = value;
            bestId = c;
          }
        }
        // Softmax over the frame, for a confidence that means something.
        for (var c = 0; c < classes; c++) {
          sumExp += math.exp(flat[offset + c] - best);
        }
        if (sumExp > 0) {
          probabilitySum += 1 / sumExp;
          counted++;
        }

        // Greedy CTC: drop blanks, and collapse runs of the same token.
        if (bestId != _blankId && bestId != previous) {
          buffer.write(vocab[bestId] ?? '');
        }
        previous = bestId;
      }

      final text =
          buffer
              .toString()
              .replaceAll('|', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

      return OnDeviceTranscript(
        text: text,
        confidence: counted == 0 ? 0 : probabilitySum / counted,
        seconds: watch.elapsedMicroseconds / 1e6,
      );
    } catch (error) {
      debugPrint('[stt] on-device transcription failed: $error');
      return null;
    } finally {
      await input.dispose();
    }
  }
}
