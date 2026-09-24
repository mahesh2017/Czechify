import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:crypto/crypto.dart';

import '../sync/backend_service.dart';
import 'curriculum_contract_validator.dart';

// A public named parameter initializes an intentionally private dependency.
// ignore_for_file: prefer_initializing_formals

/// A content release manifest fetched from Supabase.
///
/// Ties together a set of curriculum packs into a versioned, checksummed
/// release. The client compares the manifest version to its local state to
/// determine whether a content update is available.
class ContentRelease {
  /// The content format this app reads.
  ///
  /// 2 added exercise modes, lecture and notebook cards (plan v1.2). Raise it
  /// when the app learns to read something older apps cannot, and publish
  /// content that needs it with `status = 'gated'` and a matching
  /// `min_client_format` — never as 'published', which every older app
  /// installs (enforced in 20261005100000_content_release_client_format.sql).
  static const clientFormat = 2;

  final String releaseId;
  final int version;
  final String contentChecksum;
  final List<PackRef> packRefs;
  final String? previousRelease;
  final String? notes;

  const ContentRelease({
    required this.releaseId,
    required this.version,
    required this.contentChecksum,
    required this.packRefs,
    this.previousRelease,
    this.notes,
  });

  factory ContentRelease.fromJson(Map<String, dynamic> json) {
    final refs =
        (json['pack_refs'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(PackRef.fromJson)
            .toList();
    return ContentRelease(
      releaseId: json['release_id'] as String,
      version: json['version'] as int,
      contentChecksum: json['content_checksum'] as String,
      packRefs: refs,
      previousRelease: json['previous_release'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

/// A reference to a single pack within a release manifest.
class PackRef {
  final String packKey;
  final int version;
  final String checksum;

  const PackRef({
    required this.packKey,
    required this.version,
    required this.checksum,
  });

  factory PackRef.fromJson(Map<String, dynamic> json) {
    return PackRef(
      packKey: json['pack_key'] as String,
      version: json['version'] as int,
      checksum: json['checksum'] as String,
    );
  }
}

typedef VerifiedContentPack = ({int version, String checksum, Object? content});

/// Deterministic SHA-256 verification for decoded JSON curriculum packs.
class ContentReleaseVerifier {
  const ContentReleaseVerifier();

  String checksum(Object? content) =>
      sha256.convert(utf8.encode(_canonicalJson(content))).toString();

  String aggregateChecksum(Iterable<PackRef> refs) {
    final ordered =
        refs.toList()..sort((a, b) => a.packKey.compareTo(b.packKey));
    return sha256
        .convert(utf8.encode(ordered.map((ref) => ref.checksum).join()))
        .toString();
  }

  void verify({
    required ContentRelease release,
    required Set<String> requiredPackKeys,
    required Map<String, VerifiedContentPack> packs,
  }) {
    final refsByKey = <String, PackRef>{};
    for (final ref in release.packRefs) {
      if (refsByKey.putIfAbsent(ref.packKey, () => ref) != ref) {
        throw StateError('Release contains duplicate pack ${ref.packKey}.');
      }
    }
    if (refsByKey.keys.toSet().difference(requiredPackKeys).isNotEmpty ||
        requiredPackKeys.difference(refsByKey.keys.toSet()).isNotEmpty) {
      throw StateError(
        'Release pack membership does not match the app contract.',
      );
    }
    if (packs.keys.toSet().difference(requiredPackKeys).isNotEmpty ||
        requiredPackKeys.difference(packs.keys.toSet()).isNotEmpty) {
      throw StateError(
        'Downloaded release is incomplete or contains extra packs.',
      );
    }
    for (final ref in release.packRefs) {
      final pack = packs[ref.packKey]!;
      if (pack.version != ref.version || pack.checksum != ref.checksum) {
        throw StateError('Pack identity does not match ${ref.packKey}.');
      }
      if (checksum(pack.content) != ref.checksum) {
        throw StateError('Pack checksum failed for ${ref.packKey}.');
      }
    }
    if (aggregateChecksum(release.packRefs) != release.contentChecksum) {
      throw StateError('Release aggregate checksum failed.');
    }
  }

  String _canonicalJson(Object? value) => switch (value) {
    final Map<Object?, Object?> map => _canonicalMap(map),
    final List<Object?> list => '[${list.map(_canonicalJson).join(',')}]',
    _ => jsonEncode(value),
  };

  String _canonicalMap(Map<Object?, Object?> map) {
    final keys = map.keys.map((key) => key as String).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(map[key])}').join(',')}}';
  }
}

/// Loads a complete curriculum snapshot from either bundled assets or
/// Supabase. A snapshot is exposed only after every required pack is present.
class CurriculumPackSource {
  CurriculumPackSource({
    required BackendService backend,
    AssetBundle? bundle,
    Logger? log,
  }) : _backend = backend,
       _bundle = bundle ?? rootBundle,
       _log = log ?? Logger('CurriculumPackSource');

  final BackendService _backend;
  final AssetBundle _bundle;
  final Logger _log;
  final ContentReleaseVerifier _verifier = const ContentReleaseVerifier();
  Map<String, Object?> _packs = const {};
  Map<String, VerifiedContentPack> _verifiedPacks = const {};

  /// The last release manifest fetched from Supabase, or null when only
  /// bundled content has been loaded.
  ContentRelease? _lastRelease;
  ContentRelease? get currentRelease => _lastRelease;
  Map<String, VerifiedContentPack> get verifiedPacks =>
      Map.unmodifiable(_verifiedPacks);

  /// Load and validate the packaged bootstrap snapshot.
  Future<void> loadBundled(Set<String> requiredPackKeys) async {
    final bundled = <String, Object?>{};
    for (final key in requiredPackKeys) {
      bundled[key] = jsonDecode(await _bundle.loadString(key));
    }
    CurriculumContractValidator.validateSnapshot(bundled);
    _packs = bundled;
    _verifiedPacks = const {};
    _lastRelease = null;
    _log.info('Loaded ${bundled.length} bundled curriculum packs.');
  }

  /// Fetch and validate a complete live curriculum snapshot.
  Future<void> refreshRemote(Set<String> requiredPackKeys) async {
    final client = _backend.client;
    if (client == null) {
      throw StateError(
        'Supabase is not configured; curriculum cannot be loaded.',
      );
    }

    final releaseRows = await client
        .from('content_releases')
        .select()
        .inFilter('status', const ['published', 'gated'])
        .lte('min_client_format', ContentRelease.clientFormat)
        .order('published_at', ascending: false)
        .limit(1)
        .timeout(const Duration(seconds: 10));
    if (releaseRows.isEmpty) {
      throw StateError('No published content release is available.');
    }
    var release = ContentRelease.fromJson(releaseRows.first);
    final itemRows = await client
        .from('content_release_items')
        .select('pack_key,pack_version,checksum')
        .eq('release_id', release.releaseId)
        .order('position')
        .timeout(const Duration(seconds: 10));
    final refs =
        itemRows
            .map(
              (row) => PackRef(
                packKey: row['pack_key'] as String,
                version: row['pack_version'] as int,
                checksum: row['checksum'] as String,
              ),
            )
            .toList();
    release = ContentRelease(
      releaseId: release.releaseId,
      version: release.version,
      contentChecksum: release.contentChecksum,
      packRefs: refs,
      previousRelease: release.previousRelease,
      notes: release.notes,
    );

    final versionRows = await client
        .from('curriculum_pack_versions')
        .select('pack_key,version,checksum,content')
        .inFilter('pack_key', refs.map((ref) => ref.packKey).toList())
        .timeout(const Duration(seconds: 10));
    final referencedVersions = {
      for (final ref in refs) '${ref.packKey}@${ref.version}',
    };
    final packs = <String, VerifiedContentPack>{};
    for (final row in versionRows) {
      final key = row['pack_key'] as String;
      final version = row['version'] as int;
      if (!referencedVersions.contains('$key@$version')) continue;
      packs[key] = (
        version: version,
        checksum: row['checksum'] as String,
        content: row['content'],
      );
    }
    _verifier.verify(
      release: release,
      requiredPackKeys: requiredPackKeys,
      packs: packs,
    );
    final remote = {
      for (final entry in packs.entries) entry.key: entry.value.content,
    };
    CurriculumContractValidator.validateSnapshot(remote);
    _packs = remote;
    _verifiedPacks = Map.unmodifiable(packs);
    _lastRelease = release;
    _log.info('Loaded ${remote.length} curriculum packs from Supabase.');
  }

  /// The version of the currently loaded release, or 0 when only bundled
  /// content (no release manifest) is in use.
  int get releaseVersion => _lastRelease?.version ?? 0;

  /// Restore a previously verified local release. Cached bytes are verified
  /// again before they become visible to the installer.
  void loadCachedRelease({
    required ContentRelease release,
    required Set<String> requiredPackKeys,
    required Map<String, VerifiedContentPack> packs,
  }) {
    _verifier.verify(
      release: release,
      requiredPackKeys: requiredPackKeys,
      packs: packs,
    );
    final snapshot = {
      for (final entry in packs.entries) entry.key: entry.value.content,
    };
    CurriculumContractValidator.validateSnapshot(snapshot);
    _packs = snapshot;
    _verifiedPacks = Map.unmodifiable(packs);
    _lastRelease = release;
  }

  Future<String> load(String path) async {
    final pack = _packs[path];
    if (pack != null) return jsonEncode(pack);
    throw StateError('Curriculum pack is not present in the snapshot: $path');
  }
}
