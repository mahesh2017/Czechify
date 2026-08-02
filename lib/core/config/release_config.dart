/// Values that tie bundled curriculum and its remotely hosted media together.
class ReleaseConfig {
  const ReleaseConfig._();

  /// Increment whenever bundled lessons or their audio manifest changes.
  ///
  /// The same value forces existing installs to reseed curriculum and gives
  /// the CDN a new manifest URL for the matching app release.
  static const int bundledContentRevision = 22;

  static String audioManifestUrl(String url) =>
      '$url?v=$bundledContentRevision';

  /// Re-recorded audio keeps its text-hash filename. Its byte checksum is the
  /// cache key that bypasses any older CDN object at that same path.
  static String audioClipUrl(String url, String? checksum) =>
      checksum == null || checksum.isEmpty ? url : '$url?v=$checksum';
}
