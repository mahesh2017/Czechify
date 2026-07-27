import 'dart:io';

/// Abstract interface for Text-to-Speech.
abstract class TtsService {
  Future<String> synthesize(String text, {String? voiceId});
  Future<File> getCachedOrSynthesize(String text, {String? voiceId});
  Future<List<String>> getAvailableVoices();
  Future<bool> isAvailable();
}
