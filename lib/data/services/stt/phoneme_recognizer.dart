import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

/// Client for the Czech acoustic recogniser (services/phoneme-recognizer).
///
/// Returns what the learner actually said, as Czech text, from a bare CTC model
/// decoded without a language model. That distinction is the whole point: an
/// ASR with a language model rewrites a learner's "reka" into the real word
/// "řeka", hiding the error. This reports the sounds as heard, so a substituted
/// ř survives all the way to the scorer.
///
/// Every failure degrades to null rather than throwing. A pronunciation
/// exercise must still work when the service is down, unreachable, or simply
/// not configured — the caller falls back to transcript-level scoring.
class PhonemeRecognizer {
  PhonemeRecognizer({
    required String baseUrl,
    String? apiToken,
    Dio? http,
    Logger? log,
  }) : _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
       // ignore: prefer_initializing_formals
       _apiToken = apiToken,
       _log = log ?? Logger('PhonemeRecognizer'),
       _http =
           http ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 5),
               sendTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(seconds: 20),
             ),
           );

  final String _baseUrl;
  final String? _apiToken;
  final Dio _http;
  final Logger _log;

  /// Configured only over TLS.
  ///
  /// This endpoint receives raw recordings of the learner's voice, and it is
  /// a self-hosted address supplied at build time — the documented example was
  /// a plain `http://` host on a LAN. A build that shipped with one would have
  /// sent biometric audio in the clear to a destination the privacy notice
  /// does not describe. Refusing to treat it as configured degrades the app to
  /// transcript scoring, which is the existing behaviour when no recogniser is
  /// set at all, rather than failing anything visible.
  bool get isConfigured => Uri.tryParse(_baseUrl)?.isScheme('https') ?? false;

  /// The Czech text the model heard, or null if it could not be obtained.
  Future<String?> recognize(String audioPath) async {
    if (!isConfigured) return null;

    final file = File(audioPath);
    if (!await file.exists()) {
      _log.warning('Audio file missing: $audioPath');
      return null;
    }

    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(audioPath, filename: 'clip.wav'),
      });
      final response = await _http.post<Map<String, dynamic>>(
        '$_baseUrl/recognize',
        data: form,
        options: Options(
          headers: {
            if (_apiToken != null && _apiToken.isNotEmpty)
              'Authorization': 'Bearer $_apiToken',
          },
        ),
      );
      final heard = response.data?['heard'] as String?;
      if (heard == null || heard.trim().isEmpty) return null;
      _log.info('Recogniser heard: "$heard"');
      return heard.trim();
    } catch (error) {
      // Never surface this to the learner — the caller degrades instead.
      _log.warning('Phoneme recogniser unavailable: $error');
      return null;
    }
  }
}
