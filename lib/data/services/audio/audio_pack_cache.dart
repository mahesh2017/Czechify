import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/backend_config.dart';
import '../../../core/config/release_config.dart';
import 'audio_manifest.dart';

/// Local cache for one recorded audio pack: manifest, freshness, download.
///
/// The Czech and English packs each had their own copy of this — manifest
/// fetch, offline fallback, checksum freshness, `.part` download, verify,
/// rename — differing only in a filename. The copies had already drifted: the
/// English one carried a filename check that could not match anything, so its
/// pack never played at all. One implementation is the point.
///
/// Both packs share a directory, so they also share the cache meta and the
/// set of filenames worth keeping; see [sharedMeta] and [liveFileNames].
class AudioPackCache {
  AudioPackCache({
    required Dio http,
    required String manifestFileName,
    Logger? log,
    String? publicBase,
  }) : _http = http,
       _manifestFileName = manifestFileName,
       _publicBase = publicBase,
       _log = log ?? Logger('AudioPackCache');
  // Public named parameters initialize intentionally private fields.
  // ignore_for_file: prefer_initializing_formals

  final Dio _http;
  final String _manifestFileName;

  /// Storage origin. Null in normal builds, where it is derived from
  /// [BackendConfig]; supplied directly by tests, which have no dart-defines
  /// and would otherwise only ever exercise the unconfigured branch.
  final String? _publicBase;
  final Logger _log;

  Future<AudioManifest?>? _manifest;

  static const _bucket = 'course-audio';

  /// Where clips and manifests are fetched from, or null when this build has
  /// no backend configured and the pack must stay switched off.
  String? get _origin =>
      _publicBase ??
      (BackendConfig.isConfigured
          ? '${BackendConfig.supabaseUrl}/storage/v1/object/public/$_bucket'
          : null);

  /// Content key for [text]. Deliberately excludes playback speed: one clip is
  /// replayed faster or slower rather than stored twice.
  static String keyFor(String text) =>
      sha256.convert(utf8.encode(text.trim().toLowerCase())).toString();

  /// Absolute path to a playable local file for [text], or null when the pack
  /// has no clip for it and the caller should fall back to device speech.
  ///
  /// Downloads and verifies on demand. Every failure returns null rather than
  /// throwing: a stale manifest, a dead network, or a corrupt download must
  /// never stop the app from speaking.
  Future<String?> clipPath({
    required String text,
    required String gender,
  }) async {
    final manifest = await load();
    final origin = _origin;
    if (manifest == null || origin == null) return null;
    final entry = manifest.forGender(gender)[keyFor(text)];
    if (entry == null) return null;

    final fileName = entry.path.split('/').last;
    // The manifest is a remote input and this name becomes a local path.
    if (!isValidAudioPackFileName(fileName)) {
      _log.warning('Rejected manifest filename: $fileName');
      return null;
    }

    try {
      final directory = await cacheDirectory();
      final meta = await sharedMeta();
      final cached = File('$directory/$fileName');

      final status = await checkCacheFreshness(
        file: cached,
        entry: entry,
        meta: meta,
      );
      if (status == CacheStatus.fresh) return cached.path;

      // `.part` then rename: an interrupted download must never leave a
      // truncated file that looks cached and plays as silence.
      final partial = File('${cached.path}.part');
      await _http.download(
        ReleaseConfig.audioClipUrl('$origin/$fileName', entry.sha256),
        partial.path,
      );
      if (!await partial.exists() || await partial.length() == 0) {
        throw const FileSystemException('Downloaded audio is empty');
      }
      if (!await verifyDownloadedFile(file: partial, entry: entry, meta: meta)) {
        await partial.delete();
        throw FileSystemException('Checksum mismatch for $fileName');
      }
      await partial.rename(cached.path);
      await saveMeta();
      return cached.path;
    } catch (error) {
      _log.warning('Could not obtain $fileName', error);
      return null;
    }
  }

  /// The pack manifest, read once per process.
  ///
  /// Keyed on disk by [ReleaseConfig.bundledContentRevision] — which is
  /// exactly the signal that the manifest changed, and is already what
  /// cache-busts the URL. A launch that already holds this revision reads it
  /// from disk and never opens a connection.
  ///
  /// It used to fetch on every cold start and keep the disk copy only as an
  /// offline fallback, so a ~2 MB download rode on every launch. Egress then
  /// scaled with how much a learner used the app rather than with installs,
  /// which made the most engaged learners the most expensive ones.
  ///
  /// This leans on a contract the `?v=` cache-buster already implied: bump the
  /// revision whenever the manifest changes. Replacing the stored object
  /// without bumping it leaves clients on the copy they already have.
  Future<AudioManifest?> load() => _manifest ??= _load();

  /// Cache file for [revision]: `manifest.json` becomes `manifest.v22.json`.
  ///
  /// The revision lives in the name so its presence *is* the freshness check.
  /// A sidecar file recording it would be a second thing to keep in step, and
  /// the failure when the two drifted would be silent.
  String _cacheFileName(int revision) {
    final dot = _manifestFileName.lastIndexOf('.');
    if (dot <= 0) return '$_manifestFileName.v$revision';
    return '${_manifestFileName.substring(0, dot)}'
        '.v$revision'
        '${_manifestFileName.substring(dot)}';
  }

