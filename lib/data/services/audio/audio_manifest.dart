/// Versioned audio manifest model with checksum-based cache invalidation.
///
/// The manifest maps text-hashes to audio files.  In v2 the value was a bare
/// path string; in v3 it is an object carrying the audio-byte SHA-256 and size
/// so a client can detect when a clip has been re-recorded for unchanged text
/// and re-download instead of playing stale audio forever.
///
/// Both formats are accepted: a string value is treated as a legacy entry
/// with no checksum (the pre-v3 behaviour — download once if absent).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// One entry in the audio manifest — the audio file for a given text hash.
class ManifestEntry {
  ManifestEntry({required this.path, this.sha256, this.size});

  /// Storage path relative to the public audio bucket root.
  final String path;

  /// SHA-256 of the audio file bytes, when the manifest carries it (v3+).
  /// Null for legacy v2 string entries.
  final String? sha256;

  /// File size in bytes, when known.  Used as a fast cache-validity check
  /// before the slower SHA-256 verification.
  final int? size;

  /// Parse a raw manifest value, accepting both legacy (string) and v3
  /// (object) formats.
  factory ManifestEntry.fromJson(dynamic value) {
    if (value is String) {
      return ManifestEntry(path: value);
    }
    if (value is Map<String, dynamic>) {
      return ManifestEntry(
        path: value['path'] as String,
        sha256: value['sha256'] as String?,
        size: value['size'] as int?,
      );
    }
    throw const FormatException(
      'Invalid manifest entry: expected string or object',
    );
  }

  /// True when the entry carries checksum metadata that enables staleness
  /// detection.  Legacy entries without checksums can only do existence
  /// checks.
  bool get hasChecksum => sha256 != null && size != null;
}

/// A manifest-supplied filename is a remote input that becomes a local path,
/// so it is checked against the only shape the generator produces:
/// `<voice>_<64 hex>.mp3`.
///
/// This lives here, once, because it previously did not: the Czech and English
/// playback paths each carried their own copy of this pattern, and the English
/// one had `\\.` inside a raw string — a literal backslash, which no real
/// filename can contain. It matched nothing, so every English narration
/// silently fell through to the device's synthetic voice while the recorded
/// pack sat unused on the CDN.
bool isValidAudioPackFileName(String fileName) =>
    _audioPackFileName.hasMatch(fileName);

final RegExp _audioPackFileName = RegExp(r'^[a-z]+_[0-9a-f]{64}\.mp3$');

/// Parsed audio manifest: voices → {textHash → ManifestEntry}.
class AudioManifest {
  AudioManifest({
    this.version = 2,
    this.locale = 'cs-CZ',
    this.revision,
    required this.voices,
  });

  final int version;
  final String locale;

  /// Pack-level revision identifier (date, incrementing number, or any
  /// string the generator sets).  When the revision changes the client knows
  /// to re-fetch and compare per-entry checksums.
  final String? revision;

  /// gender name → {text hash → entry}
  final Map<String, Map<String, ManifestEntry>> voices;

  /// Parse raw manifest JSON, accepting v2 (string entries) and v3 (object
  /// entries).
  factory AudioManifest.parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final voicesJson = json['voices'] as Map<String, dynamic>? ?? const {};
    final voices = voicesJson.map((gender, voiceValue) {
      final voice = voiceValue as Map<String, dynamic>;
      final entriesJson = voice['entries'] as Map<String, dynamic>? ?? const {};
      return MapEntry(
        gender,
        entriesJson.map(
          (key, value) => MapEntry(key, ManifestEntry.fromJson(value)),
        ),
      );
    });
    return AudioManifest(
      version: json['version'] as int? ?? 2,
      locale: json['locale'] as String? ?? 'cs-CZ',
      revision: json['revision'] as String?,
      voices: voices,
    );
  }

  /// Entries for [gender], or empty.
  Map<String, ManifestEntry> forGender(String gender) =>
      voices[gender] ?? const {};
}

