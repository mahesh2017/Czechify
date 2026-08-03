import 'package:logging/logging.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/services/audio/audio_pack_cache.dart';
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

/// Speaks short English narration — the teaching-card intro scripts. Kept on a
/// separate engine from the Czech [ttsProvider] so the two never fight over the
/// native voice/language. The language is re-asserted before every utterance
/// because on some platforms all FlutterTts instances share one native engine,
/// so whichever spoke last would otherwise leave the wrong language selected.
///
/// This is the "English TTS now" step; a recorded character voice (an `.mp3`
/// per unit) can replace it later without touching call sites.
class EnglishTts {
  EnglishTts(this._tts, this._player, Dio http, this._voiceGender)
    : _pack = AudioPackCache(
        http: http,
        manifestFileName: 'manifest_en.json',
        log: Logger('EnglishTts.pack'),
      ) {
    _tts.setStartHandler(() => speaking.value = true);
    _tts.setCompletionHandler(() => speaking.value = false);
    _tts.setCancelHandler(() => speaking.value = false);
    _tts.setErrorHandler((_) => speaking.value = false);
  }

  final FlutterTts _tts;
  final AudioPlayer _player;
  final TtsVoiceGender Function() _voiceGender;

  /// Narration lives in its own manifest: the Czech pack is single-locale by
  /// design, and mixing the two would make each side's coverage impossible to
  /// reason about.
  final AudioPackCache _pack;

  /// True while narration is actually playing — the teaching card watches this
  /// to switch the teacher between its idle and talking animation.
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);

  /// The narration voice follows the same setting as the Czech voice and the
  /// teacher character, so one choice stays consistent across the whole card.
  Future<bool> _playNeural(String text) async {
    final path = await _pack.clipPath(
      text: text,
      gender: _voiceGender().name,
    );
    if (path == null) return false;

    try {
      await _player.setFilePath(path);
      speaking.value = true;
      // Clear the talking animation when playback actually ends. Unawaited on
      // purpose — speak() must return as soon as playback starts.
      unawaited(
        _player.playerStateStream
            .firstWhere((s) => s.processingState == ProcessingState.completed)
            .then((_) => speaking.value = false)
            .catchError((Object _) => speaking.value = false),
      );
      await _player.play();
      return true;
    } catch (_) {
      speaking.value = false;
      return false;
    }
  }

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await stop();

    if (await _playNeural(trimmed)) return;

    try {
      await _tts.setLanguage('en-US');
      // Optimistic: some platforms don't fire the start handler promptly.
      speaking.value = true;
      await _tts.speak(trimmed);
    } catch (_) {
      // Narration is best-effort — never let a missing voice break the card.
      speaking.value = false;
    }
  }

  Future<void> stop() async {
    // Stopping something already stopped is not an error worth surfacing,
    // and stop() must never throw into a widget disposing.
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    speaking.value = false;
  }
}

