import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/repositories/speech_ports.dart';

/// Word-level transcription result from Whisper.
class WhisperWord {
  final String word;
  final double start; // seconds
  final double end; // seconds
  final double probability; // 0.0-1.0, Whisper's confidence

  const WhisperWord({
    required this.word,
    required this.start,
    required this.end,
    required this.probability,
  });

  factory WhisperWord.fromJson(Map<String, dynamic> json) {
    return WhisperWord(
      word: json['word'] as String? ?? '',
      start: (json['start'] as num?)?.toDouble() ?? 0,
      end: (json['end'] as num?)?.toDouble() ?? 0,
      probability: (json['probability'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Full transcription result from Whisper verbose_json.
class WhisperResult {
  final String text;
  final String language;
  final double duration;
  final List<WhisperWord> words;

  const WhisperResult({
    required this.text,
    required this.language,
    required this.duration,
    required this.words,
  });

  factory WhisperResult.fromJson(Map<String, dynamic> json) {
    final wordsList =
        (json['words'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(WhisperWord.fromJson)
            .toList();
    return WhisperResult(
      text: json['text'] as String? ?? '',
      language: json['language'] as String? ?? 'cs',
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      words: wordsList,
    );
  }
}

/// Transcribes audio via the server-side Whisper Edge Function.
///
/// The OpenAI API key is stored as a Supabase secret — the client sends
/// base64-encoded audio to the Edge Function, which forwards it to OpenAI
/// Whisper and returns verbose_json with word-level timestamps and
/// confidence scores.
// A public named parameter initializes an intentionally private dependency.
// ignore_for_file: prefer_initializing_formals
class WhisperService implements CloudTranscriber {
  /// [clientResolver] is read live on every call so capability reflects the
  /// current session even if this service was constructed before the anonymous
  /// sign-in completed (a cached snapshot would otherwise stay null forever and
  /// silently force the on-device fallback).
  WhisperService({SupabaseClient? Function()? clientResolver, Logger? log})
    : _clientResolver = clientResolver ?? (() => null),
      _log = log ?? Logger('WhisperService');

  final SupabaseClient? Function() _clientResolver;
  final Logger _log;

  SupabaseClient? get _client => _clientResolver();

  /// Reactive capability: cloud speech is only "available" when there is an
  /// authenticated backend session, evaluated live. Even when this is true,
  /// `whisper-proxy` may be undeployed and [transcribe] may throw; callers must
  /// degrade rather than hard-fail.
  @override
  bool get isAvailable => _client?.auth.currentUser != null;

  /// Transcribe an audio file via the Whisper Edge Function.
  ///
  /// [audioPath] — path to a .wav file on disk.
  /// [language] — ISO language code (default: "cs" for Czech).
  /// [prompt] — optional reference text to guide recognition (improves
  ///   accuracy when the expected text is known, e.g. pronunciation exercises).
  @override
  Future<WhisperResult> transcribe({
    required String audioPath,
    String language = 'cs',
    String? prompt,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase client not available — Whisper backend disabled.',
      );
    }

    // Read audio file and encode as base64
    final file = File(audioPath);
    if (!await file.exists()) {
      throw FileSystemException('Audio file not found', audioPath);
    }

    final bytes = await file.readAsBytes();
    final audioBase64 = base64Encode(bytes);

    _log.info('Sending ${bytes.length} bytes of audio to Whisper proxy...');

    final response = await client.functions.invoke(
      'whisper-proxy',
      body: {
        'audio_base64': audioBase64,
        'language': language,
        if (prompt != null) 'prompt': prompt,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      final error = data is Map ? data['error']?.toString() : 'Unknown error';
      throw Exception('Whisper transcription failed: $error');
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    final result = WhisperResult.fromJson(data);

    _log.info(
      'Whisper transcribed ${result.duration.toStringAsFixed(1)}s audio: '
      '${result.text.isNotEmpty ? "${result.words.length} words" : "empty"}',
    );

    return result;
  }
}