/// Local record of what was downloaded, keyed by filename.  Stored as a
/// small JSON file in the neural-audio cache directory.
///
/// When the manifest updates and a clip's SHA-256 changes (re-recorded audio
/// for the same text), the local meta no longer matches and the client
/// re-downloads — instead of playing the old bytes forever.
class AudioCacheMeta {
  AudioCacheMeta({Map<String, String>? fileSha256})
    : _fileSha256 = fileSha256 ?? {};

  final Map<String, String> _fileSha256;

  static const _metaFileName = '_cache_meta.json';

  /// Load meta from [cacheDir], returning an empty meta if the file is
  /// absent or unreadable (never throws — a missing meta just means
  /// "re-verify everything").
  static Future<AudioCacheMeta> load(String cacheDir) async {
    final file = File('$cacheDir/$_metaFileName');
    if (!await file.exists()) return AudioCacheMeta();
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final sha = json['file_sha256'] as Map<String, dynamic>? ?? {};
      return AudioCacheMeta(
        fileSha256: sha.map((k, v) => MapEntry(k, v as String)),
      );
    } catch (_) {
      return AudioCacheMeta();
    }
  }

  /// Persist meta to [cacheDir].
  Future<void> save(String cacheDir) async {
    final file = File('$cacheDir/$_metaFileName');
    await file.writeAsString(
      jsonEncode({'file_sha256': _fileSha256}),
      flush: true,
    );
  }

  /// The SHA-256 recorded for [fileName], or null if the file was never
  /// downloaded under checksum verification.
  String? sha256Of(String fileName) => _fileSha256[fileName];

  /// Record that [fileName] was verified to have [sha256] audio bytes.
  void record(String fileName, String sha256) {
    _fileSha256[fileName] = sha256;
  }

  /// Remove a filename from the meta (e.g. after the file is deleted).
  void forget(String fileName) {
    _fileSha256.remove(fileName);
  }
}

/// Compute SHA-256 of [file]'s bytes.  Used to verify a freshly downloaded
/// file against the manifest.
Future<String> _sha256OfFile(File file) async {
  final bytes = await file.readAsBytes();
  return sha256.convert(bytes).toString();
}

/// Result of a cache validity check for a manifest entry.
enum CacheStatus { fresh, stale, unknown }

/// Check whether the cached file at [filePath] is fresh for [entry],
/// consulting the local [meta] for checksum comparison.
///
/// Returns:
/// - [CacheStatus.fresh] — file exists, size matches, and the recorded
///   sha256 matches the manifest's (or the entry has no checksum and the
///   file exists).
/// - [CacheStatus.stale] — file exists but size or checksum mismatch.
/// - [CacheStatus.unknown] — file does not exist.
Future<CacheStatus> checkCacheFreshness({
  required File file,
  required ManifestEntry entry,
  required AudioCacheMeta meta,
}) async {
  if (!await file.exists()) return CacheStatus.unknown;

  // Fast path: size check.
  if (entry.size != null && await file.length() != entry.size) {
    return CacheStatus.stale;
  }

  // If the manifest carries a checksum, compare against local meta.
  if (entry.sha256 != null) {
    final localSha = meta.sha256Of(file.uri.pathSegments.last);
    if (localSha != entry.sha256) {
      return CacheStatus.stale;
    }
  }

  return CacheStatus.fresh;
}

/// Verify a freshly downloaded file against the manifest entry's checksum.
///
/// Returns true if the file is valid (checksum matches, or the entry has no
/// checksum and the file is non-empty).  On success, records the checksum in
/// [meta].
Future<bool> verifyDownloadedFile({
  required File file,
  required ManifestEntry entry,
  required AudioCacheMeta meta,
}) async {
  if (!await file.exists() || await file.length() == 0) return false;

  if (entry.sha256 != null) {
    final actual = await _sha256OfFile(file);
    if (actual != entry.sha256) return false;
    meta.record(file.uri.pathSegments.last, actual);
  }

  // No checksum in manifest — accept any non-empty file (legacy behaviour).
  return true;
}
