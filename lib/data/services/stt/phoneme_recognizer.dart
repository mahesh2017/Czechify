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
  })  : _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
        // ignore: prefer_initializing_formals
        _apiToken = apiToken,
        _log = log ?? Logger('PhonemeRecognizer'),
        _http = http ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
            ));

  final String _baseUrl;
  final String? _apiToken;
  final Dio _http;
  final Logger _log;

  bool get isConfigured => _baseUrl.isNotEmpty;

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
