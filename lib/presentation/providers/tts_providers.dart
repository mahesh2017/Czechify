import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/config/backend_config.dart';
import '../../core/utils/text_normalizer.dart';
import 'settings_providers.dart';

/// TTS provider — manages a singleton FlutterTts instance configured for Czech.
/// The speech rate follows the user's setting.
final ttsProvider = Provider<FlutterTts>((ref) {
  final tts = FlutterTts();
  // Configure for Czech language
  tts.setLanguage('cs-CZ');
  tts.setPitch(1.0);
  tts.setVolume(1.0);
  // Upgrade from the default (often "compact") voice to the best-quality Czech
  // voice the device has — a large audible improvement at no cost. Fire and
  // forget; if it fails the default cs-CZ voice still works.
  _selectBestCzechVoice(tts);
  ref.onDispose(() => tts.stop());

  // Apply the user's speech rate now and whenever the setting changes.
  ref.listen<double>(
    settingsProvider.select((s) => s.ttsSpeechRate),
    (_, rate) => tts.setSpeechRate(rate),
    fireImmediately: true,
  );
  return tts;
});

/// Pick the highest-quality Czech voice available and set it on [tts].
/// Prefers voices flagged enhanced/premium/neural; otherwise the first Czech
/// voice. Best-effort — any failure leaves the default voice in place.
Future<void> _selectBestCzechVoice(FlutterTts tts) async {
  try {
    final raw = await tts.getVoices;
    if (raw is! List) return;
    final czech =
        raw
            .whereType<Map>()
            .where(
              (v) =>
                  (v['locale'] ?? '').toString().toLowerCase().startsWith('cs'),
            )
            .toList();
    if (czech.isEmpty) return;

    final qualityRe = RegExp('enhanced|premium|neural', caseSensitive: false);
    final best = czech.firstWhere(
      (v) => qualityRe.hasMatch(
        '${v['name'] ?? ''} ${v['identifier'] ?? ''} ${v['quality'] ?? ''}',
      ),
      orElse: () => czech.first,
    );

    final name = best['name']?.toString();
    final locale = best['locale']?.toString();
    if (name != null && locale != null) {
      await tts.setVoice({'name': name, 'locale': locale});
    }
  } catch (_) {
    // Keep the default cs-CZ voice.
  }
}

/// Audio player for playing cached TTS files.
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Helper class for speaking Czech text with file-based caching.
///
/// Pipeline:
/// 1. Hash the text → cache filename
/// 2. If cached file exists → play with just_audio (fast, no network)
/// 3. If not cached → synthesize to file via flutter_tts, cache, play
/// 4. Fallback: direct speak() if file synthesis unavailable
class CzechTts {
  final FlutterTts _tts;
  final AudioPlayer _player;
  final Dio _http;

  /// Current speech rate — part of the cache key, so audio synthesized at
  /// one rate is never replayed when the user changes the setting.
  final double Function() _speechRate;
  final TtsVoiceGender Function() _voiceGender;

  String? _cacheDir;
  String? _neuralCacheDir;
  Future<Map<String, Map<String, String>>>? _remoteAudio;

  CzechTts(
    this._tts,
    this._player,
    this._http,
    this._speechRate,
    this._voiceGender,
  );

  static const _audioBucket = 'course-audio';

  String get _publicAudioBase =>
      '${BackendConfig.supabaseUrl}/storage/v1/object/public/$_audioBucket';

