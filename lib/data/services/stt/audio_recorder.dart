import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../domain/engines/silence_detector.dart';
import '../../../domain/repositories/speech_ports.dart';

/// Records audio to a temporary .wav file for Whisper transcription.
///
/// Uses the `record` package which provides raw PCM/WAV output — unlike
/// `speech_to_text` which only gives text, this gives us the actual audio
/// bytes needed to send to Whisper.
class AudioRecorderService implements AudioRecorderPort {
  AudioRecorderService({Logger? log})
    : _log = log ?? Logger('AudioRecorderService');

  final Logger _log;
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _currentPath;

  @override
  bool get isRecording => _isRecording;

  /// Start recording to a temporary WAV file.
  /// Returns the file path where audio will be saved.
  @override
  Future<String> start() async {
    if (_isRecording) {
      throw StateError('Already recording');
    }

    // Check microphone permission
    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission not granted');
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'pronunciation_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: path,
    );

    _isRecording = true;
    _currentPath = path;
    _log.info('Started recording to $path');
    return path;
  }

  /// Record until silence (voice-activity auto-stop), the [maxDuration] cap, or
  /// [stopSignal] fires; then stop and return the recorded WAV path. Polls the
  /// microphone amplitude and drives a [SilenceDetector]; the recorded audio is
  /// always returned so it can still be transcribed after a manual stop.
  @override
  Future<String> recordUntilSilence({
    Duration silenceTimeout = const Duration(seconds: 2),
    Duration maxDuration = const Duration(seconds: 10),
    Future<void>? stopSignal,
  }) async {
    await start();
    final detector = SilenceDetector(silenceTimeout: silenceTimeout);
    final watch = Stopwatch()..start();
    var manuallyStopped = false;
    stopSignal?.then((_) => manuallyStopped = true);

    const poll = Duration(milliseconds: 150);
    while (_isRecording) {
      await Future<void>.delayed(poll);
      if (manuallyStopped || watch.elapsed >= maxDuration) break;
      try {
        final amp = await _recorder.getAmplitude();
        if (detector.accept(amp.current, watch.elapsed)) break;
      } catch (_) {
        // Amplitude unavailable on this platform/instant — keep recording and
        // rely on the max cap / manual stop rather than aborting.
      }
    }
    return stop();
  }

  /// Stop recording and return the path to the recorded WAV file.
  @override
  Future<String> stop() async {
    // Idempotent: recordUntilSilence and a manual stop can both call this.
    if (!_isRecording) return _currentPath ?? '';

    final path = await _recorder.stop();
    _isRecording = false;
    _currentPath = path;
    _log.info('Stopped recording: $path');
    return path ?? '';
  }

  /// Cancel recording and delete the audio file.
  Future<void> cancel() async {
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
    }
    if (_currentPath != null) {
      try {
        final file = File(_currentPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      _currentPath = null;
    }
  }

  /// Clean up the last recording file.
  @override
  Future<void> cleanup() async {
    if (_currentPath != null) {
      try {
        final file = File(_currentPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      _currentPath = null;
    }
  }

  /// Dispose the recorder.
  Future<void> dispose() async {
    if (_isRecording) await _recorder.cancel();
    await _recorder.dispose();
  }
}