/// Provider for the English narration helper. Uses its own FlutterTts instance
/// configured for a natural, slightly slower English delivery.
final englishTtsProvider = Provider<EnglishTts>((ref) {
  final tts = FlutterTts();
  tts.setLanguage('en-US');
  tts.setPitch(1.0);
  tts.setVolume(1.0);
  tts.setSpeechRate(0.5);
  // Its own player, so stopping narration can never cut off a Czech clip.
  final player = AudioPlayer();
  ref.onDispose(() {
    tts.stop();
    player.dispose();
  });
  return EnglishTts(
    tts,
    player,
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    ),
    () => ref.read(settingsProvider).ttsVoiceGender,
  );
});

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
  static final Logger _log = Logger('CzechTts');

  final FlutterTts _tts;
  final AudioPlayer _player;

  /// Current speech rate — part of the cache key, so audio synthesized at
  /// one rate is never replayed when the user changes the setting.
  final double Function() _speechRate;
  final TtsVoiceGender Function() _voiceGender;

  String? _cacheDir;

  /// Recorded Czech pack. Manifest, freshness, download and verification all
  /// live in [AudioPackCache], shared with the English narration pack.
  final AudioPackCache _pack;

  /// True when the last utterance came from the device's own TTS instead of
  /// the recorded pack.
  ///
  /// Substituting the system voice used to be completely silent, and it reads
  /// as a bug: the app "ignores" the male/female setting, because the platform
  /// voice has no such choice. Surfacing this lets the UI say "offline" rather
  /// than leaving a working app looking broken.
  final ValueNotifier<bool> usingFallbackVoice = ValueNotifier(false);

  CzechTts(
    this._tts,
    this._player,
    Dio http,
    this._speechRate,
    this._voiceGender,
  ) : _pack = AudioPackCache(
        http: http,
        manifestFileName: 'manifest.json',
        log: Logger('CzechTts.pack'),
      );

  /// Get the cache directory for TTS audio files.
  Future<String> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final dir = await getTemporaryDirectory();
    final ttsDir = '${dir.path}/tts_cache';
    await Directory(ttsDir).create(recursive: true);
    _cacheDir = ttsDir;
    return ttsDir;
  }

  /// Generate a cache key from the text and effective speech rate.
  String _cacheKey(String text, double rate) {
    final bytes = utf8.encode(
      '${rate.toStringAsFixed(2)}|${text.trim().toLowerCase()}',
    );
    final hash = md5.convert(bytes);
    return hash.toString();
  }

  Future<bool> _playNeural(String text, double effectiveRate) async {
    final path = await _pack.clipPath(text: text, gender: _voiceGender().name);
    if (path == null) return false;
    try {
      await _player.setFilePath(path);
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

    // Re-assert Czech: the English narration engine (see [EnglishTts]) may share
    // the same native engine on some platforms and leave it set to en-US.
    try {
      await _tts.setLanguage('cs-CZ');
    } catch (error) {
      // Not fatal: the engine keeps its previous locale, so speech may come
      // out anglicised rather than silent. Logged because that is confusing
      // to diagnose from a bug report alone.
      _log.warning('Could not re-assert cs-CZ on the TTS engine: $error');
    }

    final effectiveRate = rate ?? _speechRate();

    // Curriculum and vocabulary audio is generated once with a controlled
    // neural voice, downloaded from Supabase Storage, and retained for offline
    // reuse. It takes precedence over platform TTS whenever available.
    if (await _playNeural(trimmed, effectiveRate)) {
      usingFallbackVoice.value = false;
      return;
    }
    usingFallbackVoice.value = true;

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
  /// Play the bundled sample for [gender] — the genuine recorded teacher.
  ///
  /// The voice picker must not go through [speak]: the audio pack is not
  /// bundled (138MB lives in Supabase Storage), so before the first download
  /// [speak] falls through to the device's own TTS. That plays the *phone's*
  /// voice for both options, which makes the choice meaningless — the whole
  /// point of the screen is hearing the difference. These two clips ship in
  /// the app so the preview is always the real thing, online or not.
  Future<void> playVoiceSample(TtsVoiceGender gender) async {
    await stop();
    try {
      await _player.setAsset(voiceSampleAsset(gender));
      await _player.setSpeed(1.0);
      await _player.play();
      usingFallbackVoice.value = false;
    } catch (error) {
      // Never leave the picker silent: if the asset is somehow unreadable,
      // the device voice is worse than nothing but better than no feedback.
      _log.warning('Bundled voice sample failed for ${gender.name}: $error');
      await speak(kVoicePreviewPhrase);
    }
  }

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
    final neuralDir = Directory(await AudioPackCache.cacheDirectory());
    if (await neuralDir.exists()) {
      await neuralDir.delete(recursive: true);
      await neuralDir.create(recursive: true);
    }
    _pack.invalidate();
    AudioPackCache.resetSharedState();
  }

  /// Garbage-collect neural audio files no longer referenced by a pack.
  ///
  /// [alsoKeep] must list every other pack's live filenames. Both packs share
  /// one directory, so collecting against the Czech manifest alone deleted
  /// every English narration clip on sight — harmless only for as long as the
  /// English pack was unreachable, which it no longer is. Returns the number
  /// of files removed.
  Future<int> gcStaleAudio({Set<String> alsoKeep = const {}}) async {
    final live = await _pack.liveFileNames();
    if (live.isEmpty) return 0;

    final cacheDir = await AudioPackCache.cacheDirectory();
    final meta = await AudioPackCache.sharedMeta();

    final validFiles = {
      ...live,
      ...alsoKeep,
      // The manifests themselves and the shared cache meta.
      'manifest.json',
      'manifest_en.json',
      '_cache_meta.json',
    };

    final dir = Directory(cacheDir);
    if (!await dir.exists()) return 0;

    var removed = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      // Keep .part files — a download may be in progress.
      if (name.endsWith('.part')) continue;
      if (!validFiles.contains(name)) {
        try {
          await entity.delete();
          meta.forget(name);
          removed++;
        } catch (_) {
          // Best effort — file may be held open.
        }
      }
    }

    if (removed > 0) await AudioPackCache.saveMeta();
    return removed;
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
    final neuralDir = Directory(await AudioPackCache.cacheDirectory());
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
/// Phrase used to demo the chosen voice in onboarding and Settings.
///
/// It must be a real course utterance. Anything else has no clip in the pack,
/// so [CzechTts] falls back to the device's robotic system voice — and a
/// preview that plays the system voice tells the learner nothing about the
/// studio voice they actually get.
const String kVoicePreviewPhrase = 'Dobrý den, jak se máte?';

/// The sha256 of [kVoicePreviewPhrase] under the audio pack's naming scheme.
/// These two clips ship inside the app (see pubspec.yaml) precisely so the
/// teacher picker can play the genuine voice before any download has run.
const String _voiceSampleDigest =
    '2f44c5669abb492049b767f78d72f275298c2dd68e8ff0d575c2544eddf9c762';

/// Bundled sample asset for [gender].
String voiceSampleAsset(TtsVoiceGender gender) =>
    'assets/audio/${gender.name}_$_voiceSampleDigest.mp3';

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