  /// Get the cache directory for TTS audio files.
  Future<String> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final dir = await getTemporaryDirectory();
    final ttsDir = '${dir.path}/tts_cache';
    await Directory(ttsDir).create(recursive: true);
    _cacheDir = ttsDir;
    return ttsDir;
  }

  /// Persistent cache for downloaded neural audio and its manifest.
  Future<String> _getNeuralCacheDir() async {
    if (_neuralCacheDir != null) return _neuralCacheDir!;
    final dir = await getApplicationSupportDirectory();
    final audioDir = '${dir.path}/neural_audio';
    await Directory(audioDir).create(recursive: true);
    _neuralCacheDir = audioDir;
    return audioDir;
  }

  /// Generate a cache key from the text and effective speech rate.
  String _cacheKey(String text, double rate) {
    final bytes = utf8.encode(
      '${rate.toStringAsFixed(2)}|${text.trim().toLowerCase()}',
    );
    final hash = md5.convert(bytes);
    return hash.toString();
  }

  /// The audio-pack key deliberately excludes playback speed: one neural MP3
  /// can be replayed at normal or slow speed without duplicating the catalog.
  String _audioPackKey(String text) {
    return sha256.convert(utf8.encode(text.trim().toLowerCase())).toString();
  }

  Map<String, Map<String, String>> _parseManifest(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final voices = json['voices'] as Map<String, dynamic>? ?? const {};
    return voices.map((gender, value) {
      final voice = value as Map<String, dynamic>;
      final entries = voice['entries'] as Map<String, dynamic>? ?? const {};
      return MapEntry(
        gender,
        entries.map((key, path) => MapEntry(key, path as String)),
      );
    });
  }

  Future<Map<String, Map<String, String>>> _loadRemoteAudio() async {
    if (!BackendConfig.isConfigured) {
      // The binary was built without the Supabase --dart-defines, so
      // BackendConfig.supabaseUrl is empty and the manifest request below
      // would hit '<empty>/storage/...' and silently fall back to platform
      // TTS. Short-circuit and log loudly so the cause is obvious on-device.
      debugPrint(
        '[czech_tts] Neural audio disabled: SUPABASE_URL/SUPABASE_ANON_KEY '
        'not supplied at build time. Using on-device TTS fallback. '
        'Rebuild with both --dart-define values to enable neural audio.',
      );
      return const {};
    }

    final cacheDir = await _getNeuralCacheDir();
    final cachedManifest = File('$cacheDir/manifest.json');

    try {
      final response = await _http.get<String>(
        '$_publicAudioBase/manifest.json',
        options: Options(responseType: ResponseType.plain),
      );
      final raw = response.data;
      if (raw == null || raw.isEmpty) {
        throw const FormatException('Empty manifest');
      }
      final parsed = _parseManifest(raw);
      await cachedManifest.writeAsString(raw, flush: true);
      return parsed;
    } catch (_) {
      if (await cachedManifest.exists()) {
        try {
          return _parseManifest(await cachedManifest.readAsString());
        } catch (_) {
          // Continue to the native TTS fallback below.
        }
      }
      return const {};
    }
  }

  Future<bool> _playNeural(String text, double effectiveRate) async {
    final voices = await (_remoteAudio ??= _loadRemoteAudio());
    final entries = voices[_voiceGender().name] ?? const {};
    final remotePath = entries[_audioPackKey(text)];
    if (remotePath == null) return false;

    final fileName = remotePath.split('/').last;
    if (!RegExp(r'^[a-z]+_[0-9a-f]{64}\.mp3$').hasMatch(fileName)) {
      return false;
    }

    try {
      final cacheDir = await _getNeuralCacheDir();
      final cachedAudio = File('$cacheDir/$fileName');
      if (!await cachedAudio.exists()) {
        final partial = File('${cachedAudio.path}.part');
        await _http.download('$_publicAudioBase/$fileName', partial.path);
        if (!await partial.exists() || await partial.length() == 0) {
          throw const FileSystemException('Downloaded audio is empty');
        }
        await partial.rename(cachedAudio.path);
      }

      await _player.setFilePath(cachedAudio.path);
      // flutter_tts's default setting is 0.45. Preserve the existing control
      // semantics while keeping a single pre-generated file per utterance.
      await _player.setSpeed((effectiveRate / 0.45).clamp(0.5, 1.5));
      await _player.play();
      return true;
    } catch (_) {
      // A stale/partial manifest must never prevent speech.
      return false;
    }
  }

  /// Get the cached file path for a given text and rate.
  Future<String> _cachedFilePath(String text, double rate) async {
    final dir = await _getCacheDir();
    return '$dir/${_cacheKey(text, rate)}.mp3';
  }

  /// Speak the given Czech text. Uses cache when available.
  /// Stops any currently playing speech. [rate] overrides the user's
  /// configured speech rate for this utterance only (e.g. slow replay).
  Future<void> speak(String text, {double? rate}) async {
    // Strip blank markers and editorial hints so TTS never reads "___" aloud
    // as "podtržítko". Used for both the neural-pack lookup and device TTS, so
    // the request matches the sanitized text the audio pack is generated from.
    final trimmed = TextNormalizer.forSpeech(text);
    if (trimmed.isEmpty) return;

    await stop();

    final effectiveRate = rate ?? _speechRate();

    // Curriculum and vocabulary audio is generated once with a controlled
    // neural voice, downloaded from Supabase Storage, and retained for offline
    // reuse. It takes precedence over platform TTS whenever available.
    if (await _playNeural(trimmed, effectiveRate)) return;

    // macOS: flutter_tts's synthesizeToFile resolves paths relative to the
    // sandbox Documents dir and can't write mp3 (AVFoundation 'fmt?' error),
    // which spams retries and never produces a playable cache file. Speak
    // directly — native TTS is offline and instant, so the cache adds
    // nothing on this platform anyway.
    if (Platform.isMacOS) {
      if (rate != null) await _tts.setSpeechRate(rate);
      try {
        await _tts.speak(trimmed);
      } finally {
        if (rate != null) await _tts.setSpeechRate(_speechRate());
      }
      return;
    }

    try {
      final filePath = await _cachedFilePath(trimmed, effectiveRate);
      final cachedFile = File(filePath);

      if (await cachedFile.exists()) {
        // Play cached file
        await _player.setFilePath(filePath);
        await _player.setSpeed(1.0);
        await _player.play();
        return;
      }

      // Try to synthesize to file and cache. Rate overrides temporarily
      // change the engine rate for synthesis, then restore the setting.
      if (rate != null) await _tts.setSpeechRate(rate);
      try {
        final synthesized = await _tts.synthesizeToFile(trimmed, filePath);
        if (synthesized == 1) {
          // Synthesis succeeded — play the file
          await _player.setFilePath(filePath);
          await _player.setSpeed(1.0);
          await _player.play();
        } else {
          // Fallback: direct speak (no caching). The rate override may not
          // be restored until this utterance finishes queuing — acceptable.
          await _tts.speak(trimmed);
        }
      } finally {
        if (rate != null) await _tts.setSpeechRate(_speechRate());
      }
    } catch (_) {
      // Fallback: direct speak
      await _tts.speak(trimmed);
    }
  }

  /// Speak at ~60% of the configured rate — the "turtle button" for
  /// dictation and listening practice.
  Future<void> speakSlow(String text) {
    final slow = (_speechRate() * 0.6).clamp(0.1, 1.0);
    return speak(text, rate: slow);
  }

  /// Stop any currently playing speech.
  Future<void> stop() async {
    await _tts.stop();
    await _player.stop();
  }

  /// Check if Czech voice is available on the device.
  Future<bool> isCzechAvailable() async {
    final languages = await _tts.getLanguages;
    if (languages == null) return false;
    return languages.any(
      (lang) => lang.toString().toLowerCase().startsWith('cs'),
    );
  }

  /// Clear the TTS cache directory.
  Future<void> clearCache() async {
    final dir = await _getCacheDir();
    final dirObj = Directory(dir);
    if (await dirObj.exists()) {
      await dirObj.delete(recursive: true);
      await dirObj.create(recursive: true);
    }
    final neuralDir = Directory(await _getNeuralCacheDir());
    if (await neuralDir.exists()) {
      await neuralDir.delete(recursive: true);
      await neuralDir.create(recursive: true);
    }
    _remoteAudio = null;
  }

  /// Get the current cache size in bytes.
  Future<int> cacheSize() async {
    final dir = await _getCacheDir();
    final dirObj = Directory(dir);
    if (!await dirObj.exists()) return 0;

    int total = 0;
    await for (final entity in dirObj.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    final neuralDir = Directory(await _getNeuralCacheDir());
    await for (final entity in neuralDir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}

/// Whether the device has any Czech TTS voice installed. Surfaced as a
/// one-time hint so "listen" buttons never silently do nothing on devices
/// without a Czech voice (neural audio packs still cover curriculum audio).
final czechTtsAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.read(czechTtsProvider).isCzechAvailable();
  } catch (_) {
    // Unknown ≠ missing — don't nag when the engine can't even be asked.
    return true;
  }
});

/// Provider for the CzechTts helper.
final czechTtsProvider = Provider<CzechTts>((ref) {
  final tts = ref.read(ttsProvider);
  final player = ref.read(audioPlayerProvider);
  return CzechTts(
    tts,
    player,
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    ),
    () => ref.read(settingsProvider).ttsSpeechRate,
    () => ref.read(settingsProvider).ttsVoiceGender,
  );
});