  Future<AudioManifest?> _load() async {
    final origin = _origin;
    if (origin == null) {
      // Built without the Supabase --dart-defines, so the URL below would be
      // '<empty>/storage/...'. Say so rather than looking like missing audio.
      _log.warning(
        'Audio pack disabled: SUPABASE_URL/SUPABASE_ANON_KEY were not supplied '
        'at build time. Falling back to device speech.',
      );
      return null;
    }
    final directory = await cacheDirectory();
    const revision = ReleaseConfig.bundledContentRevision;
    final cached = File('$directory/${_cacheFileName(revision)}');

    // Same revision means identical bytes, so this is the entire fetch.
    if (await cached.exists()) {
      final onDisk = await _parseFile(cached);
      if (onDisk != null) return onDisk;
      // Truncated or corrupt: drop it rather than strand the pack on it.
      await _deleteQuietly(cached);
    }

    try {
      final response = await _http.get<String>(
        ReleaseConfig.audioManifestUrl('$origin/$_manifestFileName'),
        options: Options(responseType: ResponseType.plain),
      );
      final raw = response.data;
      if (raw == null || raw.isEmpty) {
        throw const FormatException('Empty manifest');
      }
      // Parsed before it is written. Caching first would persist a corrupt
      // manifest and keep serving it after the network recovered.
      final parsed = AudioManifest.parse(raw);
      await cached.writeAsString(raw, flush: true);
      await _removeSuperseded(directory, revision);
      return parsed;
    } catch (error) {
      _log.info('Falling back to cached $_manifestFileName', error);
      // An older revision still describes the clips already on this device,
      // which is what an offline learner actually has. Better than silence.
      return _loadSuperseded(directory, revision);
    }
  }

  Future<AudioManifest?> _parseFile(File file) async {
    try {
      return AudioManifest.parse(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } catch (_) {
      // A cache we cannot clean up is not worth failing a lesson over.
    }
  }

  /// Cached manifests for this pack that are not [current], newest first.
  ///
  /// Includes the pre-revision filename, so upgrading installs shed the
  /// unversioned ~2 MB copy instead of carrying it forever.
  Future<List<File>> _otherRevisions(String directory, int current) async {
    final dot = _manifestFileName.lastIndexOf('.');
    final stem =
        dot <= 0 ? _manifestFileName : _manifestFileName.substring(0, dot);
    final suffix = dot <= 0 ? '' : _manifestFileName.substring(dot);
    final versioned = RegExp(
      '^${RegExp.escape(stem)}\\.v(\\d+)${RegExp.escape(suffix)}\$',
    );
    final found = <int, File>{};
    File? legacy;
    try {
      await for (final entity in Directory(directory).list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name == _manifestFileName) {
          legacy = entity;
          continue;
        }
        final match = versioned.firstMatch(name);
        if (match == null) continue;
        final revision = int.parse(match.group(1)!);
        if (revision != current) found[revision] = entity;
      }
    } catch (_) {
      return const [];
    }
    final revisions = found.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final revision in revisions) found[revision]!,
      if (legacy != null) legacy,
    ];
  }

  Future<AudioManifest?> _loadSuperseded(String directory, int current) async {
    for (final file in await _otherRevisions(directory, current)) {
      final parsed = await _parseFile(file);
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<void> _removeSuperseded(String directory, int current) async {
    for (final file in await _otherRevisions(directory, current)) {
      await _deleteQuietly(file);
    }
  }

  /// Forget the in-memory manifest so the next call refetches it.
  void invalidate() => _manifest = null;

  /// Every filename this pack currently references, for garbage collection.
  Future<Set<String>> liveFileNames() async {
    final manifest = await load();
    if (manifest == null) return const {};
    return {
      for (final entries in manifest.voices.values)
        for (final entry in entries.values) entry.path.split('/').last,
    };
  }

  // ── Shared directory state ──
  //
  // Both packs live in one directory and write one `_cache_meta.json`. They
  // used to hold independent in-memory copies of it and each save the whole
  // map, so whichever wrote last erased the other's checksums and those clips
  // were re-downloaded on next launch. One instance per process fixes that.

  static Future<String>? _directory;
  static Future<AudioCacheMeta>? _meta;
  static Future<void> _pendingSave = Future.value();

  static Future<String> cacheDirectory() => _directory ??= _resolveDirectory();

  static Future<String> _resolveDirectory() async {
    final support = await getApplicationSupportDirectory();
    final path = '${support.path}/neural_audio';
    await Directory(path).create(recursive: true);
    return path;
  }

  /// The one cache-meta instance for this process.
  static Future<AudioCacheMeta> sharedMeta() =>
      _meta ??= cacheDirectory().then(AudioCacheMeta.load);

  /// Persists the shared meta, serialized so two packs finishing a download at
  /// the same moment cannot interleave writes to the same file.
  static Future<void> saveMeta() {
    return _pendingSave = _pendingSave.then((_) async {
      final meta = await sharedMeta();
      await meta.save(await cacheDirectory());
    }).catchError((Object _) {});
  }

  /// Drops cached directory/meta state. Only for tests, which otherwise leak
  /// one test's temporary directory into the next.
  static void resetSharedState() {
    _directory = null;
    _meta = null;
    _pendingSave = Future.value();
  }
}
